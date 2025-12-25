# Contributing to Video Manager Ultimate

Thank you for your interest in contributing to Video Manager Ultimate! We welcome contributions from the community.

## 🎯 Ways to Contribute

- 🐛 Report bugs
- 💡 Suggest new features
- 📝 Improve documentation
- 🔧 Submit code improvements
- ✅ Add tests
- 🌍 Add translations

---

## 🚀 Getting Started

### Prerequisites

- Bash 4.0 or higher
- Git
- Basic understanding of shell scripting

### Development Setup

1. **Fork the repository**
   ```bash
   # Click "Fork" on GitHub
   ```

2. **Clone your fork**
   ```bash
   git clone https://github.com/YOUR_USERNAME/vmgr.git
   cd vmgr
   ```

3. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

4. **Make it executable**
   ```bash
   chmod +x video-manager-ultimate.sh
   chmod +x test-modules.sh
   chmod +x lib/*.sh
   ```

---

## 🏗️ Project Structure

```
vmgr/
├── video-manager-ultimate.sh   # Main entry point (465 lines)
├── lib/                         # Modular architecture
│   ├── core.sh                  # Core initialization
│   ├── platform.sh              # Cross-platform compatibility
│   ├── logging.sh               # Logging system
│   ├── config.sh                # Configuration
│   ├── utils.sh                 # Utilities
│   ├── file-ops.sh              # File operations
│   ├── duplicates.sh            # Duplicate detection
│   ├── organize.sh              # Organization & undo
│   ├── subtitles.sh             # Whisper AI integration
│   ├── catalog.sh               # Multi-drive catalog
│   ├── batch.sh                 # Batch processing
│   └── ui.sh                    # Interactive menus
├── test-modules.sh              # Test suite (26 tests)
├── vmgr-completion.bash         # Tab completion
└── docs/                        # Documentation
```

---

## 🧪 Testing

### Run All Tests

```bash
./test-modules.sh
```

All 26 tests must pass before submitting a PR.

### Test Individual Features

```bash
# Test version
./video-manager-ultimate.sh --version

# Test help
./video-manager-ultimate.sh --help

# Test dry-run mode
./video-manager-ultimate.sh --dry-run rename /path/to/test

# Test interactive menu
./video-manager-ultimate.sh
```

### Add New Tests

If you add new functionality, add corresponding tests to `test-modules.sh`.

---

## 📝 Code Style

### Shell Script Best Practices

- Use `#!/bin/bash` shebang
- Follow Google Shell Style Guide
- Use meaningful variable names
- Add comments for complex logic
- Use `readonly` for constants
- Quote all variables: `"$var"`
- Use `[[` instead of `[` for conditionals
- Check exit codes: `if [[ $? -ne 0 ]]; then`

### Example

```bash
# Good
readonly LOG_DIR="$HOME/.video-manager-logs"

validate_directory() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        log_error "Directory not found: $dir"
        return 1
    fi

    return 0
}

# Bad
LOG_DIR=$HOME/.video-manager-logs  # Not readonly

validate_directory() {
    if [ ! -d $1 ]; then  # Unquoted, old test syntax
        echo "Error"
        return 1
    fi
}
```

### Module Guidelines

If modifying or adding modules:

1. **One module = One responsibility**
2. **Document dependencies** in module header
3. **Add to test suite**
4. **Update MODULARIZATION-PROGRESS.md** if needed

---

## 🔀 Submitting Changes

### Commit Messages

Follow conventional commits format:

```
<type>: <description>

[optional body]

[optional footer]
```

**Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `style:` - Code style changes (formatting)
- `refactor:` - Code refactoring
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks

**Examples:**
```
feat: Add video transcoding support

Implements video transcoding using ffmpeg with configurable
quality presets and format conversion.

Closes #42
```

```
fix: Handle spaces in filenames correctly

Previously, filenames with spaces caused the rename operation
to fail. Added proper quoting to fix the issue.

Fixes #38
```

### Pull Request Process

1. **Update your branch**
   ```bash
   git fetch origin
   git rebase origin/master
   ```

2. **Run tests**
   ```bash
   ./test-modules.sh
   ```

3. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: Add awesome feature"
   ```

4. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

5. **Create Pull Request**
   - Go to the original repository
   - Click "New Pull Request"
   - Select your fork and branch
   - Fill in the PR template
   - Link related issues

6. **Wait for review**
   - CI/CD will run automatically
   - Address any review comments
   - Keep the PR updated

### PR Checklist

- [ ] Tests pass (`./test-modules.sh`)
- [ ] Code follows style guidelines
- [ ] Documentation updated (if needed)
- [ ] Commit messages are clear
- [ ] No unnecessary files included
- [ ] Branch is up to date with master

---

## 🐛 Reporting Bugs

Use the bug report template and include:

- Video Manager version (`./video-manager-ultimate.sh --version`)
- Operating system and version
- Steps to reproduce
- Expected behavior
- Actual behavior
- Error messages or logs
- Screenshots (if applicable)

---

## 💡 Suggesting Features

Use the feature request template and include:

- Clear description of the feature
- Use case / motivation
- How it should work
- Alternative solutions considered
- Willing to implement it yourself?

---

## 📜 Code of Conduct

### Our Standards

- Be respectful and inclusive
- Welcome newcomers
- Accept constructive criticism
- Focus on what's best for the project
- Show empathy towards others

### Unacceptable Behavior

- Harassment or discriminatory language
- Trolling or insulting comments
- Public or private harassment
- Publishing others' private information
- Other unprofessional conduct

---

## 🏆 Recognition

Contributors will be:
- Listed in release notes
- Mentioned in CHANGELOG.md
- Credited in commit messages (Co-Authored-By)

---

## 📞 Questions?

- Open a discussion on GitHub
- Check existing issues
- Read the documentation

---

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

**Thank you for contributing to Video Manager Ultimate!** 🎉
