#!/bin/bash
# Claude Code 用户身份感知审批脚本
# 功能：基于当前用户身份、用户组、权限级别进行智能审批

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')
project_root=$(echo "$input" | jq -r '.context.project_root')

# 配置文件路径
config_file="$project_root/.claude-user-config.json"

# 获取当前用户信息
current_user=$(whoami)
current_user_id=$(id -u)
current_groups=$(id -Gn)
current_home=$HOME

# 获取项目信息
project_owner=$(stat -c '%U' "$project_root" 2>/dev/null || echo "unknown")
project_group=$(stat -c '%G' "$project_root" 2>/dev/null || echo "unknown")

# 日志记录
echo "[$(date)] User-identity approval - $tool_name by $current_user" >> /tmp/claude-user-approval.log
echo "[$(date)] User ID: $current_user_id, Groups: $current_groups" >> /tmp/claude-user-approval.log

# 默认用户权限配置
user_permissions="standard"
admin_users="root|admin|sudo|wheel"
developer_groups="developer|dev|engineering|programmer"
ops_groups="ops|operations|sysadmin|admin"
guest_groups="guest|temp|contractor"

# 读取用户配置（如果存在）
if [[ -f "$config_file" ]]; then
    # 检查用户是否在配置中有特定权限
    user_config=$(jq -r ".users.\"$current_user\" // empty" "$config_file" 2>/dev/null)
    if [[ -n "$user_config" ]]; then
        user_permissions=$(echo "$user_config" | jq -r '.permissions // "standard"')
        echo "[$(date)] Found user config for $current_user: $user_permissions" >> /tmp/claude-user-approval.log
    fi

    # 检查组权限
    for group in $current_groups; do
        group_config=$(jq -r ".groups.\"$group\" // empty" "$config_file" 2>/dev/null)
        if [[ -n "$group_config" ]]; then
            group_permissions=$(echo "$group_config" | jq -r '.permissions // "standard"')
            if [[ "$group_permissions" == "admin" ]]; then
                user_permissions="admin"
                echo "[$(date)] User has admin permissions via group $group" >> /tmp/claude-user-approval.log
                break
            elif [[ "$group_permissions" == "developer" ]] && [[ "$user_permissions" != "admin" ]]; then
                user_permissions="developer"
                echo "[$(date)] User has developer permissions via group $group" >> /tmp/claude-user-approval.log
            fi
        fi
    done
fi

# 基于用户身份的权限检查
check_user_permissions() {
    local user="$1"
    local user_id="$2"
    local groups="$3"
    local permissions="$4"

    echo "[$(date)] Checking permissions: $permissions for user $user" >> /tmp/claude-user-approval.log

    case "$permissions" in
        "admin")
            # 管理员权限：允许大部分操作
            echo "admin"
            ;;
        "developer")
            # 开发者权限：允许开发相关操作
            echo "developer"
            ;;
        "ops")
            # 运维权限：允许运维相关操作
            echo "ops"
            ;;
        "guest")
            # 访客权限：只允许最基本的操作
            echo "guest"
            ;;
        *)
            # 标准权限
            echo "standard"
            ;;
    esac
}

# 检查是否是项目所有者
is_project_owner() {
    if [[ "$current_user" == "$project_owner" ]]; then
        return 0
    else
        return 1
    fi
}

# 检查用户是否在特定的安全组中
is_in_safe_group() {
    local target_groups="$1"
    for group in $current_groups; do
        if [[ "$target_groups" =~ "$group" ]]; then
            return 0
        fi
    done
    return 1
}

# 基于用户权限级别的决策
make_user_based_decision() {
    local tool_name="$1"
    local tool_input="$2"
    local user_level="$3"

    echo "[$(date)] Making decision for user level: $user_level" >> /tmp/claude-user-approval.log

    case "$user_level" in
        "admin")
            # 管理员权限：允许大部分操作，除了最危险的
            if [[ "$tool_name" == "Bash" ]]; then
                command=$(echo "$tool_input" | jq -r '.command')
                # 即使是管理员也禁止最危险的操作
                critical_dangerous="format|fdisk|mkfs|dd if=/dev/zero"
                if [[ "$command" =~ $critical_dangerous ]]; then
                    echo '{"decision": "deny"}'
                else
                    echo '{"decision": "approve"}'
                fi
            else
                echo '{"decision": "approve"}'
            fi
            ;;
        "developer")
            # 开发者权限：允许开发相关操作
            developer_safe_tools="ls pwd echo cat grep find which head tail wc tree du"
            if [[ "$developer_safe_tools" =~ "$tool_name" ]]; then
                echo '{"decision": "approve"}'
            elif [[ "$tool_name" == "Write" ]] || [[ "$tool_name" == "Edit" ]]; then
                file_path=$(echo "$tool_input" | jq -r '.file_path')
                # 允许编辑项目文件
                if [[ "$file_path" =~ ^$project_root/ ]]; then
                    echo '{"decision": "approve"}'
                else
                    echo '{"continue": true}'
                fi
            elif [[ "$tool_name" == "Bash" ]]; then
                command=$(echo "$tool_input" | jq -r '.command')
                # 允许开发命令
                dev_commands="npm yarn pip python node git make cmake gradle mvn"
                for dev_cmd in $dev_commands; do
                    if [[ "$command" == "$dev_cmd"* ]]; then
                        echo '{"decision": "approve"}'
                        exit 0
                    fi
                done
                echo '{"continue": true}'
            else
                echo '{"continue": true}'
            fi
            ;;
        "ops")
            # 运维权限：允许运维相关操作
            ops_safe_tools="ls pwd echo cat grep find which ps top df du free netstat ss"
            if [[ "$ops_safe_tools" =~ "$tool_name" ]]; then
                echo '{"decision": "approve"}'
            elif [[ "$tool_name" == "Bash" ]]; then
                command=$(echo "$tool_input" | jq -r '.command')
                # 允许运维命令
                ops_commands="systemctl service ps top df du free netstat ss lsof uptime"
                for ops_cmd in $ops_commands; do
                    if [[ "$command" == "$ops_cmd"* ]]; then
                        echo '{"decision": "approve"}'
                        exit 0
                    fi
                done
                # 允许查看日志
                if [[ "$command" =~ grep ]] && [[ "$command" =~ /var/log ]]; then
                    echo '{"decision": "approve"}'
                    exit 0
                fi
                echo '{"continue": true}'
            else
                echo '{"continue": true}'
            fi
            ;;
        "guest")
            # 访客权限：只允许最基本的只读操作
            guest_safe_tools="ls pwd echo cat grep which date whoami"
            if [[ "$guest_safe_tools" =~ "$tool_name" ]]; then
                echo '{"decision": "approve"}'
            else
                echo '{"decision": "deny"}'
            fi
            ;;
        *)
            # 标准权限：默认行为
            echo '{"continue": true}'
            ;;
    esac
}

# 项目特定的用户权限检查
check_project_user_permissions() {
    local project_root="$1"
    local current_user="$2"

    # 检查项目中的用户权限文件
    project_user_file="$project_root/.claude-project-users.json"
    if [[ -f "$project_user_file" ]]; then
        user_role=$(jq -r ".users.\"$current_user\".role // empty" "$project_user_file" 2>/dev/null)
        if [[ -n "$user_role" ]]; then
            echo "$user_role"
            return 0
        fi
    fi

    # 默认项目权限
    if is_project_owner; then
        echo "project_owner"
    else
        echo "standard"
    fi
}

# 特殊用户规则检查
check_special_user_rules() {
    local user="$1"
    local user_id="$2"
    local tool_name="$3"

    # root 用户特殊规则
    if [[ "$user_id" == "0" ]]; then
        # root 用户也禁止最危险的操作
        if [[ "$tool_name" == "Bash" ]]; then
            command=$(echo "$tool_input" | jq -r '.command')
            root_dangerous="rm -rf /|dd if=/dev/zero of=/dev/"
            if [[ "$command" =~ $root_dangerous ]]; then
                echo "root_dangerous"
                return 0
            fi
        fi
        echo "root_safe"
        return 0
    fi

    # 系统用户特殊规则（如 www-data, nobody 等）
    if [[ $user_id -lt 1000 ]] && [[ $user_id -ne 0 ]]; then
        echo "system_user"
        return 0
    fi

    return 1
}

# 主逻辑
echo "[$(date)] Starting user-identity approval for $current_user" >> /tmp/claude-user-approval.log

# 检查特殊用户规则
special_rule=$(check_special_user_rules "$current_user" "$current_user_id" "$tool_name")
case "$special_rule" in
    "root_dangerous")
        echo "[$(date)] Root dangerous operation denied" >> /tmp/claude-user-approval.log
        echo '{"decision": "deny"}'
        exit 0
        ;;
    "root_safe")
        echo "[$(date)] Root safe operation approved" >> /tmp/claude-user-approval.log
        echo '{"decision": "approve"}'
        exit 0
        ;;
    "system_user")
        echo "[$(date)] System user limited permissions" >> /tmp/claude-user-approval.log
        # 系统用户只允许基本操作
        system_safe_tools="ls pwd echo cat grep which date"
        if [[ "$system_safe_tools" =~ "$tool_name" ]]; then
            echo '{"decision": "approve"}'
        else
            echo '{"decision": "deny"}'
        fi
        exit 0
        ;;
esac

# 获取用户权限级别
user_level=$(check_user_permissions "$current_user" "$current_user_id" "$current_groups" "$user_permissions")

# 检查项目特定权限
project_user_level=$(check_project_user_permissions "$project_root" "$current_user")

# 使用最高权限级别
final_permission="$user_level"
if [[ "$project_user_level" == "project_owner" ]] && [[ "$user_level" != "admin" ]]; then
    final_permission="developer"
fi

echo "[$(date)] Final permission level: $final_permission" >> /tmp/claude-user-approval.log

# 基于用户权限做出决策
make_user_based_decision "$tool_name" "$tool_input" "$final_permission"

# 配置文件示例：
# .claude-user-config.json
# {
#   "users": {
#     "john": {
#       "permissions": "admin",
#       "allowed_tools": ["*"],
#       "denied_tools": ["Format", "Fdisk"]
#     },
#     "jane": {
#       "permissions": "developer",
#       "allowed_projects": ["project1", "project2"]
#     },
#     "guest": {
#       "permissions": "guest",
#       "time_limit": "1hour",
#       "allowed_commands": ["ls", "pwd", "echo", "cat"]
#     }
#   },
#   "groups": {
#     "developers": {
#       "permissions": "developer"
#     },
#     "operations": {
#       "permissions": "ops"
#     },
#     "contractors": {
#       "permissions": "guest",
#       "project_limit": 3
#     }
#   },
#   "default_permissions": "standard",
#   "require_approval_for": ["Delete", "Move", "Bash"]
# }