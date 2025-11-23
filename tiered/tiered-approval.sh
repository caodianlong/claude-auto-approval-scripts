#!/bin/bash
# Claude Code 分层审批策略脚本
# 功能：基于风险评分系统，将操作分为低风险、中风险、高风险三个层级

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')
project_root=$(echo "$input" | jq -r '.context.project_root')

# 日志文件
log_file="/tmp/claude-tiered-approval.log"
echo "[$(date)] Tiered approval processing $tool_name" >> "$log_file"

# 风险评分计算器
calculate_risk_level() {
    local input="$1"
    local tool_name=$(echo "$input" | jq -r '.tool_name')
    local tool_input=$(echo "$input" | jq -r '.tool_input')

    # 基础风险评分
    local risk_score=0

    echo "[$(date)] Calculating risk for $tool_name" >> "$log_file"

    # 基于工具类型的基础评分
    case "$tool_name" in
        "Read")    risk_score=0 ;;
        "ls")      risk_score=0 ;;
        "pwd")     risk_score=0 ;;
        "echo")    risk_score=0 ;;
        "cat")     risk_score=0 ;;
        "grep")    risk_score=0 ;;
        "find")    risk_score=1 ;;
        "Write")   risk_score=2 ;;
        "Edit")    risk_score=3 ;;
        "Bash")    risk_score=4 ;;
        "Delete")  risk_score=5 ;;
        "Move")    risk_score=4 ;;
        "Copy")    risk_score=2 ;;
        *)         risk_score=3 ;;  # 未知工具默认为中等风险
    esac

    echo "[$(date)] Base risk score for $tool_name: $risk_score" >> "$log_file"

    # 基于输入内容的额外评分
    if [[ "$tool_input" =~ /etc/ ]] || [[ "$tool_input" =~ /usr/bin/ ]] || [[ "$tool_input" =~ /bin/ ]]; then
        risk_score=$((risk_score + 5))  # 系统目录高风险
        echo "[$(date)] System directory detected, +5 risk" >> "$log_file"
    fi

    if [[ "$tool_input" =~ /home/ ]] || [[ "$tool_input" =~ /Users/ ]]; then
        risk_score=$((risk_score + 1))  # 用户目录中等风险
        echo "[$(date)] User directory detected, +1 risk" >> "$log_file"
    fi

    if [[ "$tool_input" =~ \.key$ ]] || [[ "$tool_input" =~ \.pem$ ]] || [[ "$tool_input" =~ \.p12$ ]]; then
        risk_score=$((risk_score + 4))  # 密钥文件高风险
        echo "[$(date)] Key file detected, +4 risk" >> "$log_file"
    fi

    # 基于命令内容的额外评分（针对 Bash）
    if [[ "$tool_name" == "Bash" ]]; then
        command=$(echo "$tool_input" | jq -r '.command')

        if [[ "$command" =~ rm[[:space:]].*-rf ]]; then
            risk_score=$((risk_score + 6))  # 强制删除极高风险
            echo "[$(date)] Force delete detected, +6 risk" >> "$log_file"
        elif [[ "$command" =~ rm[[:space:]] ]]; then
            risk_score=$((risk_score + 3))  # 普通删除高风险
            echo "[$(date)] Delete command detected, +3 risk" >> "$log_file"
        fi

        if [[ "$command" =~ curl.*\|.*sh ]] || [[ "$command" =~ wget.*\|.*sh ]]; then
            risk_score=$((risk_score + 8))  # 管道到 shell 极高风险
            echo "[$(date)] Pipe to shell detected, +8 risk" >> "$log_file"
        fi

        if [[ "$command" =~ chmod[[:space:]]777 ]]; then
            risk_score=$((risk_score + 4))  # 完全权限高风险
            echo "[$(date)] chmod 777 detected, +4 risk" >> "$log_file"
        fi

        if [[ "$command" =~ sudo ]]; then
            risk_score=$((risk_score + 3))  # sudo 命令高风险
            echo "[$(date)] sudo detected, +3 risk" >> "$log_file"
        fi
    fi

    # 基于文件状态的额外评分（针对 Write/Edit）
    if [[ "$tool_name" == "Write" ]] || [[ "$tool_name" == "Edit" ]]; then
        file_path=$(echo "$tool_input" | jq -r '.file_path')

        # 如果文件已存在并且是重要文件类型
        if [[ -f "$file_path" ]]; then
            if [[ "$file_path" =~ \.(conf|config|ini|properties)$ ]]; then
                risk_score=$((risk_score + 2))  # 配置文件修改风险
                echo "[$(date)] Config file modification, +2 risk" >> "$log_file"
            fi

            # 检查文件大小（大文件风险更高）
            file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo "0")
            if [[ $file_size -gt 1048576 ]]; then  # 大于 1MB
                risk_score=$((risk_score + 1))
                echo "[$(date)] Large file detected, +1 risk" >> "$log_file"
            fi
        fi
    fi

    # 基于时间的额外评分
    current_hour=$(date +%H)
    if [[ $current_hour -ge 22 ]] || [[ $current_hour -le 6 ]]; then
        risk_score=$((risk_score + 1))  # 夜间操作增加风险
        echo "[$(date)] Night time operation, +1 risk" >> "$log_file"
    fi

    echo "[$(date)] Final risk score: $risk_score" >> "$log_file"

    # 根据总分返回风险等级
    if [[ $risk_score -le 2 ]]; then
        echo "low"
    elif [[ $risk_score -le 5 ]]; then
        echo "medium"
    else
        echo "high"
    fi
}

# 基于风险等级的决策函数
make_decision() {
    local risk_level="$1"
    local tool_name="$2"

    case "$risk_level" in
        "low")
            echo "[$(date)] Low risk - Auto approving $tool_name" >> "$log_file"
            echo '{"decision": "approve"}'
            ;;
        "medium")
            echo "[$(date)] Medium risk - Requiring confirmation for $tool_name" >> "$log_file"
            echo '{"continue": true}'
            ;;
        "high")
            echo "[$(date)] High risk - Denying $tool_name" >> "$log_file"
            echo '{"decision": "deny"}'
            ;;
        *)
            echo "[$(date)] Unknown risk level - Requiring confirmation for $tool_name" >> "$log_file"
            echo '{"continue": true}'
            ;;
    esac
}

# 特殊规则检查（可以覆盖风险评分）
check_special_rules() {
    local tool_name="$1"
    local tool_input="$2"

    # 白名单规则
    if [[ "$tool_name" == "Write" ]]; then
        file_path=$(echo "$tool_input" | jq -r '.file_path')

        # 总是批准临时文件
        if [[ "$file_path" =~ ^/tmp/ ]] || [[ "$file_path" =~ \.tmp$ ]] || [[ "$file_path" =~ /tmp/ ]]; then
            echo "whitelist_temp"
            return 0
        fi

        # 总是批准日志文件
        if [[ "$file_path" =~ \.log$ ]] || [[ "$file_path" =~ /logs?/ ]]; then
            echo "whitelist_logs"
            return 0
        fi
    fi

    # 黑名单规则
    if [[ "$tool_name" == "Bash" ]]; then
        command=$(echo "$tool_input" | jq -r '.command')

        # 绝对禁止的命令
        if [[ "$command" =~ format[[:space:]] ]] || [[ "$command" =~ fdisk[[:space:]] ]]; then
            echo "blacklist_critical"
            return 0
        fi

        # 禁止删除系统文件
        if [[ "$command" =~ rm[[:space:]].*/(etc|usr|bin|sbin|lib|proc|sys|dev) ]]; then
            echo "blacklist_system_delete"
            return 0
        fi
    fi

    echo "none"
}

# 主逻辑
echo "[$(date)] Starting tiered approval for $tool_name" >> "$log_file"

# 检查特殊规则
special_rule=$(check_special_rules "$tool_name" "$tool_input")
case "$special_rule" in
    "whitelist_temp"|"whitelist_logs")
        echo "[$(date)] Special whitelist rule applied" >> "$log_file"
        echo '{"decision": "approve"}'
        exit 0
        ;;
    "blacklist_critical"|"blacklist_system_delete")
        echo "[$(date)] Special blacklist rule applied" >> "$log_file"
        echo '{"decision": "deny"}'
        exit 0
        ;;
esac

# 计算风险等级
risk_level=$(calculate_risk_level "$input")

# 根据风险等级做出决策
make_decision "$risk_level" "$tool_name"

exit 0

# 使用示例：
# echo '{"tool_name": "Bash", "tool_input": {"command": "ls -la"}, "context": {"project_root": "/home/user/project"}}' | bash tiered-approval.sh
# echo '{"tool_name": "Write", "tool_input": {"file_path": "/tmp/test.txt"}, "context": {"project_root": "/home/user/project"}}' | bash tiered-approval.sh
# echo '{"tool_name": "Bash", "tool_input": {"command": "rm -rf /important"}, "context": {"project_root": "/home/user/project"}}' | bash tiered-approval.sh

# 配置文件示例（可选）：
# ~/.claude-tiered-config.json
# {
#   "risk_thresholds": {
#     "low": 2,
#     "medium": 5,
#     "high": 10
#   },
#   "whitelist_patterns": ["^/tmp/", "\.log$", "^/home/.*/temp/"],
#   "blacklist_patterns": ["/etc/passwd", "/etc/shadow", "^/usr/bin/"],
#   "time_multipliers": {
#     "day": 1.0,
#     "night": 1.5,
#     "weekend": 1.3
#   }
# }