#!/bin/bash
# Claude Code 自动审批脚本快速设置工具
# 功能：帮助用户快速配置和部署审批脚本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_CONFIG_DIR="${HOME}/.claude"
SETTINGS_FILE="${CLAUDE_CONFIG_DIR}/settings.json"
BACKUP_DIR="${CLAUDE_CONFIG_DIR}/backup_$(date +%Y%m%d_%H%M%S)"

# 帮助信息
show_help() {
    echo -e "${BLUE}Claude Code 自动审批脚本设置工具${NC}"
    echo ""
    echo -e "${CYAN}用法:${NC} ./setup.sh [选项]"
    echo ""
    echo -e "${CYAN}选项:${NC}"
    echo "  -h, --help          显示帮助信息"
    echo "  -i, --interactive   交互式设置"
    echo "  -s, --script <type>  选择脚本类型 (basic|smart|tiered|dev|prod|cicd|intelligent)"
    echo "  -c, --check         检查依赖和环境"
    echo "  -t, --test          运行测试验证"
    echo "  -b, --backup        备份现有配置"
    echo "  -r, --restore       恢复备份配置"
    echo ""
    echo -e "${CYAN}示例:${NC}"
    echo "  ./setup.sh -i                    # 交互式设置"
    echo "  ./setup.sh -s smart              # 使用智能审批脚本"
    echo "  ./setup.sh -s prod -t            # 生产环境脚本+测试"
    echo "  ./setup.sh -c                    # 检查环境"
    echo ""
}

# 检查依赖
check_dependencies() {
    echo -e "${BLUE}检查依赖...${NC}"

    local deps=("jq" "bc")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2&1; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}缺失依赖: ${missing_deps[*]}${NC}"
        echo "请安装缺失的依赖："
        echo "  Ubuntu/Debian: sudo apt-get install jq bc"
        echo "  CentOS/RHEL: sudo yum install jq bc"
        echo "  macOS: brew install jq bc"
        return 1
    fi

    echo -e "${GREEN}所有依赖都已安装${NC}"
    return 0
}

# 检查Claude Code环境
check_claude_environment() {
    echo -e "${BLUE}检查Claude Code环境...${NC}"

    if [[ -d "$CLAUDE_CONFIG_DIR" ]]; then
        echo -e "${GREEN}✓${NC} Claude Code配置目录存在: $CLAUDE_CONFIG_DIR"
    else
        echo -e "${YELLOW}!${NC} Claude Code配置目录不存在，将创建"
        mkdir -p "$CLAUDE_CONFIG_DIR"
    fi

    if [[ -f "$SETTINGS_FILE" ]]; then
        echo -e "${GREEN}✓${NC} 配置文件存在: $SETTINGS_FILE"
        return 0
    else
        echo -e "${YELLOW}!${NC} 配置文件不存在，将创建默认配置"
        return 1
    fi
}

# 备份现有配置
backup_config() {
    echo -e "${BLUE}备份现有配置...${NC}"

    if [[ -f "$SETTINGS_FILE" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp "$SETTINGS_FILE" "$BACKUP_DIR/"
        echo -e "${GREEN}✓${NC} 配置已备份到: $BACKUP_DIR"
    else
        echo -e "${YELLOW}!${NC} 无现有配置需要备份"
    fi
}

# 选择脚本
check_permissions() {
    local script_path="$1"

    if [[ ! -f "$script_path" ]]; then
        echo -e "${RED}脚本不存在: $script_path${NC}"
        return 1
    fi

    if [[ ! -x "$script_path" ]]; then
        echo -e "${YELLOW}脚本没有执行权限，正在设置...${NC}"
        chmod +x "$script_path"
        echo -e "${GREEN}✓${NC} 已设置执行权限"
    fi

    return 0
}

# 选择脚本
select_script() {
    local script_type="$1"

    case "$script_type" in
        "basic")
            echo "$SCRIPT_DIR/basic/auto-approve-basic.sh"
            ;;
        "smart")
            echo "$SCRIPT_DIR/smart/smart-context-approve.sh"
            ;;
        "tiered")
            echo "$SCRIPT_DIR/tiered/tiered-approval.sh"
            ;;
        "dev")
            echo "$SCRIPT_DIR/environment-specific/dev-environment-approve.sh"
            ;;
        "prod")
            echo "$SCRIPT_DIR/environment-specific/prod-environment-approve.sh"
            ;;
        "cicd")
            echo "$SCRIPT_DIR/environment-specific/cicd-environment-approve.sh"
            ;;
        "intelligent")
            echo "$SCRIPT_DIR/advanced/combined-intelligent-approve.sh"
            ;;
        *)
            echo ""
            ;;
    esac
}

# 创建配置文件
create_config() {
    local script_path="$1"
    local config_file="$2"

    echo -e "${BLUE}创建配置文件...${NC}"

    # 获取脚本的绝对路径
    local absolute_script_path=$(realpath "$script_path")

    # 检查配置文件是否存在
    if [[ -f "$config_file" ]]; then
        echo -e "${YELLOW}配置文件已存在，是否备份并覆盖？(y/N)${NC}"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            backup_config
        else
            echo -e "${YELLOW}取消配置更新${NC}"
            return 1
        fi
    fi

    # 创建新的配置文件
    cat > "$config_file" << EOF
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit|Bash|Delete|Move|Copy",
      "hooks": [
        {
          "type": "command",
          "command": "bash $absolute_script_path"
        }
      ]
    }
  ]
}
EOF

    echo -e "${GREEN}✓${NC} 配置文件已创建: $config_file"
    echo -e "${CYAN}使用的脚本:${NC} $(basename "$script_path")"
}

# 交互式设置
interactive_setup() {
    echo -e "${BLUE}=== 交互式设置向导 ===${NC}"
    echo ""

    # 检查依赖
    if ! check_dependencies; then
        exit 1
    fi

    # 检查环境
    check_claude_environment

    echo ""
    echo -e "${CYAN}请选择审批脚本类型:${NC}"
    echo "  1) 基础审批 (适合新手)"
    echo "  2) 智能审批 (推荐)"
    echo "  3) 分层审批 (高级)"
    echo "  4) 开发环境"
    echo "  5) 生产环境"
    echo "  6) CI/CD环境"
    echo "  7) 组合智能审批 (最全面)"
    echo ""

    read -p "请输入选择 (1-7): " choice

    case "$choice" in
        1) script_type="basic" ;;
        2) script_type="smart" ;;
        3) script_type="tiered" ;;
        4) script_type="dev" ;;
        5) script_type="prod" ;;
        6) script_type="cicd" ;;
        7) script_type="intelligent" ;;
        *)
            echo -e "${RED}无效选择${NC}"
            exit 1
            ;;
    esac

    # 选择脚本
    local script_path=$(select_script "$script_type")
    if [[ -z "$script_path" ]]; then
        echo -e "${RED}无效的脚本类型${NC}"
        exit 1
    fi

    # 检查脚本权限
    check_permissions "$script_path"

    echo ""
    echo -e "${CYAN}是否备份现有配置？${NC} (推荐) (y/N)"
    read -r backup_response
    if [[ "$backup_response" =~ ^[Yy]$ ]]; then
        backup_config
    fi

    # 创建配置文件
    create_config "$script_path" "$SETTINGS_FILE"

    echo ""
    echo -e "${GREEN}设置完成！${NC}"
    echo -e "${CYAN}下一步建议:${NC}"
    echo "  1. 运行测试验证配置: ./setup.sh -t"
    echo "  2. 查看详细文档: cat $SCRIPT_DIR/README.md"
    echo "  3. 自定义配置文件: $SETTINGS_FILE"
}

# 运行测试
run_tests() {
    echo -e "${BLUE}运行测试验证...${NC}"

    local test_script="$SCRIPT_DIR/testing/test-approval-scripts.sh"
    if [[ -f "$test_script" ]]; then
        check_permissions "$test_script"
        echo ""
        bash "$test_script"
    else
        echo -e "${RED}测试脚本不存在: $test_script${NC}"
        exit 1
    fi
}

# 恢复备份
restore_backup() {
    echo -e "${BLUE}恢复备份配置...${NC}"

    # 查找最新的备份目录
    local latest_backup=$(ls -dt "$CLAUDE_CONFIG_DIR"/backup_* 2>/dev/null | head -1)

    if [[ -z "$latest_backup" ]]; then
        echo -e "${RED}未找到备份配置${NC}"
        exit 1
    fi

    echo -e "${CYAN}找到备份:${NC} $latest_backup"
    echo -e "${YELLOW}是否恢复此备份？(y/N)${NC}"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        if [[ -f "$latest_backup/settings.json" ]]; then
            cp "$latest_backup/settings.json" "$SETTINGS_FILE"
            echo -e "${GREEN}✓${NC} 配置已恢复"
        else
            echo -e "${RED}备份文件不存在${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}取消恢复操作${NC}"
    fi
}

# 显示状态
show_status() {
    echo -e "${BLUE}当前状态:${NC}"
    echo ""

    # 检查依赖
    if check_dependencies >/dev/null 2&1; then
        echo -e "${GREEN}✓${NC} 依赖检查通过"
    else
        echo -e "${RED}✗${NC} 依赖检查失败"
    fi

    # 检查配置
    if [[ -f "$SETTINGS_FILE" ]]; then
        echo -e "${GREEN}✓${NC} 配置文件存在: $SETTINGS_FILE"

        # 显示当前使用的脚本
        local current_script=$(grep -o '"command": *"[^"]*"' "$SETTINGS_FILE" 2>/dev/null | cut -d'"' -f4)
        if [[ -n "$current_script" ]]; then
            echo -e "${BLUE}ℹ${NC} 当前脚本: $current_script"
        fi
    else
        echo -e "${YELLOW}!${NC} 配置文件不存在"
    fi

    # 检查备份
    local backup_count=$(ls -d "$CLAUDE_CONFIG_DIR"/backup_* 2>/dev/null | wc -l)
    if [[ $backup_count -gt 0 ]]; then
        echo -e "${GREEN}✓${NC} 备份文件: $backup_count 个"
    else
        echo -e "${YELLOW}!${NC} 无备份文件"
    fi

    echo ""
    echo -e "${CYAN}可用脚本:${NC}"
    echo "  基础审批: $SCRIPT_DIR/basic/auto-approve-basic.sh"
    echo "  智能审批: $SCRIPT_DIR/smart/smart-context-approve.sh"
    echo "  分层审批: $SCRIPT_DIR/tiered/tiered-approval.sh"
    echo "  开发环境: $SCRIPT_DIR/environment-specific/dev-environment-approve.sh"
    echo "  生产环境: $SCRIPT_DIR/environment-specific/prod-environment-approve.sh"
    echo "  CI/CD环境: $SCRIPT_DIR/environment-specific/cicd-environment-approve.sh"
    echo "  组合智能: $SCRIPT_DIR/advanced/combined-intelligent-approve.sh"
}

# 主函数
main() {
    local interactive=false
    local script_type=""
    local check_only=false
    local test_only=false
    local backup_only=false
    local restore_only=false
    local status_only=false

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -i|--interactive)
                interactive=true
                shift
                ;;
            -s|--script)
                script_type="$2"
                shift 2
                ;;
            -c|--check)
                check_only=true
                shift
                ;;
            -t|--test)
                test_only=true
                shift
                ;;
            -b|--backup)
                backup_only=true
                shift
                ;;
            -r|--restore)
                restore_only=true
                shift
                ;;
            -S|--status)
                status_only=true
                shift
                ;;
            *)
                echo -e "${RED}未知选项: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done

    # 执行相应的功能
    if [[ "$status_only" == true ]]; then
        show_status
    elif [[ "$check_only" == true ]]; then
        check_dependencies
        check_claude_environment
    elif [[ "$test_only" == true ]]; then
        if check_dependencies >/dev/null 2&1; then
            run_tests
        else
            exit 1
        fi
    elif [[ "$backup_only" == true ]]; then
        backup_config
    elif [[ "$restore_only" == true ]]; then
        restore_backup
    elif [[ -n "$script_type" ]]; then
        # 直接设置指定脚本
        if ! check_dependencies >/dev/null 2&1; then
            exit 1
        fi

        local script_path=$(select_script "$script_type")
        if [[ -n "$script_path" ]]; then
            check_permissions "$script_path"
            backup_config
            create_config "$script_path" "$SETTINGS_FILE"
            echo -e "${GREEN}✓${NC} 脚本设置完成"
        else
            echo -e "${RED}无效的脚本类型: $script_type${NC}"
            exit 1
        fi
    else
        # 默认交互式设置
        interactive_setup
    fi
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# 使用示例：
# ./setup.sh -i                    # 交互式设置
# ./setup.sh -s smart              # 使用智能审批脚本
# ./setup.sh -c                    # 检查环境
# ./setup.sh -t                    # 运行测试
# ./setup.sh -b                    # 备份配置
# ./setup.sh -r                    # 恢复配置
# ./setup.sh -S                    # 显示状态

# 快速开始：
# 1. ./setup.sh -c                 # 检查环境
# 2. ./setup.sh -i                 # 交互式设置
# 3. ./setup.sh -t                 # 验证配置
# 4. ./setup.sh -S                 # 查看状态

# 高级用法：
# DEBUG_LEVEL=3 ./setup.sh -s intelligent -t  # 详细调试模式设置智能脚本并测试

## 🎯 设置完成后的建议：
#
# 1. 测试审批功能：
#    echo '{"tool_name": "ls", "tool_input": {"path": "/tmp"}, "context": {"project_root": "/home/user/project"}}' | bash $(grep -o '"command": *"[^"]*"' ~/.claude/settings.json | cut -d'"' -f4)
#
# 2. 查看详细文档：
#    cat README.md
#
# 3. 自定义配置：
#    编辑 ~/.claude/settings.json
#
# 4. 运行完整测试：
#    ./testing/test-approval-scripts.sh
#
# 5. 调试问题：
#    ./testing/debug-approval-script.sh -d 3 -v $(grep -o '"command": *"[^"]*"' ~/.claude/settings.json | cut -d'"' -f4) test-input.json

## 📋 配置文件模板：
#
# 基础配置：
# {
#   "PreToolUse": [
#     {
#       "matcher": "Write|Edit|Bash",
#       "hooks": [
#         {
#           "type": "command",
#           "command": "bash /path/to/script.sh"
#         }
#       ]
#     }
#   ]
# }
#
# 高级配置：
# {
#   "PreToolUse": [
#     {
#       "matcher": "Write|Edit",
#       "hooks": [
#         {
#           "type": "command",
#           "command": "bash /path/to/smart-script.sh"
#         }
#       ]
#     },
#     {
#       "matcher": "Bash",
#       "hooks": [
#         {
#           "type": "command",
#           "command": "bash /path/to/tiered-script.sh"
#         }
#       ]
#     }
#   ]
# }