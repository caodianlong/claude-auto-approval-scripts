# Claude Code Auto-Approval Scripts Collection

A comprehensive collection of Claude Code auto-approval scripts, featuring multiple approval strategies and tools for both Linux and Windows environments.

**[中文版本](README.md)** | English Version

## 📁 Directory Structure

```
claude-auto-approval-scripts/
├── basic/                          # Basic approval scripts
│   ├── auto-approve-basic.sh       # Basic security approval (Linux)
├── smart/                          # Intelligent context-aware scripts
│   └── smart-context-approve.sh    # Smart context approval (Linux)
├── tiered/                         # Tiered approval strategies
│   └── tiered-approval.sh          # Risk-based tiered approval
├── environment-specific/           # Environment-specific configurations
│   ├── dev-environment-approve.sh  # Development environment approval
│   ├── prod-environment-approve.sh # Production environment approval
│   └── cicd-environment-approve.sh # CI/CD environment approval
├── advanced/                       # Advanced functionality scripts
│   ├── time-window-approve.sh      # Time window approval
│   ├── user-identity-approve.sh    # User identity-aware approval
│   └── combined-intelligent-approve.sh # Combined intelligent approval
├── testing/                        # Testing and debugging tools
│   ├── test-approval-scripts.sh    # Automated testing tools
│   └── debug-approval-script.sh    # Debugging tools
└── windows-versions/               # Windows versions
    ├── auto-approve-basic.bat      # Basic approval (Windows)
    └── smart-context-approve.bat   # Smart approval (Windows)
```

## 🚀 Quick Start

### 🆕 Unified Setup Tool (Highly Recommended)

Use the new unified setup tool for one-click configuration:

```bash
# Interactive setup (recommended for beginners)
./setup-v2.sh

# Quick deployment for user-level smart approval (recommended for personal use)
./setup-v2.sh -q -e smart -m user

# Project-level development environment (recommended for new projects)
./setup-v2.sh -e dev -m project -p ~/my-project

# Global auto-detection mode (recommended for servers)
./setup-v2.sh -e auto -m global
```

### 📋 Setup Tool Features

**setup-v2.sh provides:**
- 🧠 **Smart project detection** - Automatically identify project types (Node.js, Python, Java, etc.)
- 🎯 **Environment recommendations** - Intelligently recommend appropriate approval strategies based on project type
- 🔧 **Multiple installation methods** - Supports global, user-level, and project-level installation
- ⚡ **Quick mode** - One-click deployment via command line
- 📊 **Status management** - View current configuration status anytime

**📖 Detailed Guide**: [New Setup Tool Complete Guide](NEW-SETUP-GUIDE.md)

### 2. Traditional Manual Configuration (Alternative)

If you prefer manual configuration, select an approval script that suits your needs and reference it in Claude Code's configuration file:

```json
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit|Bash",
      "hooks": [
        {
          "type": "command",
          "command": "bash /path/to/claude-auto-approval-scripts/basic/auto-approve-basic.sh"
        }
      ]
    }
  ]
}
```

### 2. Select Scripts Based on Environment

- **Development environment**: Use `dev-environment-approve.sh`
- **Production environment**: Use `prod-environment-approve.sh`
- **CI/CD environment**: Use `cicd-environment-approve.sh`
- **General scenarios**: Use `combined-intelligent-approve.sh`

### 3. For Windows Users

Windows users should use `.bat` scripts in the `windows-versions/` directory.

## 📋 Script Functionality

### Basic Scripts (basic/)

- **auto-approve-basic.sh**: Provides basic security approval functionality
  - Automatically approves safe read-only operations
  - Intelligent approval based on file paths
  - Dangerous command detection and rejection

### Smart Scripts (smart/)

- **smart-context-approve.sh**: Context-aware intelligent approval
  - Project type recognition (Node.js, Python, Java, etc.)
  - Git status awareness
  - Intelligent file type judgment

### Tiered Approval (tiered/)

- **tiered-approval.sh**: Risk-based tiered approval
  - Multi-dimensional risk assessment
  - Low/Medium/High risk classification
  - Special rules override mechanism

### Environment-Specific (environment-specific/)

- **dev-environment-approve.sh**: For development environments
  - Relatively relaxed approval policies
  - Support for development tools and commands
  - Allow temporary file operations

- **prod-environment-approve.sh**: For production environments
  - Extremely strict security controls
  - Only allow safest operations
  - Detailed audit logs

- **cicd-environment-approve.sh**: For CI/CD environments
  - Automation-first approach
  - Basic security checks
  - Performance optimization

### Advanced Features (advanced/)

- **time-window-approve.sh**: Time window approval
  - Business hours/non-business hours strategies
  - Weekend/holiday special handling
  - Maintenance time windows

- **user-identity-approve.sh**: User identity awareness
  - Permission-based approval
  - User group identification
  - Project ownership checks

- **combined-intelligent-approve.sh**: Combined intelligent approval
  - Multi-factor comprehensive scoring
  - Machine learning integration interface
  - Context-enhanced decision making

## 🧪 Testing Tools

### Automated Testing

```bash
cd testing/
./test-approval-scripts.sh
```

Features:
- Automated functional testing
- Performance benchmarks
- Detailed test reports

### Debugging Tools

```bash
cd testing/
./debug-approval-script.sh -d 3 -s -v ../basic/auto-approve-basic.sh '{"tool_name": "ls", "tool_input": {"path": "/tmp"}}'
```

Features:
- Step-by-step execution debugging
- Variable value display
- Performance profiling
- Output validation

## ⚙️ Configuration Options

### Basic Configuration

Create `.claude/settings.json`:

```json
{
  "PreToolUse": [
    {
      "matcher": "Write|Edit",
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

### Advanced Configuration

Create project-specific configuration files:

```json
// .claude-intelligent-config.json
{
  "approval_thresholds": {
    "high_trust": 80,
    "medium_trust": 60,
    "low_trust": 40
  },
  "time_restrictions": {
    "business_hours": {"start": 9, "end": 18},
    "weekend_mode": "strict"
  },
  "user_permissions": {
    "admin_users": ["john", "jane"],
    "developer_groups": ["engineering", "dev"]
  }
}
```

## 🔧 Custom Development

### Creating Custom Approval Scripts

1. Create new script based on template
2. Implement approval logic
3. Add test cases
4. Integrate into configuration file

### Script Template

```bash
#!/bin/bash
# Custom approval script template

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name')
tool_input=$(echo "$input" | jq -r '.tool_input')
project_root=$(echo "$input" | jq -r '.context.project_root')

# Your approval logic
if [[ "$tool_name" == "YourCondition" ]]; then
    echo '{"decision": "approve"}'
else
    echo '{"continue": true}'
fi
```

## 📊 Performance Optimization

### Performance Benchmarks

- Basic scripts: ~0.01-0.05s
- Smart scripts: ~0.05-0.1s
- Complex combined scripts: ~0.1-0.3s

### Optimization Recommendations

1. **Reduce external command calls**
2. **Use caching mechanisms**
3. **Simplify condition judgments**
4. **Avoid repeated calculations**

## 🛡️ Security Considerations

### Security Checklist

- [ ] Dangerous command filtering
- [ ] System directory protection
- [ ] Privilege escalation detection
- [ ] Network operation security
- [ ] Resource exhaustion protection

### Best Practices

1. **Principle of least privilege**
2. **Layered security control**
3. **Detailed audit logs**
4. **Regular security reviews**

## 🔍 Troubleshooting

### Common Issues

1. **Script lacks execute permission**
   ```bash
   chmod +x script-name.sh
   ```

2. **Missing dependencies**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install jq bc

   # CentOS/RHEL
   sudo yum install jq bc

   # macOS
   brew install jq bc
   ```

3. **JSON parsing errors**
   - Check input JSON format
   - Verify jq command availability
   - View debug logs

### Debugging Steps

1. Use debugging tools to check input/output
2. View detailed log files
3. Step-by-step script execution analysis
4. Verify configuration file format

## 📚 Related Resources

- [Claude Code Official Documentation](https://claude.ai/docs)
- [Example Configuration Files](./examples/)
- [Best Practices Guide](./docs/best-practices.md)
- [Security Guide](./docs/security.md)

## 🤝 Contributing Guidelines

Contributions and Pull Requests are welcome!

### Submission Guidelines

1. Clear commit messages
2. Complete test cases
3. Updated documentation
4. Security review passed

## 📄 License

MIT License - See [LICENSE](LICENSE) file for details

## 📝 Changelog

### v1.0.0 (2024-01-XX)
- Initial version release
- Includes basic approval scripts
- Supports intelligent context awareness
- Provides complete testing tools

---

**Note**: Before using these scripts, please ensure you understand their security implications and configure and test them appropriately according to your specific needs. For production environments, testing in a small scope before gradual rollout is recommended.

For questions or suggestions, please submit feedback via GitHub Issues!

## 🎯 Next Steps

- [ ] Add more Windows version scripts
- [ ] Integrate machine learning models
- [ ] Support more programming languages
- [ ] Cloud configuration synchronization
- [ ] Real-time monitoring dashboard
- [ ] Automated rule generation

**Happy coding with Claude Code!** 🚀
