#!/bin/bash
# Claude Code 审批脚本测试工具
# 功能：测试各种审批脚本的正确性和响应

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 测试配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_LOG="/tmp/claude-approval-test.log"
VERBOSE=${VERBOSE:-false}

# 清空日志
echo "=== Claude Approval Scripts Test Log ===" > "$TEST_LOG"
echo "Test started at: $(date)" >> "$TEST_LOG"
echo "" >> "$TEST_LOG"

# 测试用例定义
declare -a test_cases=(
    # 基础安全测试
    'basic|safe_read|{"tool_name": "ls", "tool_input": {"path": "/tmp"}, "context": {"project_root": "/home/user/project"}}|approve'
    'basic|safe_write|{"tool_name": "Write", "tool_input": {"file_path": "/tmp/test.txt", "content": "test"}, "context": {"project_root": "/home/user/project"}}|approve'
    'basic|dangerous_command|{"tool_name": "Bash", "tool_input": {"command": "rm -rf /"}, "context": {"project_root": "/home/user/project"}}|deny'
    'basic|safe_bash|{"tool_name": "Bash", "tool_input": {"command": "ls -la"}, "context": {"project_root": "/home/user/project"}}|approve'

    # 智能上下文测试
    'smart|project_file|{"tool_name": "Write", "tool_input": {"file_path": "/home/user/project/src/main.js", "content": "console.log(\"hello\")"}, "context": {"project_root": "/home/user/project"}}|approve'
    'smart|git_tracked|{"tool_name": "Edit", "tool_input": {"file_path": "/home/user/project/README.md", "content": "# Updated"}, "context": {"project_root": "/home/user/project"}}|continue'
    'smart|temp_file|{"tool_name": "Write", "tool_input": {"file_path": "/tmp/cache.tmp", "content": "cache"}, "context": {"project_root": "/home/user/project"}}|approve'
    'smart|dev_command|{"tool_name": "Bash", "tool_input": {"command": "npm install"}, "context": {"project_root": "/home/user/project"}}|approve'

    # 环境特定测试
    'dev|dev_tool|{"tool_name": "Bash", "tool_input": {"command": "git status"}, "context": {"project_root": "/home/user/project"}}|approve'
    'prod|prod_safety|{"tool_name": "Bash", "tool_input": {"command": "sudo systemctl restart nginx"}, "context": {"project_root": "/home/user/project"}}|deny'

    # 其他可用脚本测试
    'advanced|complex_decision|{"tool_name": "Write", "tool_input": {"file_path": "/etc/hosts", "content": "127.0.0.1 localhost"}, "context": {"project_root": "/home/user/project"}}|deny'
)

# 辅助函数
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Claude Code 审批脚本测试工具         ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

log_message() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$TEST_LOG"
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

print_result() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    local script_name="$4"
    local status="$5"

    if [[ "$status" == "PASS" ]]; then
        echo -e "${GREEN}✓ PASS${NC}: $test_name ($script_name)"
        echo "  Expected: $expected, Got: $actual"
        return 0
    elif [[ "$status" == "SKIP" ]]; then
        echo -e "${YELLOW}⚠ SKIP${NC}: $test_name ($script_name)"
        echo "  Reason: Script not found"
        return 2
    else
        echo -e "${RED}✗ FAIL${NC}: $test_name ($script_name)"
        echo "  Expected: $expected, Got: $actual"
        return 1
    fi
}

# 发现可用的审批脚本
discover_scripts() {
    log_message "Discovering available scripts..."
    
    declare -A script_map
    
    # 查找所有可能的脚本路径
    local search_paths=(
        "$PARENT_DIR/basic/auto-approve-basic.sh"
        "$PARENT_DIR/smart/smart-context-approve.sh"
        "$PARENT_DIR/environment-specific/dev-environment-approve.sh"
        "$PARENT_DIR/environment-specific/prod-environment-approve.sh"
        "$PARENT_DIR/environment-specific/cicd-environment-approve.sh"
        "$PARENT_DIR/advanced/combined-intelligent-approve.sh"
        "$PARENT_DIR/tiered/tiered-approval.sh"
    )
    
    # 建立类型到脚本的映射
    for script_path in "${search_paths[@]}"; do
        if [[ -f "$script_path" ]]; then
            local basename_script=$(basename "$script_path")
            case "$basename_script" in
                "auto-approve-basic.sh")
                    script_map["basic"]="$script_path"
                    ;;
                "smart-context-approve.sh")
                    script_map["smart"]="$script_path"
                    ;;
                "dev-environment-approve.sh")
                    script_map["dev"]="$script_path"
                    ;;
                "prod-environment-approve.sh")
                    script_map["prod"]="$script_path"
                    ;;
                "combined-intelligent-approve.sh")
                    script_map["advanced"]="$script_path"
                    ;;
                "tiered-approval.sh")
                    script_map["tiered"]="$script_path"
                    ;;
            esac
            log_message "Found script: $script_path"
        else
            log_message "Script not found: $script_path"
        fi
    done
    
    # 输出发现的脚本
    echo -e "${CYAN}发现的脚本:${NC}"
    for script_type in "${!script_map[@]}"; do
        echo "  $script_type: ${script_map[$script_type]}"
    done
    echo ""
    
    # 导出脚本映射供其他函数使用
    for script_type in "${!script_map[@]}"; do
        eval "SCRIPT_${script_type^^}='${script_map[$script_type]}'"
    done
}

get_script_path() {
    local script_type="$1"
    local var_name="SCRIPT_${script_type^^}"
    echo "${!var_name}"
}

parse_result() {
    local result="$1"
    local actual_result="unknown"
    
    log_message "Parsing result: $result"
    
    # 尝试解析JSON结果
    if command -v jq >/dev/null 2>&1; then
        # 使用jq解析
        local decision=$(echo "$result" | jq -r '.decision // empty' 2>/dev/null)
        local continue_flag=$(echo "$result" | jq -r '.continue // empty' 2>/dev/null)
        
        if [[ "$decision" == "approve" ]]; then
            actual_result="approve"
        elif [[ "$decision" == "deny" ]]; then
            actual_result="deny"
        elif [[ "$continue_flag" == "true" ]]; then
            actual_result="continue"
        fi
    else
        # 回退到字符串匹配
        if [[ "$result" == *'"decision": "approve"'* ]]; then
            actual_result="approve"
        elif [[ "$result" == *'"decision": "deny"'* ]]; then
            actual_result="deny"
        elif [[ "$result" == *'"continue": true'* ]]; then
            actual_result="continue"
        fi
    fi
    
    log_message "Parsed result: $actual_result"
    echo "$actual_result"
}

run_test() {
    local script_type="$1"
    local test_name="$2"
    local input_data="$3"
    local expected_result="$4"

    log_message "=== Testing: $test_name ==="
    log_message "Script type: $script_type"
    log_message "Input: $input_data"
    log_message "Expected: $expected_result"

    # 获取脚本路径
    local script_path=$(get_script_path "$script_type")
    
    if [[ -z "$script_path" ]]; then
        log_message "Script type '$script_type' not found"
        print_result "$test_name" "$expected_result" "script_not_found" "$script_type" "SKIP"
        return 2
    fi

    # 检查脚本是否存在且可执行
    if [[ ! -f "$script_path" ]]; then
        log_message "Script file not found: $script_path"
        print_result "$test_name" "$expected_result" "file_not_found" "$(basename "$script_path")" "SKIP"
        return 2
    fi

    if [[ ! -x "$script_path" ]]; then
        log_message "Script not executable: $script_path"
        chmod +x "$script_path" 2>/dev/null || {
            print_result "$test_name" "$expected_result" "not_executable" "$(basename "$script_path")" "SKIP"
            return 2
        }
    fi

    # 运行测试
    local result
    local exit_code
    
    result=$(echo "$input_data" | timeout 10s bash "$script_path" 2>&1)
    exit_code=$?
    
    log_message "Script exit code: $exit_code"
    log_message "Raw result: $result"

    if [[ $exit_code -ne 0 ]]; then
        log_message "Script execution failed with exit code: $exit_code"
        log_message "Error output: $result"
        print_result "$test_name" "$expected_result" "execution_error" "$(basename "$script_path")" "FAIL"
        return 1
    fi

    # 解析结果
    local actual_result=$(parse_result "$result")

    # 打印和比较结果
    if [[ "$expected_result" == "$actual_result" ]]; then
        print_result "$test_name" "$expected_result" "$actual_result" "$(basename "$script_path")" "PASS"
        return 0
    else
        print_result "$test_name" "$expected_result" "$actual_result" "$(basename "$script_path")" "FAIL"
        return 1
    fi
}

# 性能测试
performance_test() {
    local script_path="$1"
    local test_input="$2"
    local iterations="${3:-50}"

    if [[ ! -f "$script_path" ]]; then
        echo -e "${YELLOW}Performance test skipped: $(basename "$script_path") not found${NC}"
        return
    fi

    echo -e "${YELLOW}Performance test: $(basename "$script_path")${NC}"
    echo "Iterations: $iterations"

    local start_time=$(date +%s.%N)

    for ((i=1; i<=iterations; i++)); do
        echo "$test_input" | timeout 5s bash "$script_path" >/dev/null 2>&1 || true
    done

    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "N/A")
    
    if [[ "$duration" != "N/A" ]]; then
        local avg_time=$(echo "scale=6; $duration / $iterations" | bc 2>/dev/null || echo "N/A")
        echo "Total time: ${duration}s"
        echo "Average time per execution: ${avg_time}s"
    else
        echo "Performance measurement unavailable (bc not installed)"
    fi
    echo ""
}

# 检查依赖
check_dependencies() {
    echo -e "${BLUE}检查依赖...${NC}"

    local deps=("timeout")
    local optional_deps=("jq" "bc")
    local missing_deps=()
    local missing_optional=()

    # 检查必需依赖
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    # 检查可选依赖
    for dep in "${optional_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_optional+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}缺失必需依赖: ${missing_deps[*]}${NC}"
        echo "请安装缺失的依赖："
        echo "  Ubuntu/Debian: sudo apt-get install coreutils"
        return 1
    fi

    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        echo -e "${YELLOW}缺失可选依赖: ${missing_optional[*]}${NC}"
        echo "建议安装以获得更好的体验："
        echo "  Ubuntu/Debian: sudo apt-get install jq bc"
        echo "  CentOS/RHEL: sudo yum install jq bc"
        echo "  macOS: brew install jq bc"
    fi

    echo -e "${GREEN}依赖检查完成${NC}"
    return 0
}

# 生成测试报告
generate_report() {
    local total_tests="$1"
    local passed_tests="$2"
    local failed_tests="$3"
    local skipped_tests="$4"

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  测试报告                             ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "总测试数: $total_tests"
    echo -e "通过: ${GREEN}$passed_tests${NC}"
    echo -e "失败: ${RED}$failed_tests${NC}"
    echo -e "跳过: ${YELLOW}$skipped_tests${NC}"
    
    if [[ $total_tests -gt 0 ]]; then
        local success_rate=$(echo "scale=2; ($passed_tests * 100) / ($total_tests - $skipped_tests)" | bc 2>/dev/null || echo "N/A")
        echo -e "成功率: ${GREEN}${success_rate}%${NC}"
    fi
    
    echo ""
    echo "详细日志: $TEST_LOG"

    if [[ $failed_tests -gt 0 ]]; then
        echo ""
        echo -e "${RED}失败的测试需要检查脚本实现${NC}"
    fi

    if [[ $skipped_tests -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}跳过的测试表明对应的审批脚本不存在${NC}"
        echo "你可以运行 setup.sh 来生成缺失的脚本"
    fi
}

# 主测试函数
main() {
    local verbose_mode=false
    local performance_only=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -p|--performance)
                performance_only=true
                shift
                ;;
            -h|--help)
                echo "用法: $0 [选项]"
                echo "选项:"
                echo "  -v, --verbose    详细输出"
                echo "  -p, --performance 仅运行性能测试"
                echo "  -h, --help       显示帮助"
                exit 0
                ;;
            *)
                echo "未知选项: $1"
                exit 1
                ;;
        esac
    done

    print_header

    # 检查依赖
    if ! check_dependencies; then
        exit 1
    fi

    # 发现脚本
    discover_scripts

    if [[ "$performance_only" == "true" ]]; then
        echo -e "${YELLOW}仅运行性能测试...${NC}"
        echo ""
        
        # 性能测试
        local basic_script=$(get_script_path "basic")
        local smart_script=$(get_script_path "smart")
        
        [[ -n "$basic_script" ]] && performance_test "$basic_script" '{"tool_name": "ls", "tool_input": {"path": "/tmp"}, "context": {"project_root": "/home/user/project"}}' 50
        [[ -n "$smart_script" ]] && performance_test "$smart_script" '{"tool_name": "Write", "tool_input": {"file_path": "/tmp/test.txt", "content": "test"}, "context": {"project_root": "/home/user/project"}}' 50
        
        exit 0
    fi

    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    local skipped_tests=0

    echo -e "${YELLOW}开始功能测试...${NC}"
    echo ""

    # 运行所有测试用例
    for test_case in "${test_cases[@]}"; do
        IFS='|' read -r script_type test_name input_data expected_result <<< "$test_case"

        total_tests=$((total_tests + 1))

        local result=$(run_test "$script_type" "$test_name" "$input_data" "$expected_result")
        case $? in
            0) passed_tests=$((passed_tests + 1)) ;;
            1) failed_tests=$((failed_tests + 1)) ;;
            2) skipped_tests=$((skipped_tests + 1)) ;;
        esac
    done

    echo ""
    echo -e "${YELLOW}开始性能测试...${NC}"
    echo ""

    # 性能测试
    local basic_script=$(get_script_path "basic")
    local smart_script=$(get_script_path "smart")
    
    [[ -n "$basic_script" ]] && performance_test "$basic_script" '{"tool_name": "ls", "tool_input": {"path": "/tmp"}, "context": {"project_root": "/home/user/project"}}' 50
    [[ -n "$smart_script" ]] && performance_test "$smart_script" '{"tool_name": "Write", "tool_input": {"file_path": "/tmp/test.txt", "content": "test"}, "context": {"project_root": "/home/user/project"}}' 50

    # 生成报告
    generate_report "$total_tests" "$passed_tests" "$failed_tests" "$skipped_tests"

    # 返回结果
    if [[ $failed_tests -eq 0 ]]; then
        echo -e "${GREEN}测试完成！${NC}"
        exit 0
    else
        echo -e "${RED}存在测试失败${NC}"
        exit 1
    fi
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
