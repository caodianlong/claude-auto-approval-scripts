#!/bin/bash
# Claude Code 审批脚本调试工具
# 功能：帮助调试审批脚本，显示详细的执行过程和变量信息

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 调试配置
DEBUG_LEVEL="${DEBUG_LEVEL:-3}"  # 0=ERROR, 1=WARN, 2=INFO, 3=DEBUG
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
DEBUG_LOG="/tmp/claude-approval-debug_${TIMESTAMP}.log"

# 调试日志函数
debug_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')

    # 根据调试级别过滤日志
    case "$level" in
        "ERROR") level_num=0 ;;
        "WARN")  level_num=1 ;;
        "INFO")  level_num=2 ;;
        "DEBUG") level_num=3 ;;
        *)       level_num=2 ;;
    esac

    if [[ $level_num -le $DEBUG_LEVEL ]]; then
        echo "[$timestamp] [$level] $message" | tee -a "$DEBUG_LOG"
    fi
}

# 显示帮助信息
show_help() {
    echo -e "${BLUE}Claude Code 审批脚本调试工具${NC}"
    echo ""
    echo -e "${CYAN}用法:${NC} ./debug-approval-script.sh [选项] <脚本路径> <测试输入>"
    echo ""
    echo -e "${CYAN}选项:${NC}"
    echo "  -h, --help          显示帮助信息"
    echo "  -d, --debug         设置调试级别 (0-3, 默认: 3)"
    echo "  -s, --step          逐步执行模式"
    echo "  -v, --variables     显示变量值"
    echo "  -t, --trace         显示执行跟踪"
    echo "  -p, --performance   性能分析"
    echo "  -c, --config        显示配置信息"
    echo ""
    echo -e "${CYAN}示例:${NC}"
    echo "  ./debug-approval-script.sh ../basic/auto-approve-basic.sh '{\"tool_name\": \"ls\", \"tool_input\": {\"path\": \"/tmp\"}}'"
    echo "  ./debug-approval-script.sh -d 3 -s ../smart/smart-context-approve.sh test-input.json"
    echo ""
}

# 解析命令行参数
parse_args() {
    STEP_MODE=false
    SHOW_VARIABLES=false
    SHOW_TRACE=false
    PERFORMANCE_MODE=false
    SHOW_CONFIG=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--debug)
                DEBUG_LEVEL="$2"
                shift 2
                ;;
            -s|--step)
                STEP_MODE=true
                shift
                ;;
            -v|--variables)
                SHOW_VARIABLES=true
                shift
                ;;
            -t|--trace)
                SHOW_TRACE=true
                shift
                ;;
            -p|--performance)
                PERFORMANCE_MODE=true
                shift
                ;;
            -c|--config)
                SHOW_CONFIG=true
                shift
                ;;
            *)
                if [[ -z "$SCRIPT_PATH" ]]; then
                    SCRIPT_PATH="$1"
                elif [[ -z "$TEST_INPUT" ]]; then
                    TEST_INPUT="$1"
                fi
                shift
                ;;
        esac
    done

    # 验证必要参数
    if [[ -z "$SCRIPT_PATH" ]]; then
        debug_log "ERROR" "未指定脚本路径"
        show_help
        exit 1
    fi

    if [[ ! -f "$SCRIPT_PATH" ]]; then
        debug_log "ERROR" "脚本文件不存在: $SCRIPT_PATH"
        exit 1
    fi

    if [[ -z "$TEST_INPUT" ]]; then
        debug_log "ERROR" "未提供测试输入"
        show_help
        exit 1
    fi
}

# 分析脚本结构
analyze_script() {
    local script_path="$1"

    debug_log "INFO" "分析脚本结构: $(basename "$script_path")"
    echo -e "${CYAN}脚本分析:${NC}"

    # 检查脚本类型
    if head -1 "$script_path" | grep -q "bash"; then
        echo -e "${GREEN}✓${NC} 脚本类型: Bash 脚本"
    elif head -1 "$script_path" | grep -q "sh"; then
        echo -e "${GREEN}✓${NC} 脚本类型: Shell 脚本"
    else
        echo -e "${YELLOW}!${NC} 脚本类型: 未知"
    fi

    # 检查执行权限
    if [[ -x "$script_path" ]]; then
        echo -e "${GREEN}✓${NC} 执行权限: 已设置"
    else
        echo -e "${RED}✗${NC} 执行权限: 未设置"
        echo "  运行: chmod +x $script_path"
    fi

    # 检查依赖
    echo -e "${BLUE}依赖检查:${NC}"
    local deps=("jq" "bc" "date")
    for dep in "${deps[@]}"; do
        if command -v "$dep" >/dev/null 2&1; then
            echo -e "${GREEN}✓${NC} $dep: 已安装"
        else
            echo -e "${RED}✗${NC} $dep: 未安装"
        fi
    done

    # 统计信息
    echo -e "${BLUE}统计信息:${NC}"
    echo "  代码行数: $(wc -l < "$script_path")"
    echo "  函数数量: $(grep -c "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$script_path" || echo 0)"
    echo "  条件判断: $(grep -c "if\|case" "$script_path" || echo 0)"
    echo ""
}

# 验证输入格式
validate_input() {
    local input_data="$1"

    debug_log "INFO" "验证输入数据格式"

    # 检查是否为有效的 JSON
    if ! echo "$input_data" | jq . >/dev/null 2>&1; then
        debug_log "ERROR" "输入数据不是有效的 JSON 格式"
        return 1
    fi

    # 检查必需字段
    local required_fields=("tool_name" "tool_input" "context")
    for field in "${required_fields[@]}"; do
        if ! echo "$input_data" | jq -e ".$field" >/dev/null 2>&1; then
            debug_log "ERROR" "缺少必需字段: $field"
            return 1
        fi
    done

    # 提取并显示输入信息
    local tool_name=$(echo "$input_data" | jq -r '.tool_name')
    local project_root=$(echo "$input_data" | jq -r '.context.project_root')

    debug_log "INFO" "工具名称: $tool_name"
    debug_log "INFO" "项目根目录: $project_root"
    debug_log "INFO" "输入数据格式验证通过"

    return 0
}

# 显示变量信息
show_variables() {
    local script_path="$1"

    debug_log "INFO" "分析脚本变量使用情况"
    echo -e "${CYAN}变量分析:${NC}"

    # 查找变量定义
    echo "环境变量:"
    grep -n "^[A-Z_][A-Z0-9_]*=" "$script_path" | head -10 || echo "  无环境变量定义"

    echo ""
    echo "局部变量:"
    grep -n "local " "$script_path" | head -10 || echo "  无局部变量定义"

    echo ""
    echo "输入变量:"
    grep -n "input\|tool_name\|tool_input" "$script_path" | head -10 || echo "  无输入变量处理"

    echo ""
}

# 逐步执行模式
step_execution() {
    local script_path="$1"
    local input_data="$2"

    debug_log "INFO" "开始逐步执行模式"
    echo -e "${CYAN}逐步执行:${NC}"

    # 创建临时调试脚本
    local debug_script="/tmp/claude-debug-$$.sh"

    # 添加调试信息到脚本
    cat << 'EOF' > "$debug_script"
#!/bin/bash
# 调试版本 - 添加了详细的执行跟踪

set -x  # 启用执行跟踪

# 记录每个重要步骤
debug_step() {
    echo "[STEP] $1" >> "$DEBUG_LOG"
    echo "[VARS] $(env | grep -E 'tool_|project_|current_' | head -5)" >> "$DEBUG_LOG"
}

# 读取输入
input=\$(cat)
debug_step "读取输入数据"

# 解析 JSON
tool_name=\$(echo "\$input" | jq -r '.tool_name')
debug_step "解析工具名称: \$tool_name"

# 继续执行原始逻辑...
EOF

    # 添加原始脚本内容（去除shebang）
    tail -n +2 "$script_path" >> "$debug_script"

    # 执行调试脚本
    echo -e "${YELLOW}正在执行调试脚本...${NC}"
    local result=$(echo "$input_data" | bash "$debug_script" 2>&1)

    # 显示执行跟踪
    echo -e "${BLUE}执行跟踪:${NC}"
    grep "^+" "$DEBUG_LOG" | tail -20 || echo "  无执行跟踪信息"

    # 清理
    rm -f "$debug_script"

    echo -e "${GREEN}执行结果:${NC} $result"
}

# 性能分析
performance_analysis() {
    local script_path="$1"
    local input_data="$2"

    debug_log "INFO" "开始性能分析"
    echo -e "${CYAN}性能分析:${NC}"

    # 多次执行取平均值
    local iterations=10
    local total_time=0

    echo "执行 $iterations 次取平均值..."

    for ((i=1; i<=iterations; i++)); do
        local start_time=$(date +%s.%N)
        echo "$input_data" | bash "$script_path" >/dev/null 2>&1
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc)
        total_time=$(echo "$total_time + $duration" | bc)

        echo -ne "  第 $i 次: ${duration}s\r"
    done

    echo ""

    local avg_time=$(echo "scale=6; $total_time / $iterations" | bc)
    echo "平均执行时间: ${avg_time}s"

    # 性能建议
    if (( $(echo "$avg_time > 0.1" | bc -l) )); then
        echo -e "${YELLOW}性能建议:${NC} 执行时间较长，考虑优化脚本"
    else
        echo -e "${GREEN}性能良好:${NC} 执行时间正常"
    fi
}

# 配置信息分析
analyze_config() {
    local script_path="$1"

    debug_log "INFO" "分析配置文件依赖"
    echo -e "${CYAN}配置分析:${NC}"

    # 查找配置相关的代码
    echo "配置文件引用:"
    grep -n "\.json\|config" "$script_path" || echo "  无配置文件引用"

    echo ""
    echo "环境变量依赖:"
    grep -n '\$[A-Z_]' "$script_path" | grep -v '\$[0-9]' | head -10 || echo "  无环境变量依赖"

    echo ""
    echo "外部命令依赖:"
    grep -n '\$(' "$script_path" | head -10 || echo "  无外部命令调用"
}

# 验证输出结果
validate_output() {
    local output="$1"

    debug_log "INFO" "验证输出结果格式"
    echo -e "${CYAN}输出验证:${NC}"

    # 检查输出格式
    if echo "$output" | jq . >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} 输出是有效的 JSON 格式"

        # 检查必需字段
        if echo "$output" | jq -e '.decision' >/dev/null 2>&1; then
            local decision=$(echo "$output" | jq -r '.decision')
            echo -e "${GREEN}✓${NC} 包含决策字段: $decision"
        elif echo "$output" | jq -e '.continue' >/dev/null 2>&1; then
            local continue_val=$(echo "$output" | jq -r '.continue')
            echo -e "${GREEN}✓${NC} 包含继续字段: $continue_val"
        else
            echo -e "${RED}✗${NC} 缺少决策字段"
        fi

        # 检查其他字段
        if echo "$output" | jq -e '.reason' >/dev/null 2>&1; then
            local reason=$(echo "$output" | jq -r '.reason')
            echo -e "${BLUE}ℹ${NC} 决策原因: $reason"
        fi

    else
        echo -e "${RED}✗${NC} 输出不是有效的 JSON 格式"
        echo "原始输出: $output"
    fi
}

# 主调试函数
main_debug() {
    debug_log "INFO" "开始调试会话"
    debug_log "INFO" "脚本路径: $SCRIPT_PATH"
    debug_log "INFO" "调试级别: $DEBUG_LEVEL"

    # 显示基本信息
    echo -e "${BLUE}调试会话信息:${NC}"
    echo "脚本: $(basename "$SCRIPT_PATH")"
    echo "输入: $TEST_INPUT"
    echo "调试级别: $DEBUG_LEVEL"
    echo "日志文件: $DEBUG_LOG"
    echo ""

    # 分析脚本
    if [[ "$SHOW_CONFIG" == true ]]; then
        analyze_config "$SCRIPT_PATH"
        echo ""
    fi

    # 分析脚本结构
    analyze_script "$SCRIPT_PATH"

    # 验证输入
    if ! validate_input "$TEST_INPUT"; then
        exit 1
    fi
    echo ""

    # 显示变量信息
    if [[ "$SHOW_VARIABLES" == true ]]; then
        show_variables "$SCRIPT_PATH"
        echo ""
    fi

    # 执行脚本并记录结果
    debug_log "INFO" "执行审批脚本"
    echo -e "${YELLOW}执行结果:${NC}"

    local result
    local start_time=$(date +%s.%N)

    if [[ "$STEP_MODE" == true ]]; then
        step_execution "$SCRIPT_PATH" "$TEST_INPUT"
        result=$(echo "$TEST_INPUT" | bash "$SCRIPT_PATH" 2>&1)
    else
        result=$(echo "$TEST_INPUT" | bash "$SCRIPT_PATH" 2>&1)
        echo "$result"
    fi

    local end_time=$(date +%s.%N)
    local execution_time=$(echo "$end_time - $start_time" | bc)

    echo ""
    echo -e "${BLUE}执行统计:${NC}"
    echo "执行时间: ${execution_time}s"
    echo "退出码: $?"

    # 验证输出
    echo ""
    validate_output "$result"

    # 性能分析
    if [[ "$PERFORMANCE_MODE" == true ]]; then
        echo ""
        performance_analysis "$SCRIPT_PATH" "$TEST_INPUT"
    fi

    # 显示跟踪信息
    if [[ "$SHOW_TRACE" == true ]]; then
        echo ""
        echo -e "${BLUE}详细跟踪日志:${NC}"
        echo "查看完整日志: $DEBUG_LOG"
    fi

    debug_log "INFO" "调试会话结束"
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_args "$@"
    main_debug
fi

# 使用示例：
# ./debug-approval-script.sh ../basic/auto-approve-basic.sh '{"tool_name": "ls", "tool_input": {"path": "/tmp"}}'
# ./debug-approval-script.sh -d 3 -s -v ../smart/smart-context-approve.sh test-input.json
# DEBUG_LEVEL=3 ./debug-approval-script.sh -p -t ../tiered/tiered-approval.sh '{"tool_name": "Bash", "tool_input": {"command": "ls"}}'