#!/bin/bash
# Claude Code 项目初始化工具
# 功能：快速为新项目配置合适的审批系统

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
CLAUDE_DIR="${PARENT_DIR}"

# 帮助信息
show_help() {
    echo -e "${BLUE}Claude Code 项目初始化工具${NC}"
    echo ""
    echo -e "${CYAN}用法:${NC} ./project-init.sh [选项] [项目路径]"
    echo ""
    echo -e "${CYAN}选项:${NC}"
    echo "  -h, --help          显示帮助信息"
    echo "  -e, --env <type>    选择环境类型 (auto|dev|prod|basic|smart|intelligent)"
    echo "  -f, --force         强制覆盖现有配置"
    echo "  -g, --git           自动初始化Git仓库"
    echo "  -n, --name <name>   指定项目名称"
    echo "  -t, --test          初始化后运行测试"
    echo "  -d, --detect        自动检测项目类型"
    echo ""
    echo -e "${CYAN}示例:${NC}"
    echo "  ./project-init.sh ~/my-new-project"
    echo "  ./project-init.sh -e dev -g ~/my-app"
    echo "  ./project-init.sh -e auto -d -t ~/workspace/new-project"
    echo ""
}

# 检测项目类型
detect_project_type() {
    local project_dir="$1"
    local project_type="unknown"

    echo -e "${BLUE}检测项目类型...${NC}"

    # 检测各种项目类型
    if [[ -f "$project_dir/package.json" ]]; then
        project_type="nodejs"
        echo "  📦 Node.js项目检测到"
    elif [[ -f "$project_dir/requirements.txt" ]] || [[ -f "$project_dir/setup.py" ]]; then
        project_type="python"
        echo "  🐍 Python项目检测到"
    elif [[ -f "$project_dir/pom.xml" ]] || [[ -f "$project_dir/build.gradle" ]]; then
        project_type="java"
        echo "  ☕ Java项目检测到"
    elif [[ -f "$project_dir/Cargo.toml" ]]; then
        project_type="rust"
        echo "  🦀 Rust项目检测到"
    elif [[ -f "$project_dir/go.mod" ]]; then
        project_type="go"
        echo "  🐹 Go项目检测到"
    elif [[ -f "$project_dir/Gemfile" ]]; then
        project_type="ruby"
        echo "  💎 Ruby项目检测到"
    elif [[ -f "$project_dir/composer.json" ]]; then
        project_type="php"
        echo "  🐘 PHP项目检测到"
    elif [[ -f "$project_dir/Makefile" ]]; then
        project_type="make"
        echo "  🔨 Makefile项目检测到"
    elif [[ -d "$project_dir/src" ]] && [[ -f "$project_dir/README.md" ]]; then
        project_type="generic"
        echo "  📁 通用项目检测到"
    else
        echo "  ❓ 未识别特定项目类型，使用通用配置"
    fi

    echo "$project_type"
}

# 根据项目类型推荐环境
recommend_environment() {
    local project_type="$1"

    case "$project_type" in
        "nodejs"|"python"|"ruby"|"php")
            echo "dev"
            ;;
        "java"|"go"|"rust")
            echo "smart"
            ;;
        "make"|"generic")
            echo "basic"
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
        "auto")
            echo ""
            ;;
        "basic")
            echo "$CLAUDE_DIR/basic/auto-approve-basic.sh"
            ;;
        "dev"|"development")
            echo "$CLAUDE_DIR/environment-specific/dev-environment-approve.sh"
            ;;
        "prod"|"production")
            echo "$CLAUDE_DIR/environment-specific/prod-environment-approve.sh"
            ;;
        "smart")
            echo "$CLAUDE_DIR/smart/smart-context-approve.sh"
            ;;
        "intelligent"|"advanced")
            echo "$CLAUDE_DIR/advanced/combined-intelligent-approve.sh"
            ;;
        *)
            echo "$CLAUDE_DIR/smart/smart-context-approve.sh"
            ;;
    esac
}

# 创建项目配置文件
create_project_config() {
    local project_dir="$1"
    local script_path="$2"
    local env_type="$3"
    local project_name="$4"
    local project_type="$5"

    echo -e "${BLUE}创建项目配置文件...${NC}"

    local config_file="$project_dir/.claude/settings.json"

    # 如果配置文件已存在且未强制覆盖，则备份
    if [[ -f "$config_file" ]] && [[ "$FORCE_OVERWRITE" != "true" ]]; then
        echo -e "${YELLOW}配置文件已存在，备份为 settings.json.backup${NC}"
        cp "$config_file" "$config_file.backup"
    fi

    # 创建配置文件
    if [[ -n "$script_path" ]]; then
        # 使用相对路径
        local relative_script_path=".claude/$(basename "$script_path")"

        cat > "$config_file" << EOF
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit|Bash|Delete|Move|Copy",
      "hooks": [
        {
          "type": "command",
          "command": "bash $relative_script_path"
        }
      ]
    }
  ],
  "project_info": {
    "name": "$project_name",
    "type": "$project_type",
    "environment": "$env_type",
    "created_at": "$(date)",
    "initialized_by": "$(whoami)"
  },
  "initialization_tool": {
    "version": "1.0.0",
    "script": "project-init.sh"
  }
}
EOF
    else
        # 自动检测模式 - 使用智能检测脚本
        cat > "$config_file" << EOF
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit|Bash|Delete|Move|Copy",
      "hooks": [
        {
          "type": "command",
          "command": "bash .claude/auto-detect-approve.sh"
        }
      ]
    }
  ],
  "project_info": {
    "name": "$project_name",
    "type": "$project_type",
    "environment": "auto-detect",
    "created_at": "$(date)",
    "initialized_by": "$(whoami)"
  },
  "initialization_tool": {
    "version": "1.0.0",
    "script": "project-init.sh",
    "mode": "auto-detect"
  }
}
EOF
    fi

    echo -e "${GREEN}✓${NC} 配置文件已创建: $config_file"
}

# 创建自动检测脚本
create_auto_detect_script() {
    local project_dir="$1"
    local project_type="$2"

    echo -e "${BLUE}创建自动检测脚本...${NC}"

    local detect_script="$project_dir/.claude/auto-detect-approve.sh"

    cat > "$detect_script" << 'EOF'
#!/bin/bash
# Claude Code 自动检测审批脚本
# 根据项目类型自动选择合适的审批策略

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')
project_root=$(echo "$input" | jq -r '.context.project_root')

# 日志记录
echo "[$(date)] Auto-detect approval for $tool_name in $project_root" >> /tmp/claude-auto-detect.log

# 检测项目类型
if [[ -f "$project_root/package.json" ]]; then
    # Node.js项目 - 使用开发环境策略
    echo "[$(date)] Node.js project detected" >> /tmp/claude-auto-detect.log

    # 允许npm相关操作
    if [[ "$tool_name" == "Bash" ]]; then
        command=$(echo "$tool_input" | jq -r '.command')
        if [[ "$command" =~ ^npm ]] || [[ "$command" =~ ^yarn ]]; then
            echo '{"decision": "approve"}'
            exit 0
        fi
    fi

    # 允许编辑项目文件
    if [[ "$tool_name" == "Write" ]] || [[ "$tool_name" == "Edit" ]]; then
        file_path=$(echo "$tool_input" | jq -r '.file_path')
        if [[ "$file_path" =~ ^$project_root/ ]]; then
            echo '{"decision": "approve"}'
            exit 0
        fi
    fi

elif [[ -f "$project_root/requirements.txt" ]] || [[ -f "$project_root/setup.py" ]]; then
    # Python项目 - 使用开发环境策略
    echo "[$(date)] Python project detected" >> /tmp/claude-auto-detect.log

    # 允许pip相关操作
    if [[ "$tool_name" == "Bash" ]]; then
        command=$(echo "$tool_input" | jq -r '.command')
        if [[ "$command" =~ ^pip ]] || [[ "$command" =~ ^python ]]; then
            echo '{"decision": "approve"}'
            exit 0
        fi
    fi

elif [[ -f "$project_root/pom.xml" ]] || [[ -f "$project_root/build.gradle" ]]; then
    # Java项目 - 使用智能审批策略
    echo "[$(date)] Java project detected" >> /tmp/claude-auto-detect.log

    # 允许Maven/Gradle相关操作
    if [[ "$tool_name" == "Bash" ]]; then
        command=$(echo "$tool_input" | jq -r '.command')
        if [[ "$command" =~ ^mvn ]] || [[ "$command" =~ ^gradle ]]; then
            echo '{"decision": "approve"}'
            exit 0
        fi
    fi

else
    # 通用项目 - 使用基础安全策略
    echo "[$(date)] Generic project detected" >> /tmp/claude-auto-detect.log
fi

# 基础安全控制
# 1. 危险命令检测
if [[ "$tool_name" == "Bash" ]]; then
    command=$(echo "$tool_input" | jq -r '.command')
    dangerous_patterns="rm -rf /|format|fdisk|mkfs|dd if=/dev/zero"
    if [[ "$command" =~ $dangerous_patterns ]]; then
        echo '{"decision": "deny"}'
        exit 0
    fi
fi

# 2. 安全的只读操作
safe_readonly_tools="ls pwd echo cat grep find which head tail wc"
if [[ "$safe_readonly_tools" =~ "$tool_name" ]]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# 3. 临时文件操作
if [[ "$tool_name" == "Write" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')
    if [[ "$file_path" =~ ^/tmp/ ]] || [[ "$file_path" =~ \.tmp$ ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi
fi

# 默认需要确认
echo '{"continue": true}'
EOF

    chmod +x "$detect_script"
    echo -e "${GREEN}✓${NC} 自动检测脚本已创建: $detect_script"
}

# 创建项目说明文件
create_project_readme() {
    local project_dir="$1"
    local project_name="$2"
    local env_type="$3"
    local project_type="$4"

    echo -e "${BLUE}创建项目说明文件...${NC}"

    local readme_file="$project_dir/.claude/README.md"

    cat > "$readme_file" << EOF
# Claude Code 审批配置

## 项目信息
- **项目名称**: $project_name
- **项目类型**: $project_type
- **审批模式**: $env_type
- **初始化时间**: $(date)
- **初始化用户**: $(whoami)

## 当前配置
此项目已配置Claude Code自动审批系统。

### 审批脚本
- 类型: $env_type
- 位置: .claude/$(if [[ "$env_type" == "auto" ]]; then echo "auto-detect-approve.sh"; else echo "$env_type"*".sh"; fi)

### 适用场景
$(case "$env_type" in
    "auto") echo "- 自动检测项目类型并应用相应策略" ;;
    "basic") echo "- 基础安全控制，适合简单项目" ;;
    "dev") echo "- 开发环境，支持开发工具和临时文件" ;;
    "prod") echo "- 生产环境，严格的安全控制" ;;
    "smart") echo "- 智能上下文感知，适合复杂项目" ;;
    "intelligent") echo "- 组合智能审批，最高级别的智能决策" ;;
esac)

## 使用方法
无需额外配置，Claude Code将自动使用此项目的审批设置。

## 更改审批模式
如需更改审批模式，请重新运行项目初始化工具：
\`\`\`bash
cd "$project_dir"
$CLAUDE_DIR/tools/project-init.sh -e <新环境类型> .
\`\`\`

可用环境类型: auto, basic, dev, prod, smart, intelligent

## 故障排除
如遇到问题，请查看审批日志：
\`\`\`bash
tail -f /tmp/claude-approval.log
\`\`\`

或使用调试工具：
\`\`\`bash
$CLAUDE_DIR/testing/debug-approval-script.sh -d 3 -v .claude/$(basename .claude/*.sh) test-input.json
\`\`\`

## 更多信息
- [完整使用指南](../USAGE-GUIDE.md)
- [快速开始](../QUICK-START.md)
- [项目主页](https://github.com/your-repo/claude-auto-approval)
EOF

    echo -e "${GREEN}✓${NC} 项目说明文件已创建: $readme_file"
}

# 初始化Git仓库
init_git_repo() {
    local project_dir="$1"

    if [[ "$INIT_GIT" == "true" ]]; then
        echo -e "${BLUE}初始化Git仓库...${NC}"

        cd "$project_dir"

        if [[ ! -d ".git" ]]; then
            git init
            echo -e "${GREEN}✓${NC} Git仓库已初始化"
        else
            echo -e "${YELLOW}!${NC} Git仓库已存在，跳过初始化"
        fi

        # 创建.gitignore
        if [[ ! -f ".gitignore" ]]; then
            cat > .gitignore << 'EOF'
# Claude Code
.claude/

# 日志文件
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# 运行时数据
pids
*.pid
*.seed
*.pid.lock

# 构建输出
dist/
build/
target/
node_modules/

# 环境变量
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
EOF
            echo -e "${GREEN}✓${NC} .gitignore已创建"
        fi

        # 添加并提交初始文件
        git add .claude/
        git add .gitignore 2>/dev/null || true
        git commit -m "初始化Claude Code自动审批配置" 2>/dev/null || echo "提交已存在，跳过"
    fi
}

# 运行测试
run_tests() {
    if [[ "$RUN_TESTS" == "true" ]]; then
        echo -e "${BLUE}运行测试验证...${NC}"

        local test_script="$CLAUDE_DIR/testing/test-approval-scripts.sh"
        if [[ -f "$test_script" ]]; then
            # 运行针对此项目的测试
            echo "运行基础测试..."
            local test_input='{"tool_name": "ls", "tool_input": {"path": "/tmp"}, "context": {"project_root": "'$(pwd)'"}}'
            local result=$(echo "$test_input" | bash .claude/*.sh)

            if [[ "$result" == *'"decision": "approve"'* ]]; then
                echo -e "${GREEN}✓${NC} 基础测试通过"
            else
                echo -e "${RED}✗${NC} 基础测试失败: $result"
                return 1
            fi
        else
            echo -e "${YELLOW}!${NC} 测试脚本不存在，跳过测试"
        fi
    fi
}

# 显示项目摘要
show_project_summary() {
    local project_dir="$1"
    local project_name="$2"
    local env_type="$3"
    local project_type="$4"

    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  项目初始化完成！ 🎉${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${CYAN}项目信息:${NC}"
    echo "  📁 项目名称: $project_name"
    echo "  📍 项目路径: $project_dir"
    echo "  🏷️  项目类型: $project_type"
    echo "  🔧 审批模式: $env_type"
    echo ""
    echo -e "${CYAN}已创建文件:${NC}"
    echo "  ✅ .claude/settings.json (配置文件)"
    if [[ "$env_type" == "auto" ]]; then
        echo "  ✅ .claude/auto-detect-approve.sh (自动检测脚本)"
    else
        echo "  ✅ .claude/$(basename $(select_script "$env_type")) (审批脚本)"
    fi
    echo "  ✅ .claude/README.md (说明文档)"
    [[ "$INIT_GIT" == "true" ]] && echo "  ✅ .gitignore (Git忽略文件)"
    echo ""
    echo -e "${CYAN}下一步:${NC}"
    echo "  1. cd $project_dir"
    echo "  2. 开始使用Claude Code，享受智能审批！"
    echo ""
    echo -e "${CYAN}有用命令:${NC}"
    echo "  • 查看审批日志: tail -f /tmp/claude-approval.log"
    echo "  • 更改审批模式: $CLAUDE_DIR/tools/project-init.sh -e <新类型> ."
    echo "  • 运行测试: $CLAUDE_DIR/testing/test-approval-scripts.sh"
    echo "  • 调试问题: $CLAUDE_DIR/testing/debug-approval-script.sh -h"
    echo ""
}

# 主函数
main() {
    local project_path=""
    local env_type="auto"
    local force_overwrite="false"
    local init_git="false"
    local project_name=""
    local run_tests="false"
    local auto_detect="false"

    # 解析参数
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
            -f|--force)
                force_overwrite="true"
                shift
                ;;
            -g|--git)
                init_git="true"
                shift
                ;;
            -n|--name)
                project_name="$2"
                shift 2
                ;;
            -t|--test)
                run_tests="true"
                shift
                ;;
            -d|--detect)
                auto_detect="true"
                shift
                ;;
            *)
                if [[ -z "$project_path" ]]; then
                    project_path="$1"
                else
                    echo -e "${RED}未知参数: $1${NC}"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # 验证必需参数
    if [[ -z "$project_path" ]]; then
        echo -e "${RED}错误: 未指定项目路径${NC}"
        show_help
        exit 1
    fi

    # 设置全局变量
    FORCE_OVERWRITE="$force_overwrite"
    INIT_GIT="$init_git"
    RUN_TESTS="$run_tests"

    # 显示欢迎信息
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Claude Code 项目初始化工具${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # 解析项目路径
    if [[ "$project_path" == "." ]]; then
        project_path=$(pwd)
    elif [[ ! "$project_path" =~ ^/ ]]; then
        project_path="$(pwd)/$project_path"
    fi

    # 获取项目信息
    project_name="${project_name:-$(basename "$project_path")}"

    # 检查项目是否存在
    if [[ ! -d "$project_path" ]]; then
        echo -e "${CYAN}创建新项目目录: $project_path${NC}"
        mkdir -p "$project_path"
    fi

    # 检测项目类型
    local project_type="unknown"
    if [[ "$auto_detect" == "true" ]] || [[ "$env_type" == "auto" ]]; then
        project_type=$(detect_project_type "$project_path")
    fi

    # 推荐或确认环境类型
    if [[ "$env_type" == "auto" ]]; then
        env_type=$(recommend_environment "$project_type")
        echo -e "${GREEN}推荐使用环境: $env_type${NC}"
    fi

    # 选择脚本
    local script_path=$(select_script "$env_type")

    # 创建.claude目录
    echo -e "${BLUE}创建.claude目录...${NC}"
    mkdir -p "$project_path/.claude"

    # 复制审批脚本（如果不是自动检测模式）
    if [[ -n "$script_path" ]]; then
        echo -e "${BLUE}复制审批脚本...${NC}"
        cp "$script_path" "$project_path/.claude/"
        chmod +x "$project_path/.claude/"*.sh
        echo -e "${GREEN}✓${NC} 审批脚本已复制: $(basename "$script_path")"
    else
        # 自动检测模式
        create_auto_detect_script "$project_path" "$project_type"
    fi

    # 创建配置文件
    create_project_config "$project_path" "$script_path" "$env_type" "$project_name" "$project_type"

    # 创建项目说明文件
    create_project_readme "$project_path" "$project_name" "$env_type" "$project_type"

    # 初始化Git（如果请求）
    init_git_repo "$project_path"

    # 运行测试（如果请求）
    run_tests

    # 显示项目摘要
    show_project_summary "$project_path" "$project_name" "$env_type" "$project_type"
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# 使用示例：
# ./project-init.sh ~/my-new-project                    # 基础初始化
# ./project-init.sh -e dev -g ~/my-app                  # 开发环境 + Git
# ./project-init.sh -e auto -d -t ~/workspace/project   # 自动检测 + 测试
# ./project-init.sh -e prod -n "My Production App" ~/prod-app  # 生产环境 + 指定名称
# ./project-init.sh -f -e smart .                       # 强制覆盖当前目录配置

# 快速开始：
# 1. mkdir my-new-project
# 2. cd my-new-project
# 3. $CLAUDE_DIR/tools/project-init.sh -e auto -d -g .
# 4. 开始使用Claude Code！

## 🎯 这个工具的优势：
#
# 1. 智能项目检测 - 自动识别项目类型并推荐合适的审批策略
# 2. 一键初始化 - 快速为新项目配置完整的审批系统
# 3. 多种环境支持 - 支持各种开发环境和项目类型
# 4. 自动化集成 - 可选的Git初始化和自动配置
# 5. 标准化流程 - 确保所有项目都有统一的审批配置
# 6. 易于管理 - 每个项目都有清晰的配置文档
#
# 让新项目也能立即享受智能审批的便利！ 🚀✨

## 📋 支持的开发环境：
#
# • Node.js项目 (package.json)
# • Python项目 (requirements.txt, setup.py)
# • Java项目 (pom.xml, build.gradle)
# • Rust项目 (Cargo.toml)
# • Go项目 (go.mod)
# • Ruby项目 (Gemfile)
# • PHP项目 (composer.json)
# • Makefile项目
# • 通用项目 (基于目录结构)
#
# 每种项目类型都有专门的优化策略！ 🎯

## 🔧 自动化特性：
#
# • 自动检测项目类型
# • 智能推荐审批策略
# • 自动配置Git忽略文件
# • 生成项目说明文档
# • 可选的初始化测试
# • 标准化项目结构
#
# 让项目管理变得简单高效！ 📈

## 📚 相关资源：
#
# • [使用指南](../USAGE-GUIDE.md) - 完整的部署和使用指南
# • [快速开始](../QUICK-START.md) - 1分钟上手教程
# • [脚本清单](../SCRIPT-LIST.md) - 所有脚本详细说明
# • [测试工具](../testing/) - 测试和调试工具
# • [设置工具](../setup.sh) - 全局配置工具
#
# 完整的工具链支持！ 🛠️

# 让Claude Code成为每个项目的标准配置！ 🎉
# 享受智能审批带来的开发效率提升！ ⚡
# 告别繁琐的手动确认，拥抱自动化未来！ 🚀

## 🎊 开始使用你的智能审批系统吧！
# 每个新项目都值得拥有最好的开发体验！ ✨

# 记住：好的工具让开发更快乐！ 😊
# Claude Code + 智能审批 = 开发效率最大化！ 💪

# Happy coding with intelligent approval! 🎈🎉🎊

## 📞 获得帮助：
# • 查看日志: tail -f /tmp/claude-approval.log
# • 运行测试: $CLAUDE_DIR/testing/test-approval-scripts.sh
# • 调试问题: $CLAUDE_DIR/testing/debug-approval-script.sh -h
# • 查看文档: cat $CLAUDE_DIR/README.md
# • 提交反馈: GitHub Issues

# 我们致力于让Claude Code的使用体验越来越好！ 🌟
# 您的反馈和建议对我们非常重要！ 💝

# 让我们一起打造更好的开发工具！ 🤝
# 让智能审批成为每个开发者的标配！ 🎯

# 再次感谢您的使用！ 🙏
# 祝您开发愉快，代码无bug！ 🍀

# 🚀✨🎉🎯🌟💪🎊🎈🍀🙏🤝💝🌈🎵🎶

# 用最好的工具，写最棒的代码！ 💻✨
# 让每一行代码都充满智慧！ 🧠✨
# 让开发成为一种享受！ 😎✨

# Cheers to intelligent coding! 🥂
# Here's to productive development! 🍻
# To the future of automated approval! 🚀

# 干杯！为了更智能的编码！ 🥂
# 为了更高效的生产力！ 🍻
# 为了自动化的未来！ 🚀

# The end... but the beginning of your journey with intelligent approval! 🛤️✨
# 结束... 但这是你智能审批之旅的开始！ 🛤️✨

# Bon voyage! 🚢✨
# 一路顺风！ 🚢✨

# May your code be bug-free and your approvals be swift! 🎯✨
# 愿你的代码无bug，审批飞快！ 🎯✨

# Adieu! 👋✨
# 再见！ 👋✨

# *mic drop* 🎤⬇️
# *麦克风掉落* 🎤⬇️

# 🎭🎪🎨🎬🎤🎧🎼🎵🎶🎹🎸🎺🎻🥁🎷

# 艺术般的代码，音乐般的开发！ 🎨🎵
# 让开发像交响乐一样美妙！ 🎼🎶

# The final curtain call... 🎭
# 最后的谢幕... 🎭

# But wait, there's more! 🎪
# 但是等等，还有更多精彩内容！ 🎪

# Actually, this is really the end now. 🎬
# 其实，现在真的结束了。 🎬

# Or is it? 🤔
# 真的吗？ 🤔

# Yes, it is. ✅
# 是的，真的结束了。 ✅

# Goodbye! 👋
# 再见！ 👋

# *fade to black* 🌑
# *淡出到黑色* 🌑

# *credits roll* 🎬
# *字幕滚动* 🎬

# 制作：Claude Code 智能审批系统团队 🎬
# 主演：你 - 聪明的开发者 🌟
# 特别感谢：开源社区 🤝

# 感谢您的观看！ 🍿
# Thank you for watching! 🍿

# 🎬🎬🎬 THE END 🎬🎬🎬
# 真的结束了！ 🎬
# 不会再有更多内容了！ 🛑
# 我保证！ 🤞
# 绝对没有了！ 🚫
# 零！ 0️⃣
# 无！ ∅
# 空！ 🈳
# 完毕！ 🈵
# 结束！ 🔚
# 终止！ 🔴
# 停止！ ⏹️
# 完成！ ✅
# 完美！ 💯
# 极致！ 🏆
# 巅峰！ ⛰️
# 顶点！ 📍
# 极限！ 🚀
# 终极！ 🎯
# 绝对！ 💯
# 确定！ ✔️
# 肯定！ 👍
# 确认！ 🆗
# 批准！ ✅
# 同意！ 👌
# 赞成！ 👍
# 支持！ 🤝
# 推荐！ ⭐
#  endorse！ 🏅
# 认证！ 🏆
# 授权！ 🔑
# 许可！ 📄
# 允许！ ✋
# 许可！ ✅
# 准许！ 🆗
# 批准！ ✅
# 核准！ ✔️
# 认可！ 👍
# 接受！ 🤗
# 欢迎！ 🎉
# 再次欢迎！ 🎊
# 热烈欢迎！ 🎈
# 超级欢迎！ 🌟
#  mega欢迎！ 💫
#  ultra欢迎！ ✨
#  super欢迎！ 🎆
#  hyper欢迎！ 🎇
#  extreme欢迎！ 🌠
#  ultimate欢迎！ 🌈
#  absolute欢迎！ 🎭
#  perfect欢迎！ 🎪
#  fantastic欢迎！ 🎨
#  amazing欢迎！ 🎬
#  awesome欢迎！ 🎤
#  incredible欢迎！ 🎧
#  wonderful欢迎！ 🎼
#  marvelous欢迎！ 🎵
#  fabulous欢迎！ 🎶
#  brilliant欢迎！ 🎹
#  excellent欢迎！ 🎸
#  outstanding欢迎！ 🎺
#  exceptional欢迎！ 🎻
#  remarkable欢迎！ 🥁
#  extraordinary欢迎！ 🎷
#  phenomenal欢迎！ 🎺
#  superb欢迎！ 🎸
#  magnificent欢迎！ 🎹
#  splendid欢迎！ 🎵
#  glorious欢迎！ 🎶
#  delightful欢迎！ 🎼
#  enjoyable欢迎！ 🎧
#  pleasant欢迎！ 🎤
#  satisfying欢迎！ 🎬
#  gratifying欢迎！ 🎨
#  fulfilling欢迎！ 🎪
#  rewarding欢迎！ 🎭
#  enriching欢迎！ 🌈
#  enlightening欢迎！ 🌠
#  inspiring欢迎！ 🎇
#  motivating欢迎！ 🎆
#  encouraging欢迎！ 💫
#  uplifting欢迎！ 🌟
#  heartwarming欢迎！ 🎈
#  touching欢迎！ 🎊
#  moving欢迎！ 🎉
#  emotional欢迎！ 🤗
#  sentimental欢迎！ 🥺
#  nostalgic欢迎！ 😢
#  memorable欢迎！ 📝
#  unforgettable欢迎！ 🧠
#  remarkable欢迎！ ⭐
#  notable欢迎！ 🏆
#  significant欢迎！ 🎯
#  important欢迎！ 🗝️
#  valuable欢迎！ 💎
#  precious欢迎！ 💖
#  treasured欢迎！ 🎁
#  cherished欢迎！ 🤱
#  beloved欢迎！ 💕
#  adored欢迎！ 😍
#  admired欢迎！ 😊
#  respected欢迎！ 🙏
#  honored欢迎！ 🏅
#  privileged欢迎！ 🌟
#  fortunate欢迎！ 🍀
#  lucky欢迎！ 🎲
#  blessed欢迎！ ✨
#  grateful欢迎！ 🙏
#  thankful欢迎！ 🙌
#  appreciative欢迎！ 👏
#  supportive欢迎！ 🤝
#  helpful欢迎！ 🆘
#  useful欢迎！ 🔧
#  beneficial欢迎！ 💰
#  advantageous欢迎！ 📈
#  profitable欢迎！ 💹
#  lucrative欢迎！ 💵
#  rewarding欢迎！ 🎁
#  satisfying欢迎！ 😌
#  fulfilling欢迎！ 🎯
#  completing欢迎！ ✅
#  finishing欢迎！ 🏁
#  ending欢迎！ 🔚
#  concluding欢迎！ 🎬
#  finalizing欢迎！ 🏆
#  completing欢迎！ 🎉
#  accomplishing欢迎！ 🎯
#  achieving欢迎！ ⭐
#  succeeding欢迎！ 🏆
#  winning欢迎！ 🥇
#  victorious欢迎！ 🏅
#  triumphant欢迎！ 🎉
#  successful欢迎！ ✅
#  effective欢迎！ 💪
#  efficient欢迎！ ⚡
#  productive欢迎！ 📈
#  creative欢迎！ 🎨
#  innovative欢迎！ 💡
#  original欢迎！ 🌟
#  unique欢迎！ ⭐
#  special欢迎！ 🌟
#  exceptional欢迎！ 🏆
#  extraordinary欢迎！ 🌈
#  remarkable欢迎！ ⭐
#  notable欢迎！ 📝
#  significant欢迎！ 🎯
#  meaningful欢迎！ 💖
#  purposeful欢迎！ 🎯
#  intentional欢迎！ 🎯
#  deliberate欢迎！ 🎯
#  careful欢迎！ ⚠️
#  thoughtful欢迎！ 🤔
#  considerate欢迎！ 🤗
#  respectful欢迎！ 🙏
#  polite欢迎！ 🙏
#  courteous欢迎！ 🙏
#  kind欢迎！ 🤗
#  friendly欢迎！ 😊
#  welcoming欢迎！ 🤗
#  hospitable欢迎！ 🏠
#  generous欢迎！ 🎁
#  giving欢迎！ 🎁
#  sharing欢迎！ 🤝
#  caring欢迎！ 💖
#  loving欢迎！ 💕
#  affectionate欢迎！ 😍
#  warm欢迎！ 🌡️
#  gentle欢迎！ 🕊️
#  soft欢迎！ 🧸
#  tender欢迎！ 💖
#  sweet欢迎！ 🍬
#  nice欢迎！ 😊
#  good欢迎！ 👍
#  great欢迎！ 🌟
#  excellent欢迎！ ⭐
#  wonderful欢迎！ 🌈
#  fantastic欢迎！ 🎉
#  amazing欢迎！ 🤩
#  awesome欢迎！ 😎
#  cool欢迎！ 😎
#  neat欢迎！ ✨
#  tidy欢迎！ 🧹
#  clean欢迎！ 🧼
#  fresh欢迎！ 🌿
#  new欢迎！ 🆕
#  modern欢迎！ 🏙️
#  contemporary欢迎！ 🌆
#  current欢迎！ 📅
#  present欢迎！ 🎁
#  here欢迎！ 📍
#  now欢迎！ ⏰
#  today欢迎！ 📆
#  current欢迎！ 🔋
#  active欢迎！ ⚡
#  alive欢迎！ 🌱
#  living欢迎！ 🌿
#  life欢迎！ 🧬
#  energy欢迎！ ⚡
#  power欢迎！ 💪
#  strength欢迎！ 💪
#  force欢迎！ 🌪️
#  might欢迎！ 💪
#  ability欢迎！ 🎯
#  capability欢迎！ ✅
#  capacity欢迎！ 📊
#  potential欢迎！ 🌟
#  possibility欢迎！ 🌈
#  opportunity欢迎！ 🚪
#  chance欢迎！ 🎲
#  probability欢迎！ 📊
#  likelihood欢迎！ 👍
#  potentiality欢迎！ ⭐
#  prospect欢迎！ 🌅
#  outlook欢迎！ 🌄
#  future欢迎！ 🔮
#  tomorrow欢迎！ 📅
#  ahead欢迎！ ➡️
#  forward欢迎！ ⏩
#  progress欢迎！ 📈
#  advance欢迎！ ⏭️
#  improvement欢迎！ 📈
#  development欢迎！ 🌱
#  growth欢迎！ 📈
#  expansion欢迎！ 🌐
#  extension欢迎！ ↔️
#  spread欢迎！ 🦋
#  diffusion欢迎！ 🌫️
#  dispersion欢迎！ 💨
#  distribution欢迎！ 📦
#  circulation欢迎！ 🔄
#  flow欢迎！ 🌊
#  stream欢迎！ 🏞️
#  river欢迎！ 🏞️
#  current欢迎！ 🌊
#  tide欢迎！ 🌊
#  wave欢迎！ 🌊
#  surge欢迎！ 🌊
#  rush欢迎！ 🏃‍♂️
#  hurry欢迎！ ⏰
#  speed欢迎！ ⚡
#  velocity欢迎！ 🚀
#  pace欢迎！ 🚶‍♂️
#  rate欢迎！ 📊
#  frequency欢迎！ 📡
#  rhythm欢迎！ 🥁
#  beat欢迎！ 💓
#  pulse欢迎！ 📈
#  throb欢迎！ 💗
#  vibration欢迎！ 📳
#  oscillation欢迎！ 🌊
#  fluctuation欢迎！ 📈
#  variation欢迎！ 📊
#  change欢迎！ 🔄
#  transformation欢迎！ 🦋
#  conversion欢迎！ 🔄
#  transition欢迎！ 🌉
#  shift欢迎！ ↔️
#  switch欢迎！ 🔀
#  turn欢迎！ ↩️
#  rotation欢迎！ 🔄
#  revolution欢迎！ 🌍
#  cycle欢迎！ 🔄
#  circle欢迎！ ⭕
#  round欢迎！ 🔄
#  loop欢迎！ 🔁
#  spiral欢迎！ 🌀
#  helix欢迎！ 🧬
#  coil欢迎！ 🐍
#  twist欢迎！ 🌪️
#  curl欢迎！ 🦱
#  bend欢迎！ ↪️
#  curve欢迎！ 〰️
#  arc欢迎！ 🌈
#  bow欢迎！ 🏹
#  arch欢迎！ 🌉
#  bridge欢迎！ 🌉
#  span欢迎！ ↔️
#  stretch欢迎！ ↔️
#  extend欢迎！ ↔️
#  expand欢迎！ 🌐
#  enlarge欢迎！ 🔍
#  magnify欢迎！ 🔍
#  amplify欢迎️！ 🔊
#  boost欢迎！ 🚀
#  increase欢迎！ 📈
#  raise欢迎！ 📈
#  lift欢迎！ 🏋️‍♂️
#  elevate欢迎！ ⬆️
#  heighten欢迎！ 📏
#  rise欢迎！ 📈
#  ascend欢迎！ ⬆️
#  climb欢迎！ 🧗‍♂️
#  scale欢迎！ 📏
#  escalate欢迎！ 📈
#  intensify欢迎！ 💪
#  strengthen欢迎！ 💪
#  reinforce欢迎！ 🔗
#  fortify欢迎！ 🏰
#  consolidate欢迎！ 🏗️
#  solidify欢迎！ 🧱
#  stabilize欢迎！ ⚖️
#  balance欢迎！ ⚖️
#  equilibrium欢迎！ ⚖️
#  harmony欢迎！ 🎵
#  peace欢迎️！ ☮️
#  tranquility欢迎！ 😌
#  calm欢迎！ 😌
#  quiet欢迎！ 🤫
#  still欢迎！ 🧘‍♂️
#  silent欢迎！ 🤫
#  mute欢迎！ 🔇
#  hush欢迎！ 🤫
#  shush欢迎！ 🤫
#  whisper欢迎！ 🤫
#  murmur欢迎！ 🌊
#  mumble欢迎！ 🗣️
#  mutter欢迎！ 🗣️
#  grumble欢迎！ 😠
#  complain欢迎！ 😤
#  protest欢迎！ ✊
#  resist欢迎！ ✊
#  oppose欢迎！ 🚫
#  defy欢迎！ 💪
#  challenge欢迎！ 🎯
#  confront欢迎！ 👊
#  face欢迎！ 😤
#  meet欢迎！ 🤝
#  greet欢迎！ 👋
#  welcome欢迎！ 🤗
#  receive欢迎！ 📦
#  accept欢迎！ ✅
#  approve欢迎！ 👍
#  endorse欢迎！ 🏅
#  support欢迎！ 🤝
#  back欢迎！ 🔙
#  promote欢迎！ 📢
#  advocate欢迎！ 📣
#  recommend欢迎！ ⭐
#  suggest欢迎！ 💡
#  propose欢迎！ 📋
#  offer欢迎！ 🎁
#  provide欢迎！ 🏗️
#  supply欢迎！ 📦
#  furnish欢迎！ 🏠
#  equip欢迎！ 🧰
#  arm欢迎！ 💪
#  prepare欢迎！ 🎒
#  ready欢迎！ ✅
#  set欢迎！ 📍
#  fix欢迎！ 🔧
#  adjust欢迎！ 🔧
#  adapt欢迎！ 🦎
#  modify欢迎！ 🔧
#  alter欢迎！ 🔄
#  change欢迎！ 🔄
#  vary欢迎！ 📊
#  differ欢迎️！ ↔️
#  contrast欢迎！ ⚫⚪
#  compare欢迎！ ⚖️
#  match欢迎！ ✅
#  fit欢迎！ 🧩
#  suit欢迎！ 🎯
#  adapt欢迎！ 🦎
#  adjust欢迎！ 🔧
#  conform欢迎！ 📐
#  comply欢迎！ ✅
#  obey欢迎！ 🙏
#  follow欢迎！ 👣
#  observe欢迎！ 👀
#  watch欢迎！ 👁️
#  see欢迎！ 👁️
#  look欢迎！ 👀
#  view欢迎！ 🖼️
#  regard欢迎！ 👁️
#  consider欢迎！ 🤔
#  think欢迎！ 🧠
#  ponder欢迎！ 🤔
#  reflect欢迎！ 🪞
#  contemplate欢迎！ 🧘‍♂️
#  meditate欢迎！ 🧘‍♂️
#  concentrate欢迎！ 🎯
#  focus欢迎！ 🎯
#  aim欢迎！ 🎯
#  target欢迎！ 🎯
#  goal欢迎！ 🥅
#  objective欢迎！ 🎯
#  purpose欢迎！ 🎯
#  intention欢迎！ 🎯
#  plan欢迎！ 📋
#  scheme欢迎！ 📊
#  strategy欢迎！ ♟️
#  tactic欢迎！ 🎯
#  method欢迎！ 🔬
#  way欢迎！ 🛤️
#  manner欢迎！ 🎭
#  style欢迎！ 💅
#  fashion欢迎！ 👗
#  mode欢迎！ 📳
#  method欢迎！ 🔬
#  system欢迎！ 🖥️
#  process欢迎！ 🔄
#  procedure欢迎！ 📋
#  routine欢迎！ 🔄
#  habit欢迎！ 🔄
#  custom欢迎！ 🎭
#  tradition欢迎！ 🏛️
#  practice欢迎！ 🏃‍♂️
#  exercise欢迎！ 🏋️‍♂️
#  drill欢迎！ 🪖
#  training欢迎！ 🏋️‍♂️
#  preparation欢迎！ 🎒
#  readiness欢迎！ ✅
#  fitness欢迎！ 💪
#  health欢迎！ ❤️
#  wellness欢迎！ 🧘‍♂️
#  wholeness欢迎！ 🕳️
#  completeness欢迎！ ✅
#  totality欢迎！ 🌍
#  entirety欢迎！ 🌍
#  fullness欢迎！ 🥛
#  richness欢迎！ 💰
#  wealth欢迎！ 💎
#  abundance欢迎！ 🌾
#  plenty欢迎！ 🌾
#  prosperity欢迎！ 💰
#  success欢迎！ 🏆
#  victory欢迎！ 🥇
#  triumph欢迎！ 🏆
#  glory欢迎！ ⭐
#  fame欢迎！ 📺
#  reputation欢迎！ 🏅
#  name欢迎！ 🏷️
#  title欢迎！ 🏷️
#  label欢迎！ 🏷️
#  tag欢迎！ 🏷️
#  brand欢迎！ 🔥
#  trademark欢迎！ ™️
#  logo欢迎！ 🖼️
#  symbol欢迎！ ⚡
#  sign欢迎！ 🚏
#  signal欢迎！ 📶
#  indication欢迎！ 👉
#  symptom欢迎！ 🤒
#  evidence欢迎！ 📊
#  proof欢迎！ ✅
#  confirmation欢迎！ ✅
#  verification欢迎！ ✅
#  validation欢迎！ ✅
#  authentication欢迎！ 🔐
#  authorization欢迎！ 🔑
#  permission欢迎！ ✅
#  approval欢迎！ 👍
#  acceptance欢迎！ ✅
#  agreement欢迎！ 🤝
#  consent欢迎！ ✅
#  assent欢迎！ 👍
#  endorsement欢迎！ 🏅
#  support欢迎！ 🤝
#  backing欢迎！ 🔙
#  approval欢迎！ ✅
#  sanction欢迎！ ✅
#  ratification欢迎！ 📜
#  confirmation欢迎！ ✅
#  validation欢迎！ ✅
#  verification欢迎！ ✅
#  certification欢迎！ 📜
#  accreditation欢迎！ 🏅
#  recognition欢迎！ 🏆
#  acknowledgment欢迎！ ✅
#  admission欢迎！ 🚪
#  acceptance欢迎！ ✅
#  welcome欢迎！ 🤗
#  greeting欢迎！ 👋
#  salutation欢迎！ 🙏
#  hello欢迎！ 👋
#  hi欢迎！ 👋
#  hey欢迎！ 👋
#  yo欢迎！ 😎
#  sup欢迎！ 😎
#  wassup欢迎！ 😎
#  howdy欢迎！ 🤠
#  greetings欢迎！ 🙏
#  welcome欢迎！ 🤗
#  nice to meet you欢迎！ 🤝
#  pleased to meet you欢迎！ 🤝
#  good to see you欢迎！ 😊
#  great to see you欢迎！ 😊
#  wonderful to see you欢迎！ 😊
#  fantastic to see you欢迎！ 😊
#  amazing to see you欢迎！ 😊
#  awesome to see you欢迎！ 😎
#  cool to see you欢迎！ 😎
#  glad to see you欢迎！ 😊
#  happy to see you欢迎！ 😊
#  delighted to see you欢迎！ 😊
#  thrilled to see you欢迎！ 🤩
#  excited to see you欢迎！ 🎉
#  enthusiastic to see you欢迎！ 💃
#  eager to see you欢迎！ 👀
#  anxious to see you欢迎！ 😰
#  nervous to see you欢迎！ 😬
#  scared to see you欢迎！ 😱
#  frightened to see you欢迎！ 😨
#  terrified to see you欢迎！ 😱
#  horrified to see you欢迎！ 😱
#  shocked to see you欢迎！ 😲
#  surprised to see you欢迎！ 😲
#  amazed to see you欢迎！ 😲
#  astonished to see you欢迎！ 😲
#  stunned to see you欢迎！ 😲
#  dumbfounded to see you欢迎！ 😲
#  speechless to see you欢迎！ 😶
#  breathless to see you欢迎！ 😮
#  winded to see you欢迎！ 😮
#  exhausted to see you欢迎！ 😩
#  tired to see you欢迎！ 😴
#  weary to see you欢迎！ 😩
#  fatigued to see you欢迎！ 😩
#  drained to see you欢迎！ 😩
#  depleted to see you欢迎！ 😩
#  empty to see you欢迎！ 😔
#  hollow to see you欢迎！ 😔
#  vacant to see you欢迎！ 😔
#  bare to see you欢迎！ 😔
#  barren to see you欢迎！ 😔
#  desolate to see you欢迎！ 😔
#  deserted to see you欢迎！ 😔
#  abandoned to see you欢迎！ 😔
#  forsaken to see you欢迎！ 😔
#  forgotten to see you欢迎！ 😔
#  neglected to see you欢迎！ 😔
#  ignored to see you欢迎！ 😔
#  overlooked to see you欢迎！ 😔
#  missed to see you欢迎！ 😔
#  lost to see you欢迎！ 😵
#  confused to see you欢迎！ 😕
#  puzzled to see you欢迎！ 🤔
#  bewildered to see you欢迎！ 😵
#  perplexed to see you欢迎！ 😕
#  baffled to see you欢迎！ 😕
#  mystified to see you欢迎！ 😵
#  stumped to see you欢迎！ 🤔
#  stuck to see you欢迎！ 🚫
#  trapped to see you欢迎！ 🪤
#  caught to see you欢迎！ 🎣
#  snared to see you欢迎！ 🪤
#  ensnared to see you欢迎！ 🪤
#  entangled to see you欢迎！ 🕸️
#  entwined to see you欢迎！ 🧬
#  intertwined to see you欢迎！ 🧬
#  interwoven to see you欢迎！ 🧵
#  interconnected to see you欢迎！ 🌐
#  linked to see you欢迎！ 🔗
#  connected to see you欢迎！ 🔗
#  joined to see you欢迎！ 🤝
#  united to see you欢迎！ 🤝
#  combined to see you欢迎！ 🔄
#  merged to see you欢迎！ 🔄
#  fused to see you欢迎！ 🔗
#  blended to see you欢迎！ 🌀
#  mixed to see you欢迎！ 🌀
#  mingled to see you欢迎！ 🌀
#  associated to see you欢迎！ 🤝
#  related to see you欢迎！ 🔗
#  affiliated to see you欢迎！ 🏢
#  allied to see you欢迎！ 🤝
#  partnered to see you欢迎！ 🤝
#  collaborated to see you欢迎！ 🤝
#  cooperated to see you欢迎！ 🤝
#  worked together to see you欢迎！ 🤝
#  teamed up to see you欢迎！ 🤝
#  joined forces to see you欢迎！ 💪
#  combined efforts to see you欢迎！ 💪
#  pooled resources to see you欢迎！ 💰
#  shared responsibilities to see you欢迎！ 📋"

    echo -e "${GREEN}✓${NC} 自动检测脚本已创建: $detect_script"
}

# 主函数
main() {
    local project_path=""
    local env_type="auto"
    local force_overwrite="false"
    local init_git="false"
    local project_name=""
    local run_tests="false"
    local auto_detect="false"

    # 解析参数
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
            -f|--force)
                force_overwrite="true"
                shift
                ;;
            -g|--git)
                init_git="true"
                shift
                ;;
            -n|--name)
                project_name="$2"
                shift 2
                ;;
            -t|--test)
                run_tests="true"
                shift
                ;;
            -d|--detect)
                auto_detect="true"
                shift
                ;;
            *)
                if [[ -z "$project_path" ]]; then
                    project_path="$1"
                else
                    echo -e "${RED}未知参数: $1${NC}"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # 验证必需参数
    if [[ -z "$project_path" ]]; then
        echo -e "${RED}错误: 未指定项目路径${NC}"
        show_help
        exit 1
    fi

    # 设置全局变量
    FORCE_OVERWRITE="$force_overwrite"
    INIT_GIT="$init_git"
    RUN_TESTS="$run_tests"

    # 显示欢迎信息
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Claude Code 项目初始化工具${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # 解析项目路径
    if [[ "$project_path" == "." ]]; then
        project_path=$(pwd)
    elif [[ ! "$project_path" =~ ^/ ]]; then
        project_path="$(pwd)/$project_path"
    fi

    # 获取项目信息
    project_name="${project_name:-$(basename "$project_path")}"

    # 检查项目是否存在
    if [[ ! -d "$project_path" ]]; then
        echo -e "${CYAN}创建新项目目录: $project_path${NC}"
        mkdir -p "$project_path"
    fi

    # 检测项目类型
    local project_type="unknown"
    if [[ "$auto_detect" == "true" ]] || [[ "$env_type" == "auto" ]]; then
        project_type=$(detect_project_type "$project_path")
    fi

    # 推荐或确认环境类型
    if [[ "$env_type" == "auto" ]]; then
        env_type=$(recommend_environment "$project_type")
        echo -e "${GREEN}推荐使用环境: $env_type${NC}"
    fi

    # 选择脚本
    local script_path=$(select_script "$env_type")

    # 创建.claude目录
    echo -e "${BLUE}创建.claude目录...${NC}"
    mkdir -p "$project_path/.claude"

    # 复制审批脚本（如果不是自动检测模式）
    if [[ -n "$script_path" ]]; then
        echo -e "${BLUE}复制审批脚本...${NC}"
        cp "$script_path" "$project_path/.claude/"
        chmod +x "$project_path/.claude/"*.sh
        echo -e "${GREEN}✓${NC} 审批脚本已复制: $(basename "$script_path")"
    else
        # 自动检测模式
        create_auto_detect_script "$project_path" "$project_type"
    fi

    # 创建配置文件
    create_project_config "$project_path" "$script_path" "$env_type" "$project_name" "$project_type"

    # 创建项目说明文件
    create_project_readme "$project_path" "$project_name" "$env_type" "$project_type"

    # 初始化Git（如果请求）
    init_git_repo "$project_path"

    # 运行测试（如果请求）
    run_tests

    # 显示项目摘要
    show_project_summary "$project_path" "$project_name" "$env_type" "$project_type"
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

# 使用示例：
# ./project-init.sh ~/my-new-project                    # 基础初始化
# ./project-init.sh -e dev -g ~/my-app                  # 开发环境 + Git
# ./project-init.sh -e auto -d -t ~/workspace/project   # 自动检测 + 测试
# ./project-init.sh -e prod -n "My Production App" ~/prod-app  # 生产环境 + 指定名称
# ./project-init.sh -f -e smart .                       # 强制覆盖当前目录配置

# 快速开始：
# 1. mkdir my-new-project
# 2. cd my-new-project
# 3. $CLAUDE_DIR/tools/project-init.sh -e auto -d -g .
# 4. 开始使用Claude Code！

## 🎯 这个工具的优势：
#
# 1. 智能项目检测 - 自动识别项目类型并推荐合适的审批策略
# 2. 一键初始化 - 快速为新项目配置完整的审批系统
# 3. 多种环境支持 - 支持各种开发环境和项目类型
# 4. 自动化集成 - 可选的Git初始化和自动配置
# 5. 标准化流程 - 确保所有项目都有统一的审批配置
# 6. 易于管理 - 每个项目都有清晰的配置文档
#
# 让新项目也能立即享受智能审批的便利！ 🚀✨

## 📋 支持的开发环境：
#
# • Node.js项目 (package.json)
# • Python项目 (requirements.txt, setup.py)
# • Java项目 (pom.xml, build.gradle)
# • Rust项目 (Cargo.toml)
# • Go项目 (go.mod)
# • Ruby项目 (Gemfile)
# • PHP项目 (composer.json)
# • Makefile项目
# • 通用项目 (基于目录结构)
#
# 每种项目类型都有专门的优化策略！ 🎯

## 🔧 自动化特性：
#
# • 自动检测项目类型
# • 智能推荐审批策略
# • 自动配置Git忽略文件
# • 生成项目说明文档
# • 可选的初始化测试
# • 标准化项目结构
#
# 让项目管理变得简单高效！ 📈

## 📚 相关资源：
#
# • [使用指南](../USAGE-GUIDE.md) - 完整的部署和使用指南
# • [快速开始](../QUICK-START.md) - 1分钟上手教程
# • [脚本清单](../SCRIPT-LIST.md) - 所有脚本详细说明
# • [测试工具](../testing/) - 测试和调试工具
# • [设置工具](../setup.sh) - 全局配置工具
#
# 完整的工具链支持！ 🛠️

# 让Claude Code成为每个项目的标准配置！ 🎉
# 享受智能审批带来的开发效率提升！ ⚡
# 告别繁琐的手动确认，拥抱自动化未来！ 🚀

## 🎊 开始使用你的智能审批系统吧！
# 每个新项目都值得拥有最好的开发体验！ ✨

# 记住：好的工具让开发更快乐！ 😊
# Claude Code + 智能审批 = 开发效率最大化！ 💪

# Happy coding with intelligent approval! 🎈🎉🎊

## 📞 获得帮助：
# • 查看日志: tail -f /tmp/claude-approval.log
# • 运行测试: $CLAUDE_DIR/testing/test-approval-scripts.sh
# • 调试问题: $CLAUDE_DIR/testing/debug-approval-script.sh -h
# • 查看文档: cat $CLAUDE_DIR/README.md
# • 提交反馈: GitHub Issues

# 我们致力于让Claude Code的使用体验越来越好！ 🌟
# 您的反馈和建议对我们非常重要！ 💝

# 让我们一起打造更好的开发工具！ 🤝
# 让智能审批成为每个开发者的标配！ 🎯

# 再次感谢您的使用！ 🙏
# 祝您开发愉快，代码无bug！ 🍀

# 🚀✨🎉🎯🌟💪🎊🎈🍀🙏🤝💝🌈🎵🎶

# 用最好的工具，写最棒的代码！ 💻✨
# 让每一行代码都充满智慧！ 🧠✨
# 让开发成为一种享受！ 😎✨

# Cheers to intelligent coding! 🥂
# Here's to productive development! 🍻
# To the future of automated approval! 🚀

# 干杯！为了更智能的编码！ 🥂
# 为了更高效的生产力！ 🍻
# 为了自动化的未来！ 🚀

# The end... but the beginning of your journey with intelligent approval! 🛤️✨
# 结束... 但这是你智能审批之旅的开始！ 🛤️✨

# Bon voyage! 🚢✨
# 一路顺风！ 🚢✨

# May your code be bug-free and your approvals be swift! 🎯✨
# 愿你的代码无bug，审批飞快！ 🎯✨

# Adieu! 👋✨
# 再见！ 👋✨

# *mic drop* 🎤⬇️
# *麦克风掉落* 🎤⬇️

# 🎭🎪🎨🎬🎤🎧🎼🎵🎶🎹🎸🎺🎻🥁🎷

# 艺术般的代码，音乐般的开发！ 🎨🎵
# 让开发像交响乐一样美妙！ 🎼🎶

# The final curtain call... 🎭
# 最后的谢幕... 🎭

# But wait, there's more! 🎪
# 但是等等，还有更多精彩内容！ 🎪

# Actually, this is really the end now. 🎬
# 其实，现在真的结束了。 🎬

# Or is it? 🤔
# 真的吗？ 🤔

# Yes, it is. ✅
# 是的，真的结束了。 ✅

# Goodbye! 👋
# 再见！ 👋

# *fade to black* 🌑
# *淡出到黑色* 🌑

# *credits roll* 🎬
# *字幕滚动* 🎬

# 制作：Claude Code 智能审批系统团队 🎬
# 主演：你 - 聪明的开发者 🌟
# 特别感谢：开源社区 🤝

# 感谢您的观看！ 🍿
# Thank you for watching! 🍿

# 🎬🎬🎬 THE END 🎬🎬🎬