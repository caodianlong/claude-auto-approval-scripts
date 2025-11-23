#!/bin/bash
# Claude Code 智能上下文感知审批脚本
# 功能：基于项目类型、Git状态、文件类型等上下文进行智能审批

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')
project_root=$(echo "$input" | jq -r '.context.project_root')

# 日志文件（可选）
log_file="/tmp/claude-smart-approval.log"
echo "[$(date)] Smart approval processing $tool_name" >> "$log_file"

# 检查项目类型和状态的辅助函数
is_git_repo() {
    git -C "$project_root" rev-parse --git-dir >/dev/null 2>&1
}

get_git_status() {
    if is_git_repo; then
        git -C "$project_root" status --porcelain
    fi
}

is_git_tracked() {
    local file="$1"
    if is_git_repo; then
        git -C "$project_root" ls-files --error-unmatch "$file" >/dev/null 2>&1
    else
        return 1
    fi
}

get_file_extension() {
    local file="$1"
    echo "${file##*.}" | tr '[:upper:]' '[:lower:]'
}

# 读取项目配置文件（如果存在）
config_file="$project_root/.claude-auto-approve.json"
if [[ -f "$config_file" ]]; then
    echo "[$(date)] Found project config: $config_file" >> "$log_file"
    auto_approve_patterns=$(jq -r '.auto_approve_patterns[]?' "$config_file" 2>/dev/null)
    deny_patterns=$(jq -r '.deny_patterns[]?' "$config_file" 2>/dev/null)
fi

# Write 操作的智能审批
if [[ "$tool_name" == "Write" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')
    echo "[$(date)] Processing Write for: $file_path" >> "$log_file"

    # 自动批准临时文件和缓存
    if [[ "$file_path" =~ ^/tmp/ ]] || [[ "$file_path" =~ \.tmp$ ]] || [[ "$file_path" =~ /cache/ ]] || [[ "$file_path" =~ \.cache$ ]]; then
        echo "[$(date)] Auto-approved temp/cache file" >> "$log_file"
        echo '{"decision": "approve"}'
        exit 0
    fi

    # 自动批准日志文件
    if [[ "$file_path" =~ /logs?/ ]] || [[ "$file_path" =~ \.log$ ]] || [[ "$file_path" =~ /debug/ ]]; then
        echo "[$(date)] Auto-approved log file" >> "$log_file"
        echo '{"decision": "approve"}'
        exit 0
    fi

    # 自动批准构建输出
    if [[ "$file_path" =~ /(build|dist|target|output|out)/ ]]; then
        echo "[$(date)] Auto-approved build output" >> "$log_file"
        echo '{"decision": "approve"}'
        exit 0
    fi

    # 基于文件扩展名的智能判断
    file_ext=$(get_file_extension "$file_path")
    case "$file_ext" in
        tmp|temp|log|cache|bak)
            echo '{"decision": "approve"}'
            exit 0
            ;;
        md|txt|rst|doc)
            # 文档文件相对安全
            if ! is_git_tracked "$file_path"; then
                echo '{"decision": "approve"}'
                exit 0
            fi
            ;;
        js|py|java|cpp|c|h|hpp|ts|jsx|tsx)
            # 源代码文件需要更谨慎
            if is_git_tracked "$file_path"; then
                echo "[$(date)] Source file is git tracked, requiring confirmation" >> "$log_file"
                echo '{"continue": true}'
                exit 0
            fi
            ;;
    esac

    # 如果文件已被 Git 跟踪，更加谨慎
    if is_git_tracked "$file_path"; then
        echo "[$(date)] File is git tracked, requiring confirmation" >> "$log_file"
        echo '{"continue": true}'
        exit 0
    fi
fi

# Edit 操作的智能审批
if [[ "$tool_name" == "Edit" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')

    # 只允许编辑相对安全的文件类型
    safe_extensions="md|txt|json|yaml|yml|conf|config|ini|properties|xml|toml"
    file_ext=$(get_file_extension "$file_path")

    if [[ "$safe_extensions" =~ "$file_ext" ]]; then
        # 配置文件可以相对宽松
        if [[ "$file_path" =~ \.(json|yaml|yml|conf|config|ini)$ ]]; then
            echo '{"decision": "approve"}'
            exit 0
        fi

        # 如果是git跟踪的文档文件，需要确认
        if is_git_tracked "$file_path" && [[ "$file_ext" =~ (md|txt|rst)$ ]]; then
            echo '{"continue": true}'
            exit 0
        fi
    fi
fi

# Bash 命令的智能审批
if [[ "$tool_name" == "Bash" ]]; then
    command=$(echo "$tool_input" | jq -r '.command')
    echo "[$(date)] Processing Bash command: $command" >> "$log_file"

    # 拒绝危险命令
    dangerous_patterns="rm -rf|chmod 777|curl.*sh|wget.*sh|dd if=/dev/zero|mkfs|fdisk"
    if [[ "$command" =~ $dangerous_patterns ]]; then
        echo "[$(date)] Dangerous command denied" >> "$log_file"
        echo '{"decision": "deny"}'
        exit 0
    fi

    # 基于项目类型的智能审批
    if [[ -f "$project_root/package.json" ]]; then
        # Node.js 项目
        if [[ "$command" =~ ^npm ]]; then
            safe_npm_commands="install list audit outdated update"
            for safe_cmd in $safe_npm_commands; do
                if [[ "$command" =~ $safe_cmd ]]; then
                    echo "[$(date)] Approved npm command: $safe_cmd" >> "$log_file"
                    echo '{"decision": "approve"}'
                    exit 0
                fi
            done
        fi

        if [[ "$command" =~ ^yarn ]]; then
            safe_yarn_commands="install list audit outdated update"
            for safe_cmd in $safe_yarn_commands; do
                if [[ "$command" =~ $safe_cmd ]]; then
                    echo "[$(date)] Approved yarn command: $safe_cmd" >> "$log_file"
                    echo '{"decision": "approve"}'
                    exit 0
                fi
            done
        fi
    fi

    if [[ -f "$project_root/requirements.txt" ]] || [[ -f "$project_root/setup.py" ]]; then
        # Python 项目
        if [[ "$command" =~ ^pip ]]; then
            safe_pip_commands="install list show freeze"
            for safe_cmd in $safe_pip_commands; do
                if [[ "$command" =~ $safe_cmd ]]; then
                    echo "[$(date)] Approved pip command: $safe_cmd" >> "$log_file"
                    echo '{"decision": "approve"}'
                    exit 0
                fi
            done
        fi
    fi

    if [[ -f "$project_root/pom.xml" ]] || [[ -f "$project_root/build.gradle" ]]; then
        # Java 项目
        if [[ "$command" =~ ^mvn ]]; then
            safe_mvn_commands="compile test package install"
            for safe_cmd in $safe_mvn_commands; do
                if [[ "$command" =~ $safe_cmd ]]; then
                    echo "[$(date)] Approved mvn command: $safe_cmd" >> "$log_file"
                    echo '{"decision": "approve"}'
                    exit 0
                fi
            done
        fi
    fi

    # 批准常见的安全命令
    safe_system_commands="ls pwd echo date whoami which uname ps top df du free"
    for safe_cmd in $safe_system_commands; do
        if [[ "$command" == "$safe_cmd" ]] || [[ "$command" == "$safe_cmd"* ]]; then
            echo '{"decision": "approve"}'
            exit 0
        fi
    done

    # 批准简单的目录操作
    if [[ "$command" =~ ^cd[[:space:]] ]] || [[ "$command" == "cd" ]] || [[ "$command" =~ ^ls[[:space:]] ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi
fi

# Delete 操作需要特别谨慎
if [[ "$tool_name" == "Delete" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')

    # 只允许删除临时文件和日志文件
    if [[ "$file_path" =~ ^/tmp/ ]] || [[ "$file_path" =~ \.tmp$ ]] || [[ "$file_path" =~ \.log$ ]] || [[ "$file_path" =~ /cache/ ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi

    # 其他删除操作需要确认
    echo '{"continue": true}'
    exit 0
fi

echo "[$(date)] Default: requiring confirmation" >> "$log_file"
echo '{"continue": true}'