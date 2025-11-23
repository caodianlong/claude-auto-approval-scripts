#!/bin/bash
# Claude Code 组合智能审批脚本
# 功能：结合时间窗口、用户身份、项目配置、风险评分等多种因素进行综合审批

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')
project_root=$(echo "$input" | jq -r '.context.project_root')

# 日志文件
log_file="/tmp/claude-intelligent-approval.log"
echo "========================================" >> "$log_file"
echo "[$(date)] Intelligent approval started" >> "$log_file"
echo "[$(date)] Tool: $tool_name" >> "$log_file"
echo "[$(date)] Project: $project_root" >> "$log_file"

# 获取基础信息
current_user=$(whoami)
current_time=$(date +%H:%M)
current_day=$(date +%u)
current_date=$(date +%Y-%m-%d)

# 配置文件路径
user_config="$project_root/.claude-user-config.json"
time_config="$project_root/.claude-time-config.json"
project_config="$project_root/.claude-project-config.json"
risk_config="$project_root/.claude-risk-config.json"

# 智能评分系统
calculate_intelligent_score() {
    local score=50  # 基础分数 50 分（满分 100）
    local tool_name="$1"
    local tool_input="$2"

    echo "[$(date)] Calculating intelligent score for $tool_name" >> "$log_file"

    # 1. 工具类型评分 (0-20 分)
    case "$tool_name" in
        "Read"|"ls"|"pwd"|"echo"|"cat"|"grep")
            tool_score=20
            ;;
        "find"|"which"|"head"|"tail"|"wc")
            tool_score=18
            ;;
        "Write")
            tool_score=15
            ;;
        "Edit")
            tool_score=12
            ;;
        "Bash")
            tool_score=8
            ;;
        "Delete"|"Move")
            tool_score=5
            ;;
        *)
            tool_score=10
            ;;
    esac
    score=$((score + tool_score))
    echo "[$(date)] Tool type score: $tool_score (total: $score)" >> "$log_file"

    # 2. 用户身份评分 (0-20 分)
    if [[ "$current_user" == "root" ]]; then
        user_score=20
    elif is_in_admin_group; then
        user_score=18
    elif is_in_developer_group; then
        user_score=15
    elif is_in_ops_group; then
        user_score=12
    else
        user_score=8
    fi
    score=$((score + user_score))
    echo "[$(date)] User identity score: $user_score (total: $score)" >> "$log_file"

    # 3. 时间因素评分 (0-15 分)
    current_hour=$(date +%H)
    if [[ $current_hour -ge 9 ]] && [[ $current_hour -le 17 ]]; then
        time_score=15  # 工作时间
    elif [[ $current_hour -ge 18 ]] && [[ $current_hour -le 22 ]]; then
        time_score=12  # 晚上
    else
        time_score=5   # 深夜
    fi

    if [[ $current_day -ge 6 ]]; then
        time_score=$((time_score - 3))  # 周末减分
    fi
    score=$((score + time_score))
    echo "[$(date)] Time factor score: $time_score (total: $score)" >> "$log_file"

    # 4. 项目上下文评分 (0-15 分)
    if is_project_owner; then
        project_score=15
    elif [[ "$current_user" == "$project_owner" ]]; then
        project_score=13
    elif is_git_tracked_project; then
        project_score=10
    else
        project_score=5
    fi
    score=$((score + project_score))
    echo "[$(date)] Project context score: $project_score (total: $score)" >> "$log_file"

    # 5. 输入内容风险评分 (-20 到 0 分)
    content_risk=$(calculate_content_risk "$tool_name" "$tool_input")
    score=$((score + content_risk))
    echo "[$(date)] Content risk score: $content_risk (total: $score)" >> "$log_file"

    # 确保分数在 0-100 范围内
    if [[ $score -lt 0 ]]; then
        score=0
    elif [[ $score -gt 100 ]]; then
        score=100
    fi

    echo $score
}

# 辅助函数
is_in_admin_group() {
    echo "$current_groups" | grep -qE "(root|admin|sudo|wheel)"
}

is_in_developer_group() {
    echo "$current_groups" | grep -qE "(developer|dev|engineering|programmer)"
}

is_in_ops_group() {
    echo "$current_groups" | grep -qE "(ops|operations|sysadmin)"
}

is_project_owner() {
    project_owner=$(stat -c '%U' "$project_root" 2>/dev/null || echo "unknown")
    [[ "$current_user" == "$project_owner" ]]
}

is_git_tracked_project() {
    [[ -d "$project_root/.git" ]]
}

calculate_content_risk() {
    local tool_name="$1"
    local tool_input="$2"
    local risk=0

    if [[ "$tool_name" == "Bash" ]]; then
        command=$(echo "$tool_input" | jq -r '.command')

        # 高风险命令
        if [[ "$command" =~ rm[[:space:]].*-rf ]]; then
            risk=$((risk - 15))
        elif [[ "$command" =~ curl.*\|.*sh ]] || [[ "$command" =~ wget.*\|.*sh ]]; then
            risk=$((risk - 20))
        elif [[ "$command" =~ sudo ]]; then
            risk=$((risk - 8))
        elif [[ "$command" =~ chmod[[:space:]]777 ]]; then
            risk=$((risk - 10))
        fi
    elif [[ "$tool_name" == "Write" ]]; then
        file_path=$(echo "$tool_input" | jq -r '.file_path')

        # 高风险文件路径
        if [[ "$file_path" =~ /etc/ ]] || [[ "$file_path" =~ /usr/bin/ ]]; then
            risk=$((risk - 15))
        elif [[ "$file_path" =~ \.key$ ]] || [[ "$file_path" =~ \.pem$ ]]; then
            risk=$((risk - 8))
        fi
    fi

    echo $risk
}

# 综合决策逻辑
make_intelligent_decision() {
    local score="$1"
    local tool_name="$2"

    echo "[$(date)] Final score: $score/100" >> "$log_file"

    # 基于分数的决策
    if [[ $score -ge 80 ]]; then
        echo "[$(date)] HIGH TRUST - Auto approving $tool_name" >> "$log_file"
        echo '{"decision": "approve"}'
    elif [[ $score -ge 60 ]]; then
        echo "[$(date)] MEDIUM TRUST - Auto approving safe $tool_name" >> "$log_file"
        # 中等信任：只允许相对安全的工具
        medium_trust_tools="Read ls pwd echo cat grep find which head tail wc Write Edit"
        if [[ "$medium_trust_tools" =~ "$tool_name" ]]; then
            echo '{"decision": "approve"}'
        else
            echo '{"continue": true}'
        fi
    elif [[ $score -ge 40 ]]; then
        echo "[$(date)] LOW TRUST - Requiring confirmation for $tool_name" >> "$log_file"
        echo '{"continue": true}'
    else
        echo "[$(date)] UNTRUSTED - Denying $tool_name" >> "$log_file"
        echo '{"decision": "deny"}'
    fi
}

# 机器学习模型集成（可选）
ml_predict_decision() {
    local tool_name="$1"
    local tool_input="$2"
    local context_info="$3"

    # 这里可以集成机器学习模型进行预测
    # 现在返回一个默认的安全分数
    echo "75"
}

# 上下文增强决策
contextual_decision() {
    local base_decision="$1"
    local tool_name="$2"
    local tool_input="$3"

    # 如果基础决策是拒绝，检查是否有特殊情况
    if [[ "$base_decision" == '{"decision": "deny"}' ]]; then
        # 检查是否是紧急情况
        if [[ -f "$project_root/.claude-emergency" ]]; then
            echo "[$(date)] Emergency mode detected - overriding deny decision" >> "$log_file"
            echo '{"decision": "approve"}'
            return 0
        fi

        # 检查是否是维护时间
        current_hour=$(date +%H)
        if [[ $current_hour -ge 2 ]] && [[ $current_hour -le 4 ]]; then
            echo "[$(date)] Maintenance window - considering override" >> "$log_file"
            echo '{"continue": true}'
            return 0
        fi
    fi

    echo "$base_decision"
}

# 主逻辑
echo "[$(date)] Starting intelligent approval process" >> "$log_file"

# 计算智能评分
intelligent_score=$(calculate_intelligent_score "$tool_name" "$tool_input")

# 基于评分做出基础决策
base_decision=$(make_intelligent_decision "$intelligent_score" "$tool_name")

# 上下文增强决策
final_decision=$(contextual_decision "$base_decision" "$tool_name" "$tool_input")

# 记录最终决策
echo "[$(date)] Final decision: $final_decision" >> "$log_file"
echo "========================================" >> "$log_file"

# 输出最终决策
echo "$final_decision"

# 配置文件示例：
# .claude-intelligent-config.json
# {
#   "approval_thresholds": {
#     "high_trust": 80,
#     "medium_trust": 60,
#     "low_trust": 40
#   },
#   "ml_model": {
#     "enabled": false,
#     "endpoint": "http://ml-server:8080/predict",
#     "confidence_threshold": 0.85
#   },
#   "context_rules": {
#     "emergency_override": true,
#     "maintenance_override": true,
#     "project_owner_boost": 10
#   },
#   "logging": {
#     "level": "verbose",
#     "include_scores": true,
#     "include_context": true
#   }
# }