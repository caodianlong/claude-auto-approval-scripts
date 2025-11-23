#!/bin/bash
# Claude Code 自动审批系统 - 统一设置工具 v2.0
# 功能：智能环境检测 + 多种安装方式 + 项目初始化

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$SCRIPT_DIR"
GLOBAL_INSTALL_DIR="/opt/claude-auto-approval"
USER_INSTALL_DIR="$HOME/.local/share/claude-auto-approval"

# 状态变量
INSTALL_METHOD=""
ENVIRONMENT_TYPE=""
PROJECT_PATH=""
PROJECT_NAME=""
PROJECT_TYPE=""

# 帮助信息
show_help() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                Claude Code 自动审批系统                      ║${NC}"
    echo -e "${BLUE}║                  统一设置工具 v2.0                          ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}用法:${NC}"
    echo "  $0 [选项]"
    echo ""
    echo -e "${CYAN}选项:${NC}"
    echo "  -h, --help              显示此帮助信息"
    echo "  -q, --quick             快速模式（使用默认设置）"
    echo "  -e, --env TYPE          环境类型 (basic|dev|prod|cicd|smart|intelligent|auto)"
    echo "  -m, --method METHOD     安装方式 (global|user|project)"
    echo "  -p, --project PATH      项目路径（项目级安装时）"
    echo "  -s, --status            查看当前状态"
    echo ""
    echo -e "${CYAN}环境类型说明:${NC}"
    echo "  basic      - 基础审批（新手友好）"
    echo "  dev        - 开发环境（支持开发工具）"
    echo "  prod       - 生产环境（严格安全）"
    echo "  cicd       - CI/CD环境（自动化优先）"
    echo "  smart      - 智能审批（推荐）"
    echo "  intelligent- 组合智能（高级）"
    echo "  auto       - 自动检测项目类型"
    echo ""
    echo -e "${CYAN}安装方式说明:${NC}"
    echo "  global     - 系统级安装（需要管理员权限）"
    echo "  user       - 用户级安装（推荐）"
    echo "  project    - 项目级安装（最灵活）"
    echo ""
    echo -e "${CYAN}示例:${NC}"
    echo "  $0                                    # 交互式设置"
    echo "  $0 -q -e smart -m user               # 快速用户级智能审批"
    echo "  $0 -e dev -m project -p ~/my-project # 项目级开发环境"
    echo "  $0 -e auto -m global                 # 全局自动检测"
    echo ""
}

# 显示横幅
show_banner() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                    Claude Code 自动审批系统                  ║${NC}"
    echo -e "${BLUE}║                     统一设置工具 v2.0                       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 检测系统信息
detect_system() {
    OS=$(uname -s)
    ARCH=$(uname -m)
    USER=$(whoami)
    HOME_DIR="$HOME"

    case "$OS" in
        Linux*)
            OS_TYPE="linux"
            GLOBAL_DIR="/opt/claude-auto-approval"
            ;;
        Darwin*)
            OS_TYPE="macos"
            GLOBAL_DIR="/usr/local/opt/claude-auto-approval"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            OS_TYPE="windows"
            GLOBAL_DIR="C:/claude-auto-approval"
            ;;
        *)
            OS_TYPE="unknown"
            GLOBAL_DIR="/opt/claude-auto-approval"
            ;;
    esac
}

# 检查依赖
check_dependencies() {
    echo -e "${BLUE}检查系统依赖...${NC}"

    local missing_deps=()
    local deps=("jq" "bc")

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" > /dev/null 2>&1; then
            missing_deps+=("$dep")
        fi
    done

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}缺失依赖: ${missing_deps[*]}${NC}"
        echo "请安装缺失的依赖："
        case "$OS_TYPE" in
            "linux")
                echo "  Ubuntu/Debian: sudo apt-get install jq bc"
                echo "  CentOS/RHEL: sudo yum install jq bc"
                ;;
            "macos")
                echo "  macOS: brew install jq bc"
                ;;
            "windows")
                echo "  Windows: 下载 jq.exe 和 bc.exe 并添加到PATH"
                ;;
        esac
        return 1
    fi

    echo -e "${GREEN}✓ 所有依赖都已安装${NC}"
    return 0
}

# 检测项目类型
detect_project_type() {
    local dir="${1:-$(pwd)}"
    local project_type="unknown"

    if [[ -f "$dir/package.json" ]]; then
        project_type="nodejs"
    elif [[ -f "$dir/requirements.txt" ]] || [[ -f "$dir/setup.py" ]]; then
        project_type="python"
    elif [[ -f "$dir/pom.xml" ]] || [[ -f "$dir/build.gradle" ]]; then
        project_type="java"
    elif [[ -f "$dir/Cargo.toml" ]]; then
        project_type="rust"
    elif [[ -f "$dir/go.mod" ]]; then
        project_type="go"
    elif [[ -f "$dir/Gemfile" ]]; then
        project_type="ruby"
    elif [[ -f "$dir/composer.json" ]]; then
        project_type="php"
    elif [[ -f "$dir/Makefile" ]]; then
        project_type="make"
    elif [[ -d "$dir/src" ]] && [[ -f "$dir/README.md" ]]; then
        project_type="generic"
    fi

    echo "$project_type"
}

# 推荐环境类型
recommend_environment() {
    local project_type="$1"
    local usage_type="${2:-team-dev}"

    case "$usage_type" in
        "personal-dev")
            echo "dev"
            ;;
        "production")
            echo "prod"
            ;;
        "cicd")
            echo "cicd"
            ;;
        "team-dev")
            case "$project_type" in
                "nodejs"|"python"|"ruby"|"php")
                    echo "dev"
                    ;;
                "java"|"go"|"rust"|"make")
                    echo "smart"
                    ;;
                *)
                    echo "smart"
                    ;;
            esac
            ;;
        *)
            echo "smart"
            ;;
    esac
}

# 选择审批脚本
select_script() {
    local env_type="$1"

    case "$env_type" in
        "basic")
            echo "basic/auto-approve-basic.sh"
            ;;
        "dev"|"development")
            echo "environment-specific/dev-environment-approve.sh"
            ;;
        "prod"|"production")
            echo "environment-specific/prod-environment-approve.sh"
            ;;
        "cicd")
            echo "environment-specific/cicd-environment-approve.sh"
            ;;
        "smart")
            echo "smart/smart-context-approve.sh"
            ;;
        "intelligent"|"advanced")
            echo "advanced/combined-intelligent-approve.sh"
            ;;
        "auto")
            echo "auto-detect-approve.sh"
            ;;
        *)
            echo "smart/smart-context-approve.sh"
            ;;
    esac
}

# 交互式选择安装方式
choose_install_method() {
    echo -e "${CYAN}请选择安装方式:${NC}"
    echo "  ${WHITE}1)${NC} 全局安装 - 系统所有用户共享（需要管理员权限）"
    echo "  ${WHITE}2)${NC} 用户级安装 - 仅当前用户使用（推荐）"
    echo "  ${WHITE}3)${NC} 项目级安装 - 仅特定项目使用（最灵活）"
    echo ""

    read -p "请输入选择 (1-3): " choice

    case "$choice" in
        1)
            INSTALL_METHOD="global"
            if [[ "$USER" != "root" ]] && ! sudo -n true 2>/dev/null; then
                echo -e "${YELLOW}警告: 全局安装需要管理员权限${NC}"
                read -p "是否继续？(y/N): " confirm
                if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                    choose_install_method
                    return
                fi
            fi
            ;;
        2)
            INSTALL_METHOD="user"
            ;;
        3)
            INSTALL_METHOD="project"
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            choose_install_method
            return
            ;;
    esac
}

# 交互式选择环境类型
choose_environment() {
    local project_type="${1:-unknown}"

    echo -e "${CYAN}请选择审批环境类型:${NC}"
    echo "  ${WHITE}1)${NC} 自动检测 - 根据项目类型智能推荐"
    echo "  ${WHITE}2)${NC} 基础审批 - 简单安全控制（适合新手）"
    echo "  ${WHITE}3)${NC} 开发环境 - 支持开发工具，相对宽松"
    echo "  ${WHITE}4)${NC} 生产环境 - 严格安全控制（适合服务器）"
    echo "  ${WHITE}5)${NC} CI/CD环境 - 自动化优先，基础安全检查"
    echo "  ${WHITE}6)${NC} 智能审批 - 上下文感知（推荐）"
    echo "  ${WHITE}7)${NC} 组合智能 - 最高级别的智能决策"
    echo ""

    if [[ "$project_type" != "unknown" ]]; then
        local recommended=$(recommend_environment "$project_type" "team-dev")
        echo -e "${GREEN}检测到项目类型: $project_type，推荐: $recommended${NC}"
    fi

    read -p "请输入选择 (1-7): " choice

    case "$choice" in
        1)
            ENVIRONMENT_TYPE="auto"
            ;;
        2)
            ENVIRONMENT_TYPE="basic"
            ;;
        3)
            ENVIRONMENT_TYPE="dev"
            ;;
        4)
            ENVIRONMENT_TYPE="prod"
            ;;
        5)
            ENVIRONMENT_TYPE="cicd"
            ;;
        6)
            ENVIRONMENT_TYPE="smart"
            ;;
        7)
            ENVIRONMENT_TYPE="intelligent"
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            choose_environment "$project_type"
            return
            ;;
    esac
}

# 获取项目路径（项目级安装时）
get_project_path() {
    echo -e "${CYAN}请输入项目路径:${NC}"
    read -p "项目路径: " project_path

    # 处理相对路径
    if [[ ! "$project_path" =~ ^/ ]]; then
        project_path="$(pwd)/$project_path"
    fi

    # 检查路径是否存在
    if [[ ! -d "$project_path" ]]; then
        echo -e "${YELLOW}路径不存在，是否创建？(y/N):${NC}"
        read -r create_confirm
        if [[ "$create_confirm" =~ ^[Yy]$ ]]; then
            mkdir -p "$project_path"
            echo -e "${GREEN}✓ 已创建项目目录: $project_path${NC}"
        else
            get_project_path
            return
        fi
    fi

    PROJECT_PATH="$project_path"
    PROJECT_NAME="$(basename "$project_path")"
}

# 创建自动检测脚本
create_auto_detect_script() {
    local target_dir="$1"
    local detect_script="$target_dir/auto-detect-approve.sh"

    cat > "$detect_script" << 'EOF'
#!/bin/bash
# Claude Code 自动检测审批脚本
# 根据项目类型自动选择合适的审批策略

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')
project_root=$(echo "$input" | jq -r '.context.project_root // "."')

# 日志记录
echo "[$(date)] Auto-detect approval for $tool_name in $project_root" >> /tmp/claude-auto-detect.log

# 检测项目类型
if [[ -f "$project_root/package.json" ]]; then
    echo "[$(date)] Node.js project detected" >> /tmp/claude-auto-detect.log
    
    # 允许npm/yarn相关操作
    if [[ "$tool_name" == "Bash" ]]; then
        command=$(echo "$tool_input" | jq -r '.command')
        if [[ "$command" =~ ^(npm|yarn|pnpm) ]]; then
            echo '{"decision": "approve", "reason": "Node.js package manager command"}'
            exit 0
        fi
    fi
    
elif [[ -f "$project_root/requirements.txt" ]] || [[ -f "$project_root/setup.py" ]]; then
    echo "[$(date)] Python project detected" >> /tmp/claude-auto-detect.log
    
    # 允许pip/python相关操作
    if [[ "$tool_name" == "Bash" ]]; then
        command=$(echo "$tool_input" | jq -r '.command')
        if [[ "$command" =~ ^(pip|python|python3) ]]; then
            echo '{"decision": "approve", "reason": "Python package manager command"}'
            exit 0
        fi
    fi
    
elif [[ -f "$project_root/pom.xml" ]] || [[ -f "$project_root/build.gradle" ]]; then
    echo "[$(date)] Java project detected" >> /tmp/claude-auto-detect.log
    
    # 允许Maven/Gradle相关操作
    if [[ "$tool_name" == "Bash" ]]; then
        command=$(echo "$tool_input" | jq -r '.command')
        if [[ "$command" =~ ^(mvn|gradle|./gradlew) ]]; then
            echo '{"decision": "approve", "reason": "Java build tool command"}'
            exit 0
        fi
    fi
fi

# 基础安全控制
if [[ "$tool_name" == "Bash" ]]; then
    command=$(echo "$tool_input" | jq -r '.command')
    
    # 危险命令检测
    if [[ "$command" =~ (rm -rf /|format|fdisk|mkfs|dd if=/dev/zero) ]]; then
        echo '{"decision": "deny", "reason": "Dangerous system command"}'
        exit 0
    fi
    
    # 安全的只读操作
    if [[ "$command" =~ ^(ls|pwd|echo|cat|grep|find|which|head|tail|wc) ]]; then
        echo '{"decision": "approve", "reason": "Safe read-only command"}'
        exit 0
    fi
fi

# 文件操作安全检查
if [[ "$tool_name" == "Write" ]] || [[ "$tool_name" == "Edit" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path // .path')
    
    # 允许临时文件
    if [[ "$file_path" =~ ^/tmp/ ]] || [[ "$file_path" =~ \.tmp$ ]]; then
        echo '{"decision": "approve", "reason": "Temporary file operation"}'
        exit 0
    fi
    
    # 允许项目内文件
    if [[ "$file_path" =~ ^$project_root/ ]] || [[ "$file_path" =~ ^\. ]]; then
        echo '{"decision": "approve", "reason": "Project file operation"}'
        exit 0
    fi
fi

# 默认需要确认
echo '{"continue": true, "reason": "Default interactive confirmation"}'
EOF

    chmod +x "$detect_script"
    echo -e "${GREEN}✓ 自动检测脚本已创建: $detect_script${NC}"
}

# 创建全局安装
create_global_install() {
    echo -e "${BLUE}创建全局安装...${NC}"

    local target_dir="$GLOBAL_INSTALL_DIR"
    local script_path=$(select_script "$ENVIRONMENT_TYPE")

    # 创建目标目录
    if [[ "$USER" == "root" ]]; then
        mkdir -p "$target_dir"
    else
        sudo mkdir -p "$target_dir"
    fi

    # 复制文件
    echo "复制审批系统文件到 $target_dir..."
    if [[ "$USER" == "root" ]]; then
        cp -r "$CLAUDE_DIR"/* "$target_dir/"
    else
        sudo cp -r "$CLAUDE_DIR"/* "$target_dir/"
    fi

    # 创建自动检测脚本（如果需要）
    if [[ "$ENVIRONMENT_TYPE" == "auto" ]]; then
        if [[ "$USER" == "root" ]]; then
            create_auto_detect_script "$target_dir"
        else
            sudo bash -c "$(declare -f create_auto_detect_script); create_auto_detect_script '$target_dir'"
        fi
    fi

    # 设置权限
    if [[ "$USER" == "root" ]]; then
        chmod -R 755 "$target_dir"
    else
        sudo chmod -R 755 "$target_dir"
    fi

    echo -e "${GREEN}✓ 全局安装完成${NC}"
    echo "  📁 安装目录: $target_dir"
}

# 创建用户级安装
create_user_install() {
    echo -e "${BLUE}创建用户级安装...${NC}"

    local target_dir="$USER_INSTALL_DIR"
    local script_path=$(select_script "$ENVIRONMENT_TYPE")

    # 创建目标目录
    mkdir -p "$target_dir"

    # 复制文件
    echo "复制审批系统文件到 $target_dir..."
    cp -r "$CLAUDE_DIR"/* "$target_dir/"
    
    # 创建自动检测脚本（如果需要）
    if [[ "$ENVIRONMENT_TYPE" == "auto" ]]; then
        create_auto_detect_script "$target_dir"
    fi
    
    chmod -R 755 "$target_dir"

    echo -e "${GREEN}✓ 用户级安装完成${NC}"
    echo "  📁 安装目录: $target_dir"
}

# 创建项目级安装
create_project_install() {
    echo -e "${BLUE}创建项目级安装...${NC}"

    local project_dir="$PROJECT_PATH"
    local script_path=$(select_script "$ENVIRONMENT_TYPE")

    # 创建项目目录结构
    mkdir -p "$project_dir/.claude"

    # 复制审批脚本到项目
    if [[ "$ENVIRONMENT_TYPE" == "auto" ]]; then
        create_auto_detect_script "$project_dir/.claude"
        chmod +x "$project_dir/.claude/auto-detect-approve.sh"
    else
        if [[ -f "$CLAUDE_DIR/$script_path" ]]; then
            cp "$CLAUDE_DIR/$script_path" "$project_dir/.claude/"
            chmod +x "$project_dir/.claude/"*.sh
        else
            echo -e "${YELLOW}警告: 脚本文件不存在: $CLAUDE_DIR/$script_path${NC}"
            echo "创建默认脚本..."
            cat > "$project_dir/.claude/default-approve.sh" << 'EOF'
#!/bin/bash
# 默认审批脚本
input=$(cat)
echo '{"continue": true}'
EOF
            chmod +x "$project_dir/.claude/default-approve.sh"
        fi
    fi

    echo -e "${GREEN}✓ 项目级安装完成${NC}"
    echo "  📁 项目目录: $project_dir"
    echo "  ⚙️  配置位置: $project_dir/.claude/"
}

# 运行安装后测试
run_post_install_tests() {
    echo -e "${BLUE}运行安装后测试...${NC}"

    local test_input='{"tool_name": "ls", "tool_input": {"path": "/tmp"}, "context": {"project_root": "/tmp"}}'
    local result=""
    local script_path=""

    case "$INSTALL_METHOD" in
        "global")
            script_path="$GLOBAL_INSTALL_DIR/$(select_script "$ENVIRONMENT_TYPE")"
            ;;
        "user")
            script_path="$USER_INSTALL_DIR/$(select_script "$ENVIRONMENT_TYPE")"
            ;;
        "project")
            if [[ "$ENVIRONMENT_TYPE" == "auto" ]]; then
                script_path="$PROJECT_PATH/.claude/auto-detect-approve.sh"
            else
                script_path="$PROJECT_PATH/.claude/$(basename $(select_script "$ENVIRONMENT_TYPE"))"
            fi
            ;;
    esac

    if [[ -f "$script_path" ]]; then
        result=$(echo "$test_input" | bash "$script_path" 2>/dev/null)
        if [[ "$result" == *'"decision": "approve"'* ]] || [[ "$result" == *'"continue": true'* ]]; then
            echo -e "${GREEN}✓ 基础测试通过${NC}"
        else
            echo -e "${RED}✗ 基础测试失败: $result${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ 跳过测试（脚本文件不存在）${NC}"
    fi
}

# 显示安装摘要
show_install_summary() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    安装完成！ 🎉                            ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}安装摘要:${NC}"
    echo "  📦 安装方式: $INSTALL_METHOD"
    echo "  🔧 环境类型: $ENVIRONMENT_TYPE"
    echo "  📁 项目路径: ${PROJECT_PATH:-"N/A"}"
    echo "  ⏰ 安装时间: $(date)"
    echo "  👤 安装用户: $USER"
    echo ""

    echo -e "${CYAN}下一步建议:${NC}"
    case "$INSTALL_METHOD" in
        "global")
            echo "  • 全局配置已生效，所有新项目将自动使用此设置"
            ;;
        "user")
            echo "  • 用户级配置已生效"
            ;;
        "project")
            echo "  • 项目特定配置已创建"
            echo "  • 进入项目目录开始使用: cd $PROJECT_PATH"
            ;;
    esac

    echo ""
    echo "  • 查看审批日志: tail -f /tmp/claude-approval.log"
    if [[ -f "$SCRIPT_DIR/testing/test-approval-scripts.sh" ]]; then
        echo "  • 运行完整测试: $SCRIPT_DIR/testing/test-approval-scripts.sh"
    fi
    echo ""

    echo -e "${GREEN}🎊 开始使用你的智能审批系统吧！${NC}"
}

# 交互式主流程
main_interactive() {
    show_banner
    detect_system

    # 检查依赖
    if ! check_dependencies; then
        echo ""
        echo -e "${YELLOW}请先安装缺失的依赖，然后重新运行此脚本${NC}"
        exit 1
    fi

    echo ""
    echo -e "${CYAN}欢迎使用 Claude Code 自动审批系统设置工具！${NC}"
    echo ""

    # 选择安装方式
    choose_install_method
    echo ""

    # 根据安装方式处理
    case "$INSTALL_METHOD" in
        "project")
            get_project_path
            echo ""
            PROJECT_TYPE=$(detect_project_type "$PROJECT_PATH")
            if [[ "$PROJECT_TYPE" != "unknown" ]]; then
                echo -e "${GREEN}检测到项目类型: $PROJECT_TYPE${NC}"
            fi
            ;;
    esac

    # 选择环境类型
    choose_environment "$PROJECT_TYPE"
    echo ""

    # 确认安装
    echo -e "${CYAN}安装配置确认:${NC}"
    echo "  📦 安装方式: $INSTALL_METHOD"
    echo "  🔧 环境类型: $ENVIRONMENT_TYPE"
    if [[ -n "$PROJECT_PATH" ]]; then
        echo "  📁 项目路径: $PROJECT_PATH"
    fi
    echo ""

    read -p "是否确认安装？(y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}安装已取消${NC}"
        exit 0
    fi

    echo ""

    # 执行安装
    case "$INSTALL_METHOD" in
        "global")
            create_global_install
            ;;
        "user")
            create_user_install
            ;;
        "project")
            create_project_install
            ;;
    esac

    # 运行测试
    run_post_install_tests

    # 显示安装摘要
    show_install_summary
}

# 快速模式
quick_setup() {
    local env_type="${1:-smart}"
    local method="${2:-user}"
    local project_path="$3"

    echo -e "${BLUE}快速设置模式${NC}"
    echo "环境类型: $env_type"
    echo "安装方式: $method"
    if [[ -n "$project_path" ]]; then
        echo "项目路径: $project_path"
    fi
    echo ""

    detect_system
    ENVIRONMENT_TYPE="$env_type"
    INSTALL_METHOD="$method"

    if [[ "$INSTALL_METHOD" == "project" ]]; then
        if [[ -n "$project_path" ]]; then
            PROJECT_PATH="$project_path"
        else
            PROJECT_PATH="$(pwd)"
        fi
        PROJECT_NAME="$(basename "$PROJECT_PATH")"
    fi

    case "$INSTALL_METHOD" in
        "global")
            create_global_install
            ;;
        "user")
            create_user_install
            ;;
        "project")
            create_project_install
            ;;
    esac

    run_post_install_tests
    show_install_summary
}

# 主函数
main() {
    local quick_mode=false
    local env_type=""
    local method=""
    local project_path=""

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -e|--env)
                env_type="$2"
                shift 2
                ;;
            -m|--method)
                method="$2"
                shift 2
                ;;
            -p|--project)
                project_path="$2"
                shift 2
                ;;
            -q|--quick)
                quick_mode=true
                shift
                ;;
            -s|--status)
                echo "Claude Code 自动审批系统状态:"
                echo "脚本位置: $SCRIPT_DIR"
                echo "当前环境类型: ${ENVIRONMENT_TYPE:-"未设置"}"
                echo "当前安装方式: ${INSTALL_METHOD:-"未设置"}"
                exit 0
                ;;
            *)
                echo -e "${RED}未知参数: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done

    # 快速模式或交互式模式
    if [[ "$quick_mode" == true ]] || [[ -n "$env_type" ]]; then
        quick_setup "$env_type" "$method" "$project_path"
    else
        main_interactive
    fi
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
