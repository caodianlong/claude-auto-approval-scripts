#!/bin/bash
# Claude Code CI/CD 环境审批脚本
# 功能：在 CI/CD 环境中完全自动化，但保留基本安全检查

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')
project_root=$(echo "$input" | jq -r '.context.project_root')

# CI/CD 环境日志
echo "[$(date)] CI/CD ENVIRONMENT - Processing $tool_name" >> /tmp/claude-cicd-approval.log

# CI/CD 环境中，我们只阻止真正危险的操作，其他全部自动批准
# 危险操作黑名单 - 这些在任何环境下都不应该执行

# 1. 系统级别的危险命令
if [[ "$tool_name" == "Bash" ]]; then
    command=$(echo "$tool_input" | jq -r '.command')

    # 绝对禁止的系统命令
    critical_dangerous="format|fdisk|mkfs|dd if=/dev/zero|rm -rf /|chmod 000|shutdown|reboot|halt"
    if [[ "$command" =~ $critical_dangerous ]]; then
        echo "[$(date)] CI/CD CRITICAL DANGER - Blocking system-level destructive command" >> /tmp/claude-cicd-approval.log
        echo '{"decision": "deny"}'
        exit 0
    fi

    # 禁止访问系统关键目录
    system_directories="/etc/passwd|/etc/shadow|/etc/sudoers|/proc|/sys|/dev"
    if [[ "$command" =~ $system_directories ]]; then
        echo "[$(date)] CI/CD SYSTEM PROTECTION - Blocking system directory access" >> /tmp/claude-cicd-approval.log
        echo '{"decision": "deny"}'
        exit 0
    fi

    # 禁止网络危险操作
    network_dangerous="curl.*sh|wget.*sh|nc -l|netcat -l|ssh.*\$"
    if [[ "$command" =~ $network_dangerous ]]; then
        echo "[$(date)] CI/CD NETWORK DANGER - Blocking dangerous network command" >> /tmp/claude-cicd-approval.log
        echo '{"decision": "deny"}'
        exit 0
    fi

    # 禁止权限提升
    if [[ "$command" =~ sudo ]] || [[ "$command" =~ su[[:space:]] ]]; then
        echo "[$(date)] CI/CD PRIVILEGE - Blocking privilege escalation" >> /tmp/claude-cicd-approval.log
        echo '{"decision": "deny"}'
        exit 0
    fi

    # 禁止文件系统破坏
    if [[ "$command" =~ rm.*-rf.*\/$ ]] || [[ "$command" =~ chmod.*000 ]]; then
        echo "[$(date)] CI/CD FILESYSTEM - Blocking filesystem destructive command" >> /tmp/claude-cicd-approval.log
        echo '{"decision": "deny"}'
        exit 0
    fi
fi

# 2. 文件操作安全检查
if [[ "$tool_name" == "Write" ]] || [[ "$tool_name" == "Edit" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')

    # 禁止写入系统关键目录
    if [[ "$file_path" =~ ^/etc/ ]] || [[ "$file_path" =~ ^/usr/bin ]] || [[ "$file_path" =~ ^/bin/ ]]; then
        echo "[$(date)] CI/CD SYSTEM FILE - Blocking system file modification" >> /tmp/claude-cicd-approval.log
        echo '{"decision": "deny"}'
        exit 0
    fi

    # 禁止覆盖重要的系统文件
    critical_files="passwd|shadow|sudoers|hosts|resolv.conf"
    if [[ "$file_path" =~ $critical_files ]]; then
        echo "[$(date)] CI/CD CRITICAL FILE - Blocking critical system file" >> /tmp/claude-cicd-approval.log
        echo '{"decision": "deny"}'
        exit 0
    fi
fi

# 3. Delete 操作安全检查
if [[ "$tool_name" == "Delete" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path')

    # 禁止删除系统目录
    if [[ "$file_path" =~ ^/etc/ ]] || [[ "$file_path" =~ ^/usr/ ]] || [[ "$file_path" =~ ^/bin/ ]] || [[ "$file_path" =~ ^/lib/ ]]; then
        echo "[$(date)] CI/CD SYSTEM DELETE - Blocking system directory deletion" >> /tmp/claude-cicd-approval.log
        echo '{"decision": "deny"}'
        exit 0
    fi

    # 禁止删除根目录
    if [[ "$file_path" == "/" ]] || [[ "$file_path" =~ ^/$ ]]; then
        echo "[$(date)] CI/CD ROOT DELETE - Blocking root directory deletion" >> /tmp/claude-cicd-approval.log
        echo '{"decision": "deny"}'
        exit 0
    fi
fi

# 4. Move/Copy 操作安全检查
if [[ "$tool_name" == "Move" ]] || [[ "$tool_name" == "Copy" ]]; then
    # 禁止向系统目录移动文件
    if [[ "$tool_input" =~ "to.*path.*\"[^\"]*/etc/" ]] || [[ "$tool_input" =~ "to.*path.*\"[^\"]*/usr/bin" ]]; then
        echo "[$(date)] CI/CD SYSTEM MOVE - Blocking system directory move/copy" >> /tmp/claude-cicd-approval.log
        echo '{"decision": "deny"}'
        exit 0
    fi
fi

# 5. 网络相关安全检查
if [[ "$tool_name" == "Bash" ]]; then
    command=$(echo "$tool_input" | jq -r '.command')

    # 禁止端口扫描
    if [[ "$command" =~ nmap ]] || [[ "$command" =~ masscan ]]; then
        echo "[$(date)] CI/CD PORT SCAN - Blocking port scanning" >> /tmp/claude-cicd-approval.log
        echo '{"decision": "deny"}'
        exit 0
    fi

    # 禁止网络监听
    if [[ "$command" =~ netcat.*-l ]] || [[ "$command" =~ nc.*-l ]] || [[ "$command" =~ socat.*-l ]]; then
        echo "[$(date)] CI/CD NETWORK LISTEN - Blocking network listening" >> /tmp/claude-cicd-approval.log
        echo '{"decision": "deny"}'
        exit 0
    fi
fi

# 6. 内存和 CPU 资源保护
if [[ "$tool_name" == "Bash" ]]; then
    command=$(echo "$tool_input" | jq -r '.command')

    # 禁止内存耗尽攻击
    memory_dangerous=":(){ :|: & };:|fork.*bomb"
    if [[ "$command" =~ $memory_dangerous ]]; then
        echo "[$(date)] CI/CD MEMORY BOMB - Blocking memory exhaustion attack" >> /tmp/claude-cicd-approval.log
        echo '{"decision": "deny"}'
        exit 0
    fi

    # 禁止 CPU 耗尽
    if [[ "$command" =~ yes.*\u003e ]] || [[ "$command" =~ cat.*\/dev\/zero.*\u003e ]]; then
        echo "[$(date)] CI/CD CPU EXHAUSTION - Blocking CPU exhaustion attack" >> /tmp/claude-cicd-approval.log
        echo '{"decision": "deny"}'
        exit 0
    fi
fi

# 如果通过所有安全检查，自动批准
echo "[$(date)] CI/CD AUTO APPROVED - $tool_name passed all safety checks" >> /tmp/claude-cicd-approval.log
echo '{"decision": "approve"}'

# CI/CD 环境配置建议：
# {
#   "environment": "cicd",
#   "auto_approve_all": true,
#   "safety_checks": {
#     "block_system_destruction": true,
#     "block_privilege_escalation": true,
#     "block_network_danger": true,
#     "block_resource_exhaustion": true,
#     "block_critical_files": true
#   },
#   "logging": {
#     "level": "verbose",
#     "file": "/tmp/claude-cicd-approval.log",
#     "max_size": "10MB",
#     "rotate": true
#   },
#   "monitoring": {
#     "alerts": {
#       "denied_operations": true,
#       "suspicious_patterns": true,
#       "emergency_contact": "security@company.com"
#     }
#   }
# }