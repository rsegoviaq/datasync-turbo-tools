# Contributing to DataSync Turbo Tools

> Thank you for your interest in contributing! This guide will help you get started.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing Guidelines](#testing-guidelines)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)
- [Issue Guidelines](#issue-guidelines)

---

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive experience for everyone.

### Our Standards

**Positive behavior includes**:
- Using welcoming and inclusive language
- Being respectful of differing viewpoints
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

**Unacceptable behavior includes**:
- Trolling, insulting/derogatory comments, and personal attacks
- Public or private harassment
- Publishing others' private information without permission
- Other conduct which could reasonably be considered inappropriate

---

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- [x] Linux, macOS, or WSL2 environment
- [x] Bash 4.0+ installed
- [x] AWS CLI installed and configured
- [x] Git installed
- [x] Text editor or IDE
- [x] Access to S3 bucket for testing

### Setting Up Development Environment

1. **Fork the repository**
   ```bash
   # On GitHub: Click "Fork" button
   ```

2. **Clone your fork**
   ```bash
   git clone https://github.com/YOUR_USERNAME/datasync-turbo-tools
   cd datasync-turbo-tools
   ```

3. **Add upstream remote**
   ```bash
   git remote add upstream https://github.com/original/datasync-turbo-tools
   ```

4. **Install s5cmd**
   ```bash
   ./tools/install-s5cmd.sh
   ```

5. **Create test configuration**
   ```bash
   cd examples/basic
   cp config.env.template config.env
   nano config.env  # Edit with your test bucket settings
   ```

6. **Verify setup**
   ```bash
   ./tools/verify-installation.sh
   ```

---

## How to Contribute

### Types of Contributions

We welcome many types of contributions:

#### 🐛 Bug Reports
- Report bugs via GitHub Issues
- Include detailed reproduction steps
- Provide system information
- Include relevant logs

#### ✨ Feature Requests
- Describe the feature clearly
- Explain the use case
- Consider backward compatibility
- Propose implementation approach

#### 📝 Documentation
- Fix typos or unclear sections
- Add examples
- Improve guides
- Translate documentation

#### 🔧 Code Contributions
- Bug fixes
- New features
- Performance improvements
- Refactoring

#### 🧪 Testing
- Add test cases
- Improve test coverage
- Report test failures
- Performance benchmarking

---

## Development Workflow

### Branch Strategy

```
master (or main)
  ├── feature/feature-name      # New features
  ├── bugfix/bug-description     # Bug fixes
  ├── hotfix/critical-fix        # Critical production fixes
  ├── docs/documentation-update  # Documentation changes
  └── release/v1.1.0            # Release preparation
```

### Creating a Branch

```bash
# Update master
git checkout master
git pull upstream master

# Create feature branch
git checkout -b feature/my-new-feature

# Or bug fix branch
git checkout -b bugfix/fix-throughput-calculation
```

### Making Changes

1. **Make your changes**
   - Edit relevant files
   - Follow coding standards
   - Add tests if applicable

2. **Test your changes**
   ```bash
   # Dry-run test
   source config.env
   ./scripts/datasync-s5cmd.sh --dry-run

   # Actual upload test (small dataset)
   ./scripts/datasync-s5cmd.sh

   # Verify logs
   cat logs/*.json | jq .
   ```

3. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add new feature description"
   ```

### Commit Message Format

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Build process or auxiliary tool changes

**Examples**:

```bash
# Feature
git commit -m "feat(upload): add multi-region support"

# Bug fix
git commit -m "fix(logging): correct throughput calculation in JSON output"

# Documentation
git commit -m "docs(readme): add troubleshooting section"

# Breaking change
git commit -m "feat(config): change configuration file format

BREAKING CHANGE: Configuration now uses YAML instead of .env files.
See MIGRATION.md for upgrade instructions."
```

### Pushing Changes

```bash
# Push to your fork
git push origin feature/my-new-feature
```

---

## Coding Standards

### Bash Script Style

#### 1. Script Header

```bash
#!/bin/bash
#
# Script Name - Brief Description
# Version: 1.0.0
#
# Detailed description of what the script does
#

set -euo pipefail  # Exit on error, undefined vars, pipe failures
```

#### 2. Variables

```bash
# Environment variables (UPPERCASE)
AWS_PROFILE="${AWS_PROFILE:-default}"
BUCKET_NAME="${BUCKET_NAME}"

# Local variables (lowercase)
local file_count=0
local source_dir="/path/to/data"

# Constants (readonly UPPERCASE)
readonly VERSION="1.0.0"
readonly MAX_RETRIES=5
```

#### 3. Functions

```bash
# Function with documentation
# Args:
#   $1 - Source directory path
#   $2 - Destination S3 path
# Returns:
#   0 - Success
#   1 - Failure
upload_to_s3() {
    local source_dir="$1"
    local dest_path="$2"

    # Validate inputs
    if [ -z "$source_dir" ]; then
        log_error "Source directory is required"
        return 1
    fi

    # Function logic
    log_info "Uploading $source_dir to $dest_path"

    return 0
}
```

#### 4. Error Handling

```bash
# Check command success
if ! command_that_might_fail; then
    log_error "Command failed"
    return 1
fi

# Alternative syntax
command_that_might_fail || {
    log_error "Command failed"
    return 1
}

# Trap for cleanup
cleanup() {
    log_info "Cleaning up..."
    rm -f "$temp_file"
}
trap cleanup EXIT
```

#### 5. Quoting

```bash
# Always quote variables
source_dir="$SOURCE_DIR"
file_path="$1"

# Use double quotes for variables, single for literals
log_info "Processing file: $file_path"
log_error 'Fatal error occurred'

# Quote arrays
files=("file1.txt" "file2.txt" "file with spaces.txt")
for file in "${files[@]}"; do
    echo "$file"
done
```

#### 6. Conditionals

```bash
# Use [[ ]] instead of [ ]
if [[ "$status" == "success" ]]; then
    log_success "Upload completed"
fi

# Check file existence
if [[ -f "$file_path" ]]; then
    log_info "File exists"
fi

# Check directory
if [[ -d "$directory" ]]; then
    log_info "Directory exists"
fi

# Check if variable is set
if [[ -n "$variable" ]]; then
    log_info "Variable is set"
fi
```

#### 7. Logging

```bash
# Use appropriate log levels
log_info "Informational message"
log_success "Operation completed successfully"
log_warning "Warning message"
log_error "Error message"

# For functions that return values, redirect logs to stderr
calculate_size() {
    log_info "Calculating size..." >&2
    echo "$size_value"  # Return value to stdout
}
```

### Code Quality Checklist

Before submitting code, verify:

- [ ] Script has proper shebang (`#!/bin/bash`)
- [ ] Script uses `set -euo pipefail`
- [ ] All variables are quoted
- [ ] Functions have documentation
- [ ] Error handling is implemented
- [ ] Logs use appropriate levels
- [ ] No hardcoded credentials or paths
- [ ] Permissions are correct (755 for scripts)
- [ ] Code is readable and well-commented
- [ ] No shellcheck warnings

### Running ShellCheck

```bash
# Install shellcheck
sudo apt-get install shellcheck  # Ubuntu/Debian
brew install shellcheck           # macOS

# Check script
shellcheck scripts/datasync-s5cmd.sh

# Check all scripts
find . -name "*.sh" -exec shellcheck {} \;
```

---

## Testing Guidelines

### Test Types

#### 1. Unit Testing (Manual)

Test individual functions in isolation:

```bash
# Test helper function
source scripts/datasync-s5cmd.sh
calculate_source_size "/path/to/test/data"
```

#### 2. Integration Testing

Test complete upload workflow:

```bash
# Dry-run test
source config.env
./scripts/datasync-s5cmd.sh --dry-run

# Small dataset test (< 1 GB)
SOURCE_DIR="/path/to/small/dataset"
./scripts/datasync-s5cmd.sh

# Large dataset test (> 10 GB)
SOURCE_DIR="/path/to/large/dataset"
./scripts/datasync-s5cmd.sh
```

#### 3. Performance Testing

```bash
# Benchmark test
./tools/benchmark.sh 5000  # 5 GB test

# Throughput validation
cat logs/*.json | jq '.throughput_mbps'
```

#### 4. Error Scenario Testing

```bash
# Invalid credentials
export AWS_PROFILE="nonexistent"
./scripts/datasync-s5cmd.sh  # Should fail gracefully

# Missing source directory
export SOURCE_DIR="/nonexistent/path"
./scripts/datasync-s5cmd.sh  # Should fail with clear error

# Network timeout simulation
# (requires network manipulation tools)
```

### Testing Checklist

Before submitting changes, test:

- [ ] Script runs with `--dry-run`
- [ ] Script runs with actual upload (test data)
- [ ] Logs are generated correctly
- [ ] JSON logs are valid (`jq` can parse)
- [ ] Throughput is calculated accurately
- [ ] Error messages are clear
- [ ] Script handles missing dependencies
- [ ] Script handles invalid configuration
- [ ] Performance meets expectations
- [ ] No regression in existing functionality

### Test Data Recommendations

**Small Test** (Quick validation):
- Size: 100-500 MB
- Files: 10-50 files
- Purpose: Functional testing

**Medium Test** (Performance validation):
- Size: 5-10 GB
- Files: 100-500 files
- Purpose: Performance baseline

**Large Test** (Stress testing):
- Size: 50-100 GB
- Files: 1000+ files
- Purpose: Production simulation

---

## Documentation

### Documentation Requirements

When contributing code, update relevant documentation:

#### Code Changes
- [ ] Update relevant README files
- [ ] Add/update inline comments
- [ ] Update configuration examples
- [ ] Update troubleshooting guide if needed

#### New Features
- [ ] Document in README.md
- [ ] Add usage examples
- [ ] Update configuration guide
- [ ] Add to CHANGELOG.md

#### Bug Fixes
- [ ] Add to CHANGELOG.md
- [ ] Update troubleshooting guide if relevant
- [ ] Document workarounds

### Documentation Style

#### Markdown Guidelines

```markdown
# Top-Level Heading (H1)

## Section Heading (H2)

### Subsection Heading (H3)

**Bold for emphasis**
*Italic for subtle emphasis*
`code inline`

```bash
# Code blocks with language
command --flag value
```

- Bullet list item 1
- Bullet list item 2

1. Numbered list item 1
2. Numbered list item 2

> Blockquote for important notes

[Link text](URL)
```

#### Code Examples

- Include complete, runnable examples
- Add comments explaining non-obvious parts
- Show expected output
- Include error handling examples

**Good Example**:
```bash
# Configure AWS profile and bucket
export AWS_PROFILE="production"
export BUCKET_NAME="my-prod-bucket"
export SOURCE_DIR="/data/uploads"

# Run upload with error handling
if ./scripts/datasync-s5cmd.sh; then
    echo "Upload successful"
else
    echo "Upload failed, check logs"
    exit 1
fi

# Expected output:
# [INFO] Upload started...
# [SUCCESS] Upload completed: 2.5 GB in 180s (14.2 MB/s)
```

---

## Pull Request Process

### Creating a Pull Request

1. **Ensure branch is up to date**
   ```bash
   git checkout master
   git pull upstream master
   git checkout feature/my-feature
   git rebase master
   ```

2. **Push to your fork**
   ```bash
   git push origin feature/my-feature
   ```

3. **Create pull request on GitHub**
   - Click "New Pull Request"
   - Select your fork and branch
   - Fill out the PR template

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Tested with dry-run
- [ ] Tested with actual upload
- [ ] Logs validated
- [ ] Performance benchmarked

## Related Issues
Closes #123

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings generated
- [ ] Tests added/updated
- [ ] CHANGELOG.md updated
```

### Review Process

1. **Automated Checks** (if configured)
   - ShellCheck validation
   - Syntax checking
   - Link validation

2. **Code Review**
   - Maintainers review changes
   - Feedback provided via comments
   - Revisions requested if needed

3. **Testing**
   - Changes tested by reviewers
   - Performance validated
   - Integration tested

4. **Approval and Merge**
   - Approved by maintainer(s)
   - Merged to master
   - Branch deleted

### Addressing Feedback

```bash
# Make requested changes
nano scripts/datasync-s5cmd.sh

# Commit changes
git add .
git commit -m "fix: address review feedback"

# Push updates
git push origin feature/my-feature
```

---

## Issue Guidelines

### Creating an Issue

#### Bug Report Template

```markdown
**Bug Description**
Clear description of the bug

**To Reproduce**
Steps to reproduce:
1. Configure with settings...
2. Run command...
3. See error

**Expected Behavior**
What should happen

**Actual Behavior**
What actually happens

**Environment**
- OS: Ubuntu 22.04
- Bash: 5.1.16
- s5cmd: v2.3.0
- AWS CLI: 2.13.0

**Configuration**
```bash
export AWS_PROFILE="test"
export BUCKET_NAME="test-bucket"
# ... relevant config
```

**Logs**
```
[Relevant log output]
```

**Additional Context**
Any other relevant information
```

#### Feature Request Template

```markdown
**Feature Description**
Clear description of the proposed feature

**Use Case**
Why is this feature needed?

**Proposed Solution**
How might this be implemented?

**Alternatives Considered**
Other approaches considered

**Additional Context**
Mockups, examples, etc.
```

### Issue Labels

- `bug` - Something isn't working
- `enhancement` - New feature or request
- `documentation` - Documentation improvements
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention needed
- `performance` - Performance related
- `security` - Security related
- `question` - Further information requested

---

## Recognition

### Contributors

Contributors will be:
- Listed in CONTRIBUTORS.md
- Credited in release notes
- Mentioned in relevant documentation

### Significant Contributions

Significant contributors may be:
- Added as collaborators
- Invited to planning discussions
- Recognized in project README

---

## Getting Help

### Resources

- **Documentation**: See [README.md](README.md) and other guides
- **Issues**: Search existing issues for similar problems
- **Discussions**: Use GitHub Discussions for questions
- **Email**: Contact maintainers for sensitive issues

### Questions

Before asking:
1. Check documentation
2. Search existing issues
3. Review troubleshooting guide

When asking:
- Be specific
- Include relevant details
- Provide examples
- Be patient and respectful

---

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

## Thank You!

Thank you for taking the time to contribute to DataSync Turbo Tools. Your contributions help make this project better for everyone!

---

**Document Version:** 1.0.0
**Last Updated:** 2025-10-29
