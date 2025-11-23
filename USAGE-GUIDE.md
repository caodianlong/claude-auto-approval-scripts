# Claude Code 自动审批系统 - 完整使用指南

## 📋 目录
- [安装部署方案](#安装部署方案)
- [项目管理策略](#项目管理策略)
- [实际使用示例](#实际使用示例)
- [最佳实践建议](#最佳实践建议)
- [环境管理工具](#环境管理工具)
- [故障排除指南](#故障排除指南)

## 🚀 安装部署方案

### 方案一：全局安装（推荐）

**适用于：个人用户、标准化团队**

```bash
# 1. 将脚本集合安装到全局位置
sudo mkdir -p /opt/claude-auto-approval
sudo cp -r claude-auto-approval-scripts/* /opt/claude-auto-approval/
sudo chmod -R 755 /opt/claude-auto-approval

# 2. 创建快捷方式
sudo ln -sf /opt/claude-auto-approval/setup.sh /usr/local/bin/claude-approval-setup

# 3. 全局配置（所有项目共享）
claude-approval-setup -s smart
```

**优点：**
- ✅ 一次安装，所有项目共享使用
- ✅ 便于统一管理和更新
- ✅ 节省磁盘空间
- ✅ 配置一致性
- ✅ 维护简单

### 方案二：用户级安装

**适用于：多用户服务器、个人偏好**

```bash
# 1. 安装到用户目录
mkdir -p ~/tools/claude-auto-approval
cp -r claude-auto-approval-scripts/* ~/tools/claude-auto-approval/

# 2. 添加到PATH环境变量
echo 'export PATH="$HOME/tools/claude-auto-approval:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 3. 设置审批脚本
cd ~/tools/claude-auto-approval
./setup.sh -s intelligent
```

### 方案三：项目特定安装

**适用于：特殊项目、隔离需求**

```bash
# 在特定项目中创建审批配置
mkdir -p my-project/.claude
cp /path/to/claude-auto-approval-scripts/advanced/combined-intelligent-approve.sh my-project/.claude/

# 创建项目特定的配置文件
cat > my-project/.claude/settings.json << 'EOF'
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit|Bash",
      "hooks": [
        {
          "type": "command",
          "command": "bash .claude/combined-intelligent-approve.sh"
        }
      ]
    }
  ]
}
EOF
```

## 📁 项目管理策略

### 推荐策略：全局默认 + 项目特定覆盖

#### 1. 配置优先级（从高到低）
```
项目特定配置 → 用户级配置 → 全局默认配置
```

#### 2. 配置层次结构
```
~/.claude/settings.json                    # 全局默认配置
~/project-a/.claude/settings.json         # 项目A特定配置
~/project-b/.claude/settings.json         # 项目B特定配置
```

#### 3. 智能配置继承
```bash
#!/bin/bash
# 智能配置加载器

load_claude_config() {
    local project_dir="${1:-$(pwd)}"

    # 检查项目特定配置
    if [[ -f "$project_dir/.claude/settings.json" ]]; then
        echo "使用项目特定配置: $project_dir/.claude/settings.json"
        return 0
    fi

    # 检查用户级配置
    if [[ -f "$HOME/.claude/settings.json" ]]; then
        echo "使用用户级配置: $HOME/.claude/settings.json"
        return 0
    fi

    # 使用全局默认配置
    echo "使用全局默认配置"
}
```

## 💡 实际使用示例

### 示例1：个人开发工作流
```bash
# 1. 设置开发环境（全局）
claude-approval-setup -s dev

# 2. 创建新项目（自动使用开发环境）
mkdir my-new-project
cd my-new-project
git init

# 3. 项目自动使用开发环境审批
# 可以执行开发相关操作，如：
# - npm install (自动批准)
# - 编辑配置文件 (自动批准)
# - 创建临时文件 (自动批准)
```

### 示例2：团队协作工作流
```bash
# 团队标准配置（全局）
sudo claude-approval-setup -s smart

# 特定项目需要更严格的安全控制
cd production-app
mkdir -p .claude
cp /opt/claude-auto-approval/prod-environment-approve.sh .claude/

# 创建项目特定配置
cat > .claude/settings.json << 'EOF'
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit|Bash",
      "hooks": [
        {
          "type": "command",
          "command": "bash .claude/prod-environment-approve.sh"
        }
      ]
    }
  ]
}
EOF
```

### 示例3：多环境项目
```bash
#!/bin/bash
# 项目环境切换器

switch_claude_environment() {
    local env_type="$1"  # dev, test, staging, prod
    local project_dir="${2:-$(pwd)}"

    echo "切换到 $env_type 环境..."

    # 确保.claude目录存在
    mkdir -p "$project_dir/.claude"

    case "$env_type" in
        "dev")
            cp ~/tools/claude-auto-approval/dev-environment-approve.sh "$project_dir/.claude/auto-approve.sh"
            ;;
        "test")
            cp ~/tools/claude-auto-approval/smart-context-approve.sh "$project_dir/.claude/auto-approve.sh"
            ;;
        "staging")
            cp ~/tools/claude-auto-approval/tiered-approval.sh "$project_dir/.claude/auto-approve.sh"
            ;;
        "prod")
            cp ~/tools/claude-auto-approval/prod-environment-approve.sh "$project_dir/.claude/auto-approve.sh"
            ;;
        *)
            echo "未知环境类型: $env_type"
            return 1
            ;;
    esac

    # 创建或更新项目配置
    cat > "$project_dir/.claude/settings.json" << EOF
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit|Bash|Delete|Move|Copy",
      "hooks": [
        {
          "type": "command",
          "command": "bash .claude/auto-approve.sh"
        }
      ]
    }
  ],
  "environment": "$env_type",
  "last_updated": "$(date)"
}
EOF

    echo "✅ 已切换到 $env_type 环境"
}

# 使用示例
switch_claude_environment "dev" "~/my-app"
switch_claude_environment "prod" "~/my-app"
```

## 🛠️ 环境管理工具

### 1. 环境切换脚本
```bash
#!/bin/bash
# Claude环境管理器

CLAUD_ENV_FILE="~/.claude_current_env"

set_claude_env() {
    local env_name="$1"
    local script_path=""

    case "$env_name" in
        "basic") script_path="$HOME/tools/claude-auto-approval/basic/auto-approve-basic.sh" ;;
        "smart") script_path="$HOME/tools/claude-auto-approval/smart/smart-context-approve.sh" ;;
        "dev") script_path="$HOME/tools/claude-auto-approval/environment-specific/dev-environment-approve.sh" ;;
        "prod") script_path="$HOME/tools/claude-auto-approval/environment-specific/prod-environment-approve.sh" ;;
        "intelligent") script_path="$HOME/tools/claude-auto-approval/advanced/combined-intelligent-approve.sh" ;;
        *) echo "未知环境: $env_name"; return 1 ;;
    esac

    # 更新全局配置
    cat > ~/.claude/settings.json << EOF
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit|Bash|Delete|Move|Copy",
      "hooks": [
        {
          "type": "command",
          "command": "bash $script_path"
        }
      ]
    }
  ],
  "current_environment": "$env_name",
  "last_updated": "$(date)"
}
EOF

    echo "$env_name" > "$CLAUD_ENV_FILE"
    echo "✅ 已切换到 $env_name 环境"
}

show_current_env() {
    if [[ -f "$CLAUD_ENV_FILE" ]]; then
        echo "当前环境: $(cat "$CLAUD_ENV_FILE")"
    else
        echo "未设置环境"
    fi
}

list_envs() {
    echo "可用环境:"
    echo "  basic      - 基础安全审批"
    echo "  smart      - 智能上下文审批"
    echo "  dev        - 开发环境审批"
    echo "  prod       - 生产环境审批"
    echo "  intelligent - 组合智能审批"
}

# 主函数
case "${1:-show}" in
    "set") set_claude_env "$2" ;;
    "show") show_current_env ;;
    "list") list_envs ;;
    *) echo "用法: $0 {set|show|list} [环境名称]" ;;
esac
```

### 2. 项目初始化模板
```bash
#!/bin/bash
# Claude项目初始化器

init_claude_project() {
    local project_name="$1"
    local env_type="${2:-smart}"

    echo "初始化项目: $project_name (环境: $env_type)"

    # 创建项目目录
    mkdir -p "$project_name"
    cd "$project_name"

    # 创建.claude目录
    mkdir -p .claude

    # 复制相应的审批脚本
    local script_source="$HOME/tools/claude-auto-approval"
    case "$env_type" in
        "basic") cp "$script_source/basic/auto-approve-basic.sh" .claude/ ;;
        "smart") cp "$script_source/smart/smart-context-approve.sh" .claude/ ;;
        "dev") cp "$script_source/environment-specific/dev-environment-approve.sh" .claude/ ;;
        "prod") cp "$script_source/environment-specific/prod-environment-approve.sh" .claude/ ;;
        "intelligent") cp "$script_source/advanced/combined-intelligent-approve.sh" .claude/ ;;
        *) echo "未知环境类型: $env_type"; exit 1 ;;
    esac

    # 创建项目配置文件
    cat > .claude/settings.json << EOF
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit|Bash|Delete|Move|Copy",
      "hooks": [
        {
          "type": "command",
          "command": "bash .claude/$(basename .claude/*.sh)"
        }
      ]
    }
  ],
  "project_environment": "$env_type",
  "created_at": "$(date)",
  "description": "$project_name 项目的Claude Code审批配置"
}
EOF

    # 创建项目说明文件
    cat > .claude/README.md << EOF
# Claude Code 审批配置

本项目使用 **$env_type** 环境审批模式。

## 当前审批脚本
- 脚本: $(basename .claude/*.sh)
- 类型: $env_type
- 创建时间: $(date)

## 使用方法
本项目已配置Claude Code自动审批，无需额外设置。

如需更改审批模式，请使用环境切换器：
\`\`\`bash
claude-env set dev  # 切换到开发环境
claude-env set prod # 切换到生产环境
\`\`\`

## 审批规则
$(cat "$script_source/$env_type"*README* 2>/dev/null | grep -A 20 "特点:" || echo "详见全局文档")
EOF

    # 初始化Git（可选）
    if command -v git >/dev/null 2>&1; then
        git init
        echo ".claude/" >> .gitignore
        echo "# Claude Code 审批配置" > README.md
        echo "项目已配置Claude Code自动审批系统" >> README.md
    fi

    echo "✅ 项目 $project_name 初始化完成"
    echo "📁 项目位置: $(pwd)"
    echo "🔧 审批模式: $env_type"
}

# 使用示例
if [[ $# -lt 1 ]]; then
    echo "用法: $0 <项目名称> [环境类型]"
    echo "环境类型: basic, smart, dev, prod, intelligent (默认: smart)"
    exit 1
fi

init_claude_project "$1" "${2:-smart}"
```

## 🎯 最佳实践建议

### 1. 分层管理策略
```
组织级全局配置
├── 部门级配置
│   ├── 团队级配置
│   │   ├── 项目级配置
│   │   └── 个人级配置
│   └── 环境特定配置
└── 通用最佳实践
```

### 2. 配置标准化
```bash
# 创建组织标准配置模板
mkdir -p ~/claude-configs/templates
cat > ~/claude-configs/templates/standard.json << 'EOF'
{
  "version": "1.0",
  "organization": "YourOrg",
  "security_level": "standard",
  "PreToolUse": [
    {
      "matcher": "Write|Edit|Bash",
      "hooks": [
        {
          "type": "command",
          "command": "bash /opt/claude-auto-approval/smart/smart-context-approve.sh"
        }
      ]
    }
  ],
  "logging": {
    "level": "info",
    "file": "/tmp/claude-approval.log"
  }
}
EOF
```

### 3. 自动化部署
```bash
#!/bin/bash
# 自动化部署脚本

deploy_claude_approval() {
    local target_dir="$1"
    local env_type="$2"

    echo "部署Claude审批系统到: $target_dir"

    # 1. 检查目标环境
    if [[ ! -d "$target_dir" ]]; then
        echo "错误: 目标目录不存在"
        return 1
    fi

    # 2. 创建.claude目录
    mkdir -p "$target_dir/.claude"

    # 3. 复制相应的审批脚本
    local script_source="/opt/claude-auto-approval"
    case "$env_type" in
        "dev"|"development")
            cp "$script_source/environment-specific/dev-environment-approve.sh" "$target_dir/.claude/"
            ;;
        "prod"|"production")
            cp "$script_source/environment-specific/prod-environment-approve.sh" "$target_dir/.claude/"
            ;;
        "cicd"|"ci-cd")
            cp "$script_source/environment-specific/cicd-environment-approve.sh" "$target_dir/.claude/"
            ;;
        *)
            cp "$script_source/smart/smart-context-approve.sh" "$target_dir/.claude/"
            ;;
    esac

    # 4. 创建配置文件
    cat > "$target_dir/.claude/settings.json" << EOF
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit|Bash|Delete|Move|Copy",
      "hooks": [
        {
          "type": "command",
          "command": "bash .claude/$(basename $target_dir/.claude/*.sh)"
        }
      ]
    }
  ],
  "deployment_info": {
    "environment": "$env_type",
    "deployed_at": "$(date)",
    "deployed_by": "$(whoami)",
    "script_version": "1.0.0"
  }
}
EOF

    # 5. 设置权限
    chmod +x "$target_dir/.claude/"*.sh

    # 6. 验证部署
    if [[ -f "$target_dir/.claude/settings.json" ]]; then
        echo "✅ Claude审批系统部署成功"
        echo "📁 配置文件: $target_dir/.claude/settings.json"
        echo "🔧 审批模式: $env_type"

        # 7. 运行测试
        echo "🧪 运行测试验证..."
        local test_result=$(echo '{"tool_name": "ls", "tool_input": {"path": "/tmp"}, "context": {"project_root": "'$target_dir'"}}' | bash "$target_dir/.claude/"*.sh)
        if [[ "$test_result" == *'"decision": "approve"'* ]]; then
            echo "✅ 测试通过"
        else
            echo "⚠️  测试未通过，请检查配置"
        fi
    else
        echo "❌ 部署失败"
        return 1
    fi
}

# 批量部署
batch_deploy() {
    local project_list_file="$1"
    local default_env="${2:-smart}"

    if [[ ! -f "$project_list_file" ]]; then
        echo "项目列表文件不存在: $project_list_file"
        return 1
    fi

    while IFS= read -r line; do
        local project_path=$(echo "$line" | awk '{print $1}')
        local env_type=$(echo "$line" | awk '{print $2}' || echo "$default_env")

        if [[ -n "$project_path" ]]; then
            echo "部署到: $project_path ($env_type)"
            deploy_claude_approval "$project_path" "$env_type"
            echo "---"
        fi
    done < "$project_list_file"
}
```

## 🔍 故障排除指南

### 常见问题1：脚本找不到
```bash
# 问题：Claude Code提示找不到审批脚本
# 解决：检查脚本路径和权限

# 检查全局配置
cat ~/.claude/settings.json | grep command

# 检查脚本是否存在
ls -la /opt/claude-auto-approval/basic/auto-approve-basic.sh

# 检查执行权限
chmod +x /opt/claude-auto-approval/basic/auto-approve-basic.sh

# 测试脚本直接执行
echo '{"tool_name": "ls", "tool_input": {"path": "/tmp"}, "context": {"project_root": "/home/user/project"}}' | bash /opt/claude-auto-approval/basic/auto-approve-basic.sh
```

### 常见问题2：审批决策不符合预期
```bash
# 问题：应该批准的却被拒绝，或应该拒绝的被批准
# 解决：使用调试工具分析

# 1. 查看审批日志
tail -f /tmp/claude-approval.log

# 2. 使用调试工具
./testing/debug-approval-script.sh -d 3 -v $(grep -o '"command": *"[^"]*"' ~/.claude/settings.json | cut -d'"' -f4) test-input.json

# 3. 检查配置文件
cat ~/.claude/settings.json | jq .

# 4. 验证脚本功能
./testing/test-approval-scripts.sh
```

### 常见问题3：多项目配置冲突
```bash
# 问题：项目A的配置影响了项目B
# 解决：检查配置继承关系

# 查看当前项目配置
ls -la .claude/settings.json 2>/dev/null && cat .claude/settings.json

# 查看用户级配置
cat ~/.claude/settings.json

# 检查全局配置（如果存在）
cat /etc/claude/settings.json 2>/dev/null || echo "无全局配置"

# 确定配置优先级
echo "配置优先级（从高到低）："
echo "1. 项目特定配置: .claude/settings.json"
echo "2. 用户级配置: ~/.claude/settings.json"
echo "3. 全局配置: /etc/claude/settings.json"
```

### 常见问题4：性能问题
```bash
# 问题：审批响应慢，影响使用体验
# 解决：性能分析和优化

# 1. 运行性能测试
./testing/test-approval-scripts.sh

# 2. 检查脚本执行时间
time echo '{"tool_name": "ls", "tool_input": {"path": "/tmp"}, "context": {"project_root": "/home/user/project"}}' | bash your-script.sh

# 3. 选择更轻量的脚本
# 基础脚本 > 智能脚本 > 分层脚本 > 组合脚本

# 4. 优化系统性能
# - 确保jq等依赖工具是最新版本
# - 检查磁盘I/O性能
# - 考虑使用SSD存储
```

## 📊 使用统计和监控

### 创建使用统计工具
```bash
#!/bin/bash
# Claude审批使用统计

analyze_claude_usage() {
    local log_file="/tmp/claude-approval.log"
    local days="${1:-7}"

    echo "Claude Code 审批使用统计 (最近 $days 天)"
    echo "========================================"

    # 统计审批决策
    echo "审批决策统计："
    grep "$(date -d "-$days days" '+%Y-%m-%d')" "$log_file" | grep -o "decision.*approve\|decision.*deny\|continue.*true" | sort | uniq -c

    echo ""

    # 统计工具类型
    echo "工具类型统计："
    grep "$(date -d "-$days days" '+%Y-%m-%d')" "$log_file" | grep "Processing" | awk '{print $5}' | sort | uniq -c

    echo ""

    # 统计时间分布
    echo "时间分布："
    grep "$(date -d "-$days days" '+%Y-%m-%d')" "$log_file" | awk '{print $1}' | sort | uniq -c

    echo ""

    # 统计错误
    echo "错误统计："
    grep "$(date -d "-$days days" '+%Y-%m-%d')" "$log_file" | grep -i "error\|fail" | wc -l
}

# 运行统计
analyze_claude_usage "$@"
```

## 🎯 总结

### 核心原则
1. **全局为主，项目为辅** - 大多数项目使用全局配置
2. **标准化优先** - 建立组织级的标准配置
3. **渐进式部署** - 从简单到复杂逐步实施
4. **持续监控** - 定期审查和优化配置

### 最佳实践清单
- [ ] 选择合适的全局安装方案
- [ ] 建立项目模板和标准化流程
- [ ] 创建环境切换和管理工具
- [ ] 设置监控和统计机制
- [ ] 建立备份和恢复流程
- [ ] 定期审查和更新配置
- [ ] 培训团队成员使用流程

### 快速检查清单
```bash
# 1. 检查安装
./setup.sh -c

# 2. 验证配置
./setup.sh -S

# 3. 测试功能
./setup.sh -t

# 4. 查看状态
tail -f /tmp/claude-approval.log
```

**记住：不需要每个项目都拷贝审批系统！** 使用全局配置 + 项目特定覆盖的策略，既简单又灵活。

---

*这套系统旨在让Claude Code的使用更加智能、安全、高效。选择合适的部署策略，享受自动化审批带来的便利吧！* 🚀✨

## 📚 相关文档
- [快速开始](QUICK-START.md) - 1分钟上手
- [详细教程](../../claude-code-auto-approval-tutorial.md) - 完整教程
- [脚本清单](SCRIPT-LIST.md) - 所有脚本说明
- [README](README.md) - 详细文档
- [测试工具](testing/) - 测试和调试工具