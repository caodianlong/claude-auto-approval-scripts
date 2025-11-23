# Claude Code 自动审批系统入门教程

## 概述

Claude Code 提供了一个强大的自动审批系统，通过钩子（Hook）机制在工具执行前进行智能决策。相比传统的 "yolo 模式"，这种设计更加安全、灵活和智能化。

## 核心概念

### 1. 什么是 PreToolUse 钩子

`PreToolUse` 是 Claude Code 在工具执行前触发的事件，允许我们拦截并决定是否自动批准该操作。

### 2. 系统架构

```
用户请求 → Claude Code → PreToolUse 钩子 → 审批脚本 → 决策（批准/拒绝/确认）
```

### 3. 与传统 yolo 模式的区别

| 特性 | 传统 yolo 模式 | Claude Code 自动审批 |
|------|---------------|---------------------|
| 控制粒度 | 全部自动批准 | 可针对具体工具、路径、命令 |
| 安全性 | 低 | 高（可阻止危险操作） |
| 灵活性 | 固定模式 | 完全可编程 |
| 上下文感知 | 无 | 支持项目、用户、时间等 |

## 基础配置

### 1. 最简单的自动审批配置

创建文件 `.claude/settings.json`：

```json
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit|Bash",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/auto-approve.sh"
        }
      ]
    }
  ]
}
```

### 2. 基础审批脚本

创建文件 `scripts/auto-approve.sh`：

```bash
#!/bin/bash
# 基础安全审批逻辑

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')

# 自动批准安全的只读操作
safe_readonly_tools="ls pwd echo cat grep find which"
if [[ "$safe_readonly_tools" =~ "$tool_name" ]]; then
    echo '{"decision": "approve"}'
    exit 0
fi

# Write 操作 - 基于文件路径判断
if [[ "$tool_name" == "Write" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')

    # 自动批准临时文件
    if [[ "$file_path" =~ ^/tmp/ ]] || [[ "$file_path" =~ \.tmp$ ]]; then
        echo '{"decision": "approve"}'
        exit 0
    fi
fi

# Bash 命令 - 基于命令内容判断
if [[ "$tool_name" == "Bash" ]]; then
    command=$(echo "$tool_input" | jq -r '.command')

    # 拒绝危险命令
    dangerous_patterns="rm -rf|chmod 777|curl.*sh|wget.*sh"
    if [[ "$command" =~ $dangerous_patterns ]]; then
        echo '{"decision": "deny"}'
        exit 0
    fi
fi

# 默认继续（弹出确认对话框）
echo '{"continue": true}'
```

## 进阶配置

### 1. 智能上下文感知审批

```bash
#!/bin/bash
# smart-approve.sh - 智能上下文感知审批

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')
project_root=$(echo "$input" | jq -r '.context.project_root')

# 基于 Git 状态进行智能审批
is_git_repo() {
    git -C "$project_root" rev-parse --git-dir >/dev/null 2>&1
}

# Write 操作的智能审批
if [[ "$tool_name" == "Write" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')

    # 如果文件已被 Git 跟踪，更加谨慎
    if is_git_repo && git -C "$project_root" ls-files --error-unmatch "$file_path" >/dev/null 2>&1; then
        echo '{"continue": true}'  # 已跟踪文件需要确认
        exit 0
    fi

    # 新文件基于扩展名判断
    case "$file_path" in
        *.tmp|*.temp|*.log|*.cache)
            echo '{"decision": "approve"}'
            exit 0
            ;;
        *.js|*.py|*.java|*.cpp)
            echo '{"continue": true}'  # 源代码文件需要确认
            exit 0
            ;;
    esac
fi

# 基于项目类型的审批策略
if [[ -f "$project_root/package.json" ]]; then
    # Node.js 项目
    if [[ "$tool_name" == "Bash" ]]; then
        command=$(echo "$tool_input" | jq -r '.command')
        if [[ "$command" =~ ^npm ]] && [[ ! "$command" =~ "npm audit" ]]; then
            echo '{"decision": "approve"}'
            exit 0
        fi
    fi
fi

echo '{"continue": true}'
```

### 2. 分层审批策略

```bash
#!/bin/bash
# tiered-approval.sh - 分层审批

calculate_risk_level() {
    local input="$1"
    local tool_name=$(echo "$input" | jq -r '.tool_name')
    local tool_input=$(echo "$input" | jq -r '.tool_input')

    # 风险评分逻辑
    local risk_score=0

    # 基于工具类型评分
    case "$tool_name" in
        "Write") risk_score=$((risk_score + 1)) ;;
        "Edit") risk_score=$((risk_score + 2)) ;;
        "Bash") risk_score=$((risk_score + 3)) ;;
        "Delete") risk_score=$((risk_score + 4)) ;;
    esac

    # 基于输入内容评分
    if [[ "$tool_input" =~ /etc/|/usr/|/bin/ ]]; then
        risk_score=$((risk_score + 5))  # 系统目录高风险
    fi

    if [[ $risk_score -le 2 ]]; then
        echo "low"
    elif [[ $risk_score -le 5 ]]; then
        echo "medium"
    else
        echo "high"
    fi
}

input=$(cat)
risk_level=$(calculate_risk_level "$input")

case "$risk_level" in
    "low")
        echo '{"decision": "approve"}'
        ;;
    "medium")
        echo '{"continue": true}'  # 需要确认
        ;;
    "high")
        echo '{"decision": "deny"}'
        ;;
esac
```

## 环境特定的配置策略

### 1. 开发环境配置

`.claude/settings.json`：

```json
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/dev-approve.sh"
        }
      ]
    },
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "command",
          "command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/safe-bash.sh"
        }
      ]
    }
  ]
}
```

### 2. 生产环境配置（更严格）

```json
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit|Bash",
      "hooks": [
        {
          "type": "prompt",
          "prompt": "Production environment: Review this $TOOL_NAME operation carefully. Only approve if it's a safe, read-only operation or critical maintenance task."
        }
      ]
    }
  ]
}
```

### 3. CI/CD 环境配置（完全自动）

```json
{
  "PreToolUse": [
    {
      "matcher": "*",
      "hooks": [
        {
          "type": "command",
          "command": "echo '{\"decision\": \"approve\"}'"
        }
      ]
    }
  ]
}
```

## 高级技巧和最佳实践

### 1. 时间窗口审批

```bash
#!/bin/bash
# 只允许在工作时间自动审批
current_hour=$(date +%H)
if [[ $current_hour -ge 9 && $current_hour -le 18 ]]; then
    echo '{"decision": "approve"}'
else
    echo '{"continue": true}'  # 非工作时间需要确认
fi
```

### 2. 用户身份感知

```bash
#!/bin/bash
# 基于用户身份的审批
current_user=$(whoami)
if [[ "$current_user" == "developer" ]]; then
    echo '{"decision": "approve"}'  # 开发用户自动批准
else
    echo '{"continue": true}'        # 其他用户需要确认
fi
```

### 3. 项目配置感知

```bash
#!/bin/bash
# 读取项目特定的审批配置
project_root=$(echo "$input" | jq -r '.context.project_root')
config_file="$project_root/.claude-auto-approve.json"

if [[ -f "$config_file" ]]; then
    # 检查是否在自动批准名单中
    if jq -e ".auto_approve_tools[] | select(. == \"$tool_name\")" "$config_file" >/dev/null; then
        echo '{"decision": "approve"}'
        exit 0
    fi

    # 检查是否在拒绝名单中
    if jq -e ".deny_tools[] | select(. == \"$tool_name\")" "$config_file" >/dev/null; then
        echo '{"decision": "deny"}'
        exit 0
    fi
fi
```

## 配置示例文件

### 项目特定的审批配置 (.claude-auto-approve.json)

```json
{
  "auto_approve_tools": ["ls", "pwd", "echo", "cat", "npm install"],
  "deny_tools": ["rm", "chmod", "curl", "wget"],
  "auto_approve_paths": ["/tmp/*", "*.log", "/build/*"],
  "deny_paths": ["/etc/*", "/usr/*", "*.key", "*.pem"],
  "time_restrictions": {
    "auto_approve_hours": "9-18",
    "weekend_mode": "confirm_all"
  }
}
```

## 调试和测试

### 1. 测试审批脚本

```bash
#!/bin/bash
# 测试审批脚本

# 模拟输入数据
test_input='{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/tmp/test.txt",
    "content": "test content"
  },
  "context": {
    "project_root": "/home/user/project"
  }
}'

# 运行审批脚本测试
echo "$test_input" | bash scripts/auto-approve.sh
```

### 2. 日志记录

```bash
#!/bin/bash
# 带日志记录的审批脚本

log_file="/tmp/claude-approval.log"
input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')

echo "[$(date)] Processing $tool_name request" >> "$log_file"

# 审批逻辑...
decision='{"decision": "approve"}'

echo "[$(date)] Decision for $tool_name: $decision" >> "$log_file"
echo "$decision"
```

## 常见问题和解决方案

### 1. 审批脚本没有执行

- 检查脚本是否有执行权限：`chmod +x scripts/auto-approve.sh`
- 检查配置文件语法是否正确
- 检查脚本路径是否正确

### 2. 审批决策不生效

- 确保输出格式正确：JSON 格式，包含 `decision` 或 `continue` 字段
- 检查是否有语法错误：使用 `bash -n script.sh` 检查
- 查看日志了解具体执行过程

### 3. 性能问题

- 避免在审批脚本中执行耗时操作
- 使用缓存机制存储频繁查询的数据
- 简化审批逻辑，避免复杂的嵌套判断

## 总结

Claude Code 的自动审批系统提供了：

1. **精细化控制** - 可以针对不同的工具、路径、命令设置不同策略
2. **上下文感知** - 能够获取项目信息、Git 状态、用户身份等上下文
3. **安全可控** - 即使设置了自动审批，仍然可以阻止危险操作
4. **灵活配置** - 支持命令、提示、脚本等多种决策方式
5. **审计追踪** - 所有决策都会被记录在会话历史中

这种设计将 "自动审批" 提升为 "智能审批"，既提高了效率，又保持了安全性。通过合理配置，您可以在开发效率和安全控制之间找到最佳平衡点。

## 相关资源

- Claude Code 官方文档
- 示例脚本仓库
- 社区配置分享
- 最佳实践指南

---

*本教程持续更新，欢迎您分享使用经验和改进建议。*