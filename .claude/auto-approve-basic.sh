#!/bin/bash
# Claude Code 基础安全审批脚本
# 功能：自动审批安全的只读操作，对写操作和bash命令进行安全检查

# 读取标准输入的JSON数据
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')

# 记录日志（可选）
# log_file="/tmp/claude-approval.log"
# echo "[$(date)] Processing $tool_name request" >> "$log_file"

# 自动批准安全的只读操作
safe_readonly_tools="ls pwd echo cat grep find which head tail wc"
if [[ "$safe_readonly_tools" =~ "$tool_name" ]]; then
    # echo "[$(date)] Auto-approved safe tool: $tool_name" >> "$log_file"
    echo '{"decision": "approve"}'
    exit 0
fi

# Write 操作 - 基于文件路径判断
if [[ "$tool_name" == "Write" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')

    # 自动批准临时文件
    if [[ "$file_path" =~ ^/tmp/ ]] || [[ "$file_path" =~ \.tmp$ ]] || [[ "$file_path" =~ /temp/ ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi

    # 自动批准日志文件
    if [[ "$file_path" =~ /logs?/ ]] || [[ "$file_path" =~ \.log$ ]] || [[ "$file_path" =~ /log/ ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi

    # 自动批准构建输出
    if [[ "$file_path" =~ /(build|dist|target|output)/ ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi

    # 自动批准缓存文件
    if [[ "$file_path" =~ /cache/ ]] || [[ "$file_path" =~ \.cache$ ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi
fi

# Bash 命令 - 基于命令内容判断
if [[ "$tool_name" == "Bash" ]]; then
    command=$(echo "$tool_input" | jq -r '.command')

    # 拒绝危险命令
    dangerous_patterns="rm -rf|chmod 777|curl.*sh|wget.*sh|> /dev/null|dd if=/dev/zero"
    if [[ "$command" =~ $dangerous_patterns ]]; then
        echo '{"decision": "deny"}'
        exit 0
    fi

    # 批准安全命令
    safe_commands="ls pwd echo date whoami which npm install pip install yarn install"
    for safe_cmd in $safe_commands; do
        if [[ "$command" == "$safe_cmd"* ]]; then
            echo '{"decision": "approve"}'
            exit 0
        fi
    done

    # 批准简单的目录导航
    if [[ "$command" =~ ^cd[[:space:]] ]] || [[ "$command" == "cd" ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi
fi

# Edit 操作 - 相对谨慎
if [[ "$tool_name" == "Edit" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')

    # 只允许编辑特定类型的文件
    if [[ "$file_path" =~ \.(txt|md|json|yaml|yml|conf|config)$ ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi
fi

# 默认继续（弹出确认对话框）
echo '{"continue": true}'