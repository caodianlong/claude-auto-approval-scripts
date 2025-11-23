#!/bin/bash
# Claude Code 生产环境审批脚本
# 功能：在生产环境中非常严格，只允许最安全的操作

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')
project_root=$(echo "$input" | jq -r '.context.project_root')

# 生产环境日志
echo "[$(date)] PRODUCTION ENVIRONMENT - Processing $tool_name" >> /tmp/claude-prod-approval.log
echo "[$(date)] Project root: $project_root" >> /tmp/claude-prod-approval.log

# 生产环境只允许最安全的只读命令
prod_readonly_commands="ls pwd echo date whoami uname"
if [[ "$prod_readonly_commands" =~ "$tool_name" ]]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# 严格限制的其他命令
if [[ "$tool_name" == "cat" ]] || [[ "$tool_name" == "grep" ]]; then
    # 只允许查看日志文件和配置文件
    if [[ "$tool_input" =~ \.log$ ]] || [[ "$tool_input" =~ \.conf$ ]] || [[ "$tool_input" =~ \.config$ ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi
fi

# Write 操作 - 生产环境极其严格
if [[ "$tool_name" == "Write" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')
    echo "[$(date)] PRODUCTION Write request for: $file_path" >> /tmp/claude-prod-approval.log

    # 只允许写入特定的日志目录
    if [[ "$file_path" =~ /var/log/ ]] || [[ "$file_path" =~ /logs/ ]]; then
        # 确保只是日志文件
        if [[ "$file_path" =~ \.log$ ]] || [[ "$file_path" =~ \.txt$ ]]; then
            echo "[$(date)] Approved log file write" >> /tmp/claude-prod-approval.log
            echo '{"decision": "approve"}'
            exit 0
        fi
    fi

    # 拒绝所有其他写入操作
    echo "[$(date)] PRODUCTION Write denied - not in approved log directory" >> /tmp/claude-prod-approval.log
    echo '{"decision": "deny"}'
    exit 0
fi

# Edit 操作 - 生产环境基本不允许
if [[ "$tool_name" == "Edit" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')
    echo "[$(date)] PRODUCTION Edit request for: $file_path" >> /tmp/claude-prod-approval.log

    # 只允许编辑特定的配置文件（需要非常小心）
    if [[ "$file_path" =~ \.(conf|config|ini)$ ]] && [[ "$file_path" =~ /etc/ ]]; then
        echo "[$(date)] WARNING: Production config edit requires confirmation" >> /tmp/claude-prod-approval.log
        echo '{"continue": true}'
        exit 0
    fi

    echo "[$(date)] PRODUCTION Edit denied - not approved config file" >> /tmp/claude-prod-approval.log
    echo '{"decision": "deny"}'
    exit 0
fi

# Bash 命令 - 生产环境极其严格
if [[ "$tool_name" == "Bash" ]]; then
    command=$(echo "$tool_input" | jq -r '.command')
    echo "[$(date)] PRODUCTION Bash command: $command" >> /tmp/claude-prod-approval.log

    # 绝对禁止危险命令
    dangerous_patterns="rm|chmod|curl|wget|dd|mkfs|fdisk|format|sudo|su"
    if [[ "$command" =~ $dangerous_patterns ]]; then
        echo "[$(date)] PRODUCTION Dangerous command denied" >> /tmp/claude-prod-approval.log
        echo '{"decision": "deny"}'
        exit 0
    fi

    # 只允许状态查看命令
    status_commands="ps top netstat ss lsof df du free uptime"
    for status_cmd in $status_commands; do
        if [[ "$command" == "$status_cmd" ]] || [[ "$command" == "$status_cmd"* ]]; then
            echo "[$(date)] Approved status command: $status_cmd" >> /tmp/claude-prod-approval.log
            echo '{"decision": "approve"}'
            exit 0
        fi
    done

    # 只允许查看服务状态
    if [[ "$command" =~ ^systemctl[[:space:]]+status ]] || [[ "$command" =~ ^service[[:space:]]+.*[[:space:]]+status ]]; then
        echo "[$(date)] Approved service status check" >> /tmp/claude-prod-approval.log
        echo '{"decision": "approve"}'
        exit 0
    fi

    echo "[$(date)] PRODUCTION Bash command denied - not approved status command" >> /tmp/claude-prod-approval.log
    echo '{"decision": "deny"}'
    exit 0
fi

# Delete 操作 - 生产环境基本不允许
if [[ "$tool_name" == "Delete" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')
    echo "[$(date)] PRODUCTION Delete request for: $file_path" >> /tmp/claude-prod-approval.log

    # 只允许删除特定的临时文件
    if [[ "$file_path" =~ ^/tmp/ ]] && [[ "$file_path" =~ \.tmp$ ]]; then
        echo "[$(date)] Approved temp file deletion" >> /tmp/claude-prod-approval.log
        echo '{"decision": "approve"}'
        exit 0
    fi

    echo "[$(date)] PRODUCTION Delete denied - not approved temp file" >> /tmp/claude-prod-approval.log
    echo '{"decision": "deny"}'
    exit 0
fi

# Copy/Move 操作 - 生产环境不允许
if [[ "$tool_name" == "Copy" ]] || [[ "$tool_name" == "Move" ]]; then
    echo "[$(date)] PRODUCTION Copy/Move operations denied in production" >> /tmp/claude-prod-approval.log
    echo '{"decision": "deny"}'
    exit 0
fi

# 其他工具 - 生产环境默认拒绝
echo "[$(date)] PRODUCTION Unknown tool denied: $tool_name" >> /tmp/claude-prod-approval.log
echo '{"decision": "deny"}'

# 生产环境配置要求：
# 1. 必须启用详细的审计日志
# 2. 所有拒绝操作都应该记录原因
# 3. 定期审查审批日志
# 4. 配置监控系统告警
# 5. 建立紧急维护流程
# 6. 定期备份重要数据
# 7. 最小权限原则

# 紧急维护模式配置：
# {
#   "emergency_maintenance": false,
#   "maintenance_window": "02:00-04:00",
#   "approved_admin_users": ["admin", "root"],
#   "emergency_contact": "ops-team@company.com"
# }