#!/bin/bash
# Claude Code 时间窗口审批脚本
# 功能：基于时间、工作日、节假日等因素进行智能审批

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')
project_root=$(echo "$input" | jq -r '.context.project_root')

# 配置文件路径
config_file="$project_root/.claude-time-config.json"

# 默认时间配置
business_hours_start=9
business_hours_end=18
weekend_mode="strict"  # strict, normal, permissive
night_mode="strict"    # strict, normal, permissive
holiday_mode="strict"  # strict, normal, permissive

# 读取配置文件（如果存在）
if [[ -f "$config_file" ]]; then
    business_hours_start=$(jq -r '.business_hours.start // 9' "$config_file")
    business_hours_end=$(jq -r '.business_hours.end // 18' "$config_file")
    weekend_mode=$(jq -r '.weekend_mode // "strict"' "$config_file")
    night_mode=$(jq -r '.night_mode // "strict"' "$config_file")
    holiday_mode=$(jq -r '.holiday_mode // "strict"' "$config_file")
fi

# 获取当前时间信息
current_time=$(date +%H:%M)
current_hour=$(date +%H)
current_day=$(date +%u)  # 1-7 (Monday-Sunday)
current_date=$(date +%Y-%m-%d)

# 日志记录
echo "[$(date)] Time-window approval - $tool_name at $current_time" >> /tmp/claude-time-approval.log

# 检查是否是周末
is_weekend() {
    if [[ $current_day -ge 6 ]]; then  # 6 = Saturday, 7 = Sunday
        return 0
    else
        return 1
    fi
}

# 检查是否在工作时间
is_business_hours() {
    if [[ $current_hour -ge $business_hours_start ]] && [[ $current_hour -lt $business_hours_end ]]; then
        return 0
    else
        return 1
    fi
}

# 检查是否是夜间（22:00 - 06:00）
is_night_hours() {
    if [[ $current_hour -ge 22 ]] || [[ $current_hour -lt 6 ]]; then
        return 0
    else
        return 1
    fi
}

# 简单的节假日检查（可以扩展为读取实际的节假日数据）
is_holiday() {
    # 这里可以连接到节假日API或读取配置文件
    # 现在只是简单的示例
    local month_day=$(date +%m-%d)

    # 常见节假日（美国）
    holidays="01-01|07-04|12-25|12-31"  # 新年、独立日、圣诞节、除夕

    if [[ "$holidays" =~ "$month_day" ]]; then
        return 0
    else
        return 1
    fi
}

# 根据时间模式调整风险等级
adjust_risk_by_time() {
    local base_risk="$1"
    local adjusted_risk=$base_risk

    # 非工作时间增加风险
    if ! is_business_hours; then
        adjusted_risk=$((adjusted_risk + 2))
        echo "[$(date)] Non-business hours +2 risk" >> /tmp/claude-time-approval.log
    fi

    # 夜间大幅增加风险
    if is_night_hours; then
        adjusted_risk=$((adjusted_risk + 3))
        echo "[$(date)] Night hours +3 risk" >> /tmp/claude-time-approval.log
    fi

    # 周末增加风险
    if is_weekend; then
        adjusted_risk=$((adjusted_risk + 2))
        echo "[$(date)] Weekend +2 risk" >> /tmp/claude-time-approval.log
    fi

    # 节假日增加风险
    if is_holiday; then
        adjusted_risk=$((adjusted_risk + 3))
        echo "[$(date)] Holiday +3 risk" >> /tmp/claude-time-approval.log
    fi

    echo $adjusted_risk
}

# 根据时间模式做出决策
make_time_based_decision() {
    local tool_name="$1"
    local tool_input="$2"

    # 先进行基础的安全检查
    # 危险命令在任何时间都应该被拒绝
    if [[ "$tool_name" == "Bash" ]]; then
        command=$(echo "$tool_input" | jq -r '.command')
        dangerous_any_time="rm -rf /|format|fdisk|mkfs|dd if=/dev/zero"
        if [[ "$command" =~ $dangerous_any_time ]]; then
            echo '{"decision": "deny"}'
            exit 0
        fi
    fi

    # 根据时间模式进行决策
    if is_night_hours; then
        # 夜间模式
        case "$night_mode" in
            "strict")
                # 严格模式：夜间只允许最安全的操作
                safe_night_tools="ls pwd echo cat grep date whoami"
                if [[ "$safe_night_tools" =~ "$tool_name" ]]; then
                    echo '{"decision": "approve"}'
                else
                    echo '{"continue": true}'
                fi
                ;;
            "normal")
                # 正常模式：夜间增加确认
                echo '{"continue": true}'
                ;;
            "permissive")
                # 宽松模式：夜间正常审批
                echo '{"decision": "approve"}'
                ;;
        esac
    elif is_weekend; then
        # 周末模式
        case "$weekend_mode" in
            "strict")
                # 严格模式：周末只允许基本操作
                safe_weekend_tools="ls pwd echo cat grep find which date"
                if [[ "$safe_weekend_tools" =~ "$tool_name" ]]; then
                    echo '{"decision": "approve"}'
                else
                    echo '{"continue": true}'
                fi
                ;;
            "normal")
                # 正常模式：周末需要确认
                echo '{"continue": true}'
                ;;
            "permissive")
                # 宽松模式：周末正常审批
                echo '{"decision": "approve"}'
                ;;
        esac
    elif is_holiday; then
        # 节假日模式
        case "$holiday_mode" in
            "strict")
                echo '{"continue": true}'
                ;;
            "normal"|"permissive")
                echo '{"decision": "approve"}'
                ;;
        esac
    elif is_business_hours; then
        # 工作时间：正常审批
        echo '{"decision": "approve"}'
    else
        # 非工作时间但非夜间：增加确认
        echo '{"continue": true}'
    fi
}

# 特殊时间规则检查
check_special_time_rules() {
    local tool_name="$1"
    local tool_input="$2"

    # 维护时间窗口（如果有配置）
    if [[ -f "$config_file" ]]; then
        maintenance_start=$(jq -r '.maintenance_window.start // "02:00"' "$config_file")
        maintenance_end=$(jq -r '.maintenance_window.end // "04:00"' "$config_file")

        current_time_minutes=$(date +%H*60+%M | bc)
        maintenance_start_minutes=$(echo "$maintenance_start" | awk -F: '{print $1*60+$2}')
        maintenance_end_minutes=$(echo "$maintenance_end" | awk -F: '{print $1*60+$2}')

        if [[ $current_time_minutes -ge $maintenance_start_minutes ]] && [[ $current_time_minutes -le $maintenance_end_minutes ]]; then
            # 维护时间：允许更多操作
            maintenance_safe_tools="Write Edit Bash Copy Move Delete"
            if [[ "$maintenance_safe_tools" =~ "$tool_name" ]]; then
                echo "[$(date)] Maintenance window - approving $tool_name" >> /tmp/claude-time-approval.log
                echo '{"decision": "approve"}'
                return 0
            fi
        fi
    fi

    return 1
}

# 主逻辑
echo "[$(date)] Time-based approval for $tool_name" >> /tmp/claude-time-approval.log

# 检查特殊时间规则
if check_special_time_rules "$tool_name" "$tool_input"; then
    exit 0
fi

# 基于时间模式做出决策
make_time_based_decision "$tool_name" "$tool_input"

# 配置文件示例：
# .claude-time-config.json
# {
#   "business_hours": {
#     "start": 9,
#     "end": 18
#   },
#   "weekend_mode": "strict",  // strict, normal, permissive
#   "night_mode": "strict",    // strict, normal, permissive
#   "holiday_mode": "strict",
#   "maintenance_window": {
#     "start": "02:00",
#     "end": "04:00"
#   },
#   "timezone": "America/New_York",
#   "holidays": [
#     "2024-01-01", "2024-07-04", "2024-12-25"
#   ],
#   "custom_rules": {
#     "friday_afternoon": {
#       "time": "15:00-18:00",
#       "mode": "permissive"
#     }
#   }
# }