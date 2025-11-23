#!/bin/bash
# Claude Code 开发环境审批脚本
# 功能：在开发环境中相对宽松，但仍保持基本安全控制

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')
project_root=$(echo "$input" | jq -r '.context.project_root')

# 日志文件
echo "[$(date)] Development environment approval for $tool_name" >> /tmp/claude-dev-approval.log

# 开发环境白名单 - 允许更多操作
development_safe_tools="ls pwd echo cat grep find which head tail wc tree du df free ps top"
if [[ "$development_safe_tools" =~ "$tool_name" ]]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Write 操作 - 在开发环境中相对宽松
if [[ "$tool_name" == "Write" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')

    # 自动批准项目内的文件写入（除了关键目录）
    if [[ "$file_path" =~ ^$project_root/ ]] && [[ ! "$file_path" =~ /(node_modules|vendor|\.git)/ ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi

    # 自动批准临时文件和日志
    if [[ "$file_path" =~ ^/tmp/ ]] || [[ "$file_path" =~ \.tmp$ ]] || [[ "$file_path" =~ \.log$ ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi

    # 自动批准缓存文件
    if [[ "$file_path" =~ /cache/ ]] || [[ "$file_path" =~ \.cache$ ]] || [[ "$file_path" =~ /\.npm/ ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi
fi

# Edit 操作 - 允许编辑配置文件和源代码
if [[ "$tool_name" == "Edit" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')

    # 允许编辑项目内的配置文件
    if [[ "$file_path" =~ ^$project_root/ ]]; then
        safe_extensions="md|txt|json|yaml|yml|conf|config|ini|properties|xml|toml|js|py|java|cpp|c|h|hpp|ts|jsx|tsx|css|scss|html|vue"
        file_ext=$(echo "$file_path" | sed 's/.*\.//')

        if [[ "$safe_extensions" =~ "$file_ext" ]]; then
            echo '{"decision": "approve"}'
            exit 0
        fi
    fi
fi

# Bash 命令 - 开发环境允许更多命令
if [[ "$tool_name" == "Bash" ]]; then
    command=$(echo "$tool_input" | jq -r '.command')

    # 拒绝危险命令（在任何环境下都拒绝）
    dangerous_patterns="rm -rf /|chmod 777 /|curl.*sh|wget.*sh|dd if=/dev/zero|mkfs|fdisk"
    if [[ "$command" =~ $dangerous_patterns ]]; then
        echo '{"decision": "deny"}'
        exit 0
    fi

    # 开发环境允许的命令
    dev_commands="npm yarn pip pip3 python python3 node ruby gem bundle composer"
    for dev_cmd in $dev_commands; do
        if [[ "$command" == "$dev_cmd"* ]]; then
            echo '{"decision": "approve"}'
            exit 0
        fi
    done

    # 允许开发工具
    development_tools="git docker docker-compose make cmake gradle mvn ant"
    for tool in $development_tools; do
        if [[ "$command" == "$tool"* ]]; then
            echo '{"decision": "approve"}'
            exit 0
        fi
    done

    # 允许代码格式化工具
    format_tools="prettier eslint tslint black autopep8 clang-format gofmt rustfmt"
    for tool in $format_tools; do
        if [[ "$command" == "$tool"* ]]; then
            echo '{"decision": "approve"}'
            exit 0
        fi
    done

    # 允许测试命令
    test_commands="test jest mocha jasmine pytest unittest go test cargo test"
    for test_cmd in $test_commands; do
        if [[ "$command" == *"$test_cmd"* ]]; then
            echo '{"decision": "approve"}'
            exit 0
        fi
    done
fi

# Delete 操作 - 在开发环境中允许删除更多文件
if [[ "$tool_name" == "Delete" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')

    # 允许删除项目内的临时文件
    if [[ "$file_path" =~ ^$project_root/ ]] && [[ "$file_path" =~ \.(tmp|temp|cache|log)$ ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi

    # 允许删除node_modules（重新安装）
    if [[ "$file_path" =~ /node_modules$ ]] || [[ "$file_path" =~ /node_modules/ ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi

    # 允许删除构建输出
    if [[ "$file_path" =~ /(build|dist|target|out)/ ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi
fi

echo '{"continue": true}'

# 配置文件示例：
# .claude-dev-config.json
# {
#   "environment": "development",
#   "allow_node_modules_delete": true,
#   "allow_build_clean": true,
#   "auto_approve_patterns": ["*.tmp", "*.log", "*.cache"],
#   "extra_safe_commands": ["nodemon", "ts-node", "webpack", "vite", "parcel"]
# }