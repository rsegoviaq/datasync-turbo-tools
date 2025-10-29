# Versioning Guide

> Version management strategy and release process for DataSync Turbo Tools.

---

## Table of Contents

- [Versioning Scheme](#versioning-scheme)
- [Version Storage](#version-storage)
- [Release Process](#release-process)
- [Version History](#version-history)
- [Updating Versions](#updating-versions)
- [Backward Compatibility](#backward-compatibility)

---

## Versioning Scheme

DataSync Turbo Tools follows **[Semantic Versioning 2.0.0](https://semver.org/)**.

### Format

```
MAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]
```

### Examples

- `1.0.0` - Initial production release
- `1.0.1` - Patch release (bug fixes)
- `1.1.0` - Minor release (new features, backward compatible)
- `2.0.0` - Major release (breaking changes)
- `1.1.0-beta.1` - Pre-release version
- `1.0.0+20251028` - Build metadata

### Version Components

#### MAJOR Version (X.0.0)

Increment when making **incompatible API changes** or **breaking changes**.

**Examples of Breaking Changes**:
- Removing configuration parameters
- Changing default behavior in incompatible ways
- Removing or renaming scripts
- Changing log format in incompatible ways
- Requiring different system dependencies

**Example**: v1.0.0 → v2.0.0

```
Breaking changes:
- Changed configuration file format from .env to .yaml
- Removed deprecated --legacy-mode flag
- Renamed scripts/datasync.sh to scripts/upload.sh
```

#### MINOR Version (0.X.0)

Increment when adding **new functionality** in a **backward-compatible** manner.

**Examples of Minor Changes**:
- Adding new configuration options (with defaults)
- Adding new scripts or tools
- Adding new features to existing scripts
- Enhancing monitoring or logging (additively)
- Improving performance without changing interface

**Example**: v1.0.0 → v1.1.0

```
New features:
- Added web dashboard for monitoring
- New benchmark mode for performance testing
- Support for multi-region uploads
- Enhanced logging with custom formatters
```

#### PATCH Version (0.0.X)

Increment when making **backward-compatible bug fixes**.

**Examples of Patch Changes**:
- Fixing throughput calculation bug
- Correcting error messages
- Improving documentation
- Fixing log formatting issues
- Resolving permission errors
- Security patches

**Example**: v1.0.0 → v1.0.1

```
Bug fixes:
- Fixed throughput showing 0 MB/s in logs
- Corrected JSON formatting in metrics output
- Fixed permission issues on monitoring scripts
- Updated AWS SDK compatibility
```

---

## Version Storage

### Primary Version File

**Location**: `.release/version.txt`

```
1.0.0
```

**Format**: Single line with version number (no prefix, no newline at end)

### Version References

The version number appears in multiple locations:

1. **`.release/version.txt`**
   - Source of truth for current version
   - Used by build scripts

2. **`README.md`**
   - Badge: `[![Version](https://img.shields.io/badge/version-1.0.0-blue)]()`
   - Footer: `**Version:** 1.0.0`

3. **Production Package README**
   - `packages/production-package/datasync-production-v{VERSION}/README.md`
   - Multiple references throughout documentation

4. **Build Scripts**
   - `packages/production-package/build.sh` reads from `.release/version.txt`

5. **Core Scripts**
   - `scripts/datasync-s5cmd.sh` includes version in logs
   - Line 39: `readonly VERSION="1.0.0"`

6. **CHANGELOG.md**
   - Version history with dates and changes

---

## Release Process

### 1. Pre-Release Checklist

Before creating a new release:

- [ ] All features/fixes complete and tested
- [ ] Documentation updated
- [ ] CHANGELOG.md updated with changes
- [ ] All tests passing
- [ ] No critical bugs
- [ ] Performance validated
- [ ] Security review completed (for major/minor releases)

### 2. Version Update Process

#### Step 1: Determine New Version Number

```bash
# Current version
CURRENT=$(cat .release/version.txt)
echo "Current version: $CURRENT"

# Decide new version based on changes
# Patch: 1.0.0 → 1.0.1
# Minor: 1.0.0 → 1.1.0
# Major: 1.0.0 → 2.0.0
NEW_VERSION="1.1.0"
```

#### Step 2: Update Version File

```bash
# Update primary version file
echo "$NEW_VERSION" > .release/version.txt

# Verify
cat .release/version.txt
```

#### Step 3: Update Core Script Version

```bash
# Edit scripts/datasync-s5cmd.sh
# Update line 39:
readonly VERSION="1.1.0"
```

#### Step 4: Update README.md

```bash
# Update version badge
[![Version](https://img.shields.io/badge/version-1.1.0-blue)]()

# Update footer
**Version:** 1.1.0
**Release Date:** 2025-11-XX
```

#### Step 5: Update CHANGELOG.md

```bash
# Add new version section at top
## [1.1.0] - 2025-11-XX

### Added
- New feature descriptions

### Changed
- Modified behavior descriptions

### Fixed
- Bug fix descriptions

### Security
- Security fix descriptions
```

#### Step 6: Build Production Package

```bash
# Build new package
cd packages/production-package
./build.sh

# This creates:
# - datasync-production-v1.1.0/
# - datasync-production-v1.1.0.tar.gz
# - datasync-production-v1.1.0.tar.gz.sha256
```

#### Step 7: Test Production Package

```bash
# Extract and test
tar xzf datasync-production-v1.1.0.tar.gz
cd datasync-production-v1.1.0

# Run installer in test mode
./install.sh

# Verify version
./scripts/datasync-s5cmd.sh --version  # Should show 1.1.0
```

#### Step 8: Commit and Tag

```bash
# Stage all version changes
git add .release/version.txt
git add scripts/datasync-s5cmd.sh
git add README.md
git add CHANGELOG.md
git add packages/

# Commit with version message
git commit -m "release: version 1.1.0

- Updated version to 1.1.0
- Updated documentation
- Built production package
"

# Create annotated tag
git tag -a v1.1.0 -m "Version 1.1.0

Release notes:
- Feature 1
- Feature 2
- Bug fix 1
"

# Push commits and tags
git push origin master
git push origin v1.1.0
```

### 3. Post-Release Tasks

- [ ] Create GitHub release with tarball
- [ ] Update release notes
- [ ] Notify users/clients
- [ ] Archive old versions
- [ ] Update documentation website (if applicable)
- [ ] Announce on communication channels

---

## Version History

### v1.0.0 (2025-10-28)

**Initial production release**

#### Added
- High-performance s5cmd upload scripts
- Production deployment automation
- Comprehensive monitoring and logging
- Throughput tracking and metrics
- Health checks and alerts
- Log rotation with logrotate
- Benchmark tools
- Professional documentation
- One-command installer
- Production-ready package

#### Performance
- 5-12x faster than AWS CLI
- Optimized for 3+ Gbps networks
- Concurrent operations: 64
- Workers: 32
- Part size: 128MB

#### Testing
- Validated with real uploads (2.1GB in 245 seconds)
- Performance benchmarks completed
- Production deployment tested

---

## Updating Versions

### Quick Reference

```bash
# 1. Update version file
echo "1.1.0" > .release/version.txt

# 2. Update script version
sed -i 's/readonly VERSION=".*"/readonly VERSION="1.1.0"/' scripts/datasync-s5cmd.sh

# 3. Update README badge
sed -i 's/version-[0-9.]*/version-1.1.0/' README.md

# 4. Update README footer
sed -i 's/\*\*Version:\*\* [0-9.]*/\*\*Version:\*\* 1.1.0/' README.md

# 5. Update CHANGELOG
# (manually edit CHANGELOG.md)

# 6. Build package
cd packages/production-package && ./build.sh

# 7. Commit and tag
git add -A
git commit -m "release: version 1.1.0"
git tag -a v1.1.0 -m "Version 1.1.0"
git push && git push --tags
```

### Automated Version Update Script

Create `.release/update-version.sh`:

```bash
#!/bin/bash
#
# Update version across all files
#

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <new-version>"
    echo "Example: $0 1.1.0"
    exit 1
fi

NEW_VERSION="$1"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Updating version to: $NEW_VERSION"

# Update version file
echo "$NEW_VERSION" > "$PROJECT_ROOT/.release/version.txt"
echo "✓ Updated .release/version.txt"

# Update core script
sed -i "s/readonly VERSION=\".*\"/readonly VERSION=\"$NEW_VERSION\"/" \
    "$PROJECT_ROOT/scripts/datasync-s5cmd.sh"
echo "✓ Updated scripts/datasync-s5cmd.sh"

# Update README badge
sed -i "s/version-[0-9.]*/version-$NEW_VERSION/" "$PROJECT_ROOT/README.md"
echo "✓ Updated README.md badge"

# Update README footer
sed -i "s/\*\*Version:\*\* [0-9.]*/\*\*Version:\*\* $NEW_VERSION/" \
    "$PROJECT_ROOT/README.md"
echo "✓ Updated README.md footer"

echo ""
echo "Version updated to $NEW_VERSION"
echo ""
echo "Next steps:"
echo "1. Update CHANGELOG.md with release notes"
echo "2. Build production package: cd packages/production-package && ./build.sh"
echo "3. Test the new package"
echo "4. Commit: git commit -am 'release: version $NEW_VERSION'"
echo "5. Tag: git tag -a v$NEW_VERSION -m 'Version $NEW_VERSION'"
echo "6. Push: git push && git push --tags"
```

Usage:
```bash
chmod +x .release/update-version.sh
./.release/update-version.sh 1.1.0
```

---

## Backward Compatibility

### Compatibility Policy

- **Major versions**: May break backward compatibility
- **Minor versions**: Must maintain backward compatibility
- **Patch versions**: Must maintain backward compatibility

### Deprecation Policy

When removing features:

1. **Mark as deprecated** in current release
   - Add deprecation warning to documentation
   - Log warning when deprecated feature is used
   - Document migration path

2. **Maintain for at least one minor version**
   - Keep functionality working
   - Provide migration guide
   - Update examples

3. **Remove in next major version**
   - Remove deprecated code
   - Update documentation
   - Announce breaking change

### Example Deprecation

**v1.5.0** (Deprecation):
```bash
# Add warning when old parameter is used
if [ -n "$OLD_PARAM" ]; then
    log_warning "OLD_PARAM is deprecated, use NEW_PARAM instead"
    NEW_PARAM="$OLD_PARAM"  # Still works
fi
```

Documentation:
```markdown
## Deprecated Features

### OLD_PARAM (Deprecated in v1.5.0)
**Will be removed in v2.0.0**

Use `NEW_PARAM` instead.

Migration:
- OLD: `export OLD_PARAM="value"`
- NEW: `export NEW_PARAM="value"`
```

**v2.0.0** (Removal):
```bash
# Remove old parameter entirely
# Only NEW_PARAM is supported
```

### Configuration File Compatibility

- Configuration files should remain compatible within major versions
- Add new options with sensible defaults
- Validate configuration and warn about unknown options

### Log Format Compatibility

- JSON log format is part of the API
- Don't change field names in minor/patch releases
- Add new fields freely (additive changes)
- Change field format only in major releases

---

## Version Numbering Best Practices

### When to Increment MAJOR

- Removing configuration options
- Changing required dependencies
- Modifying script behavior incompatibly
- Changing log format in breaking ways
- Removing or renaming scripts

### When to Increment MINOR

- Adding new scripts or tools
- Adding new configuration options (with defaults)
- Adding new features
- Enhancing existing features (backward compatible)
- Improving performance

### When to Increment PATCH

- Bug fixes
- Documentation updates
- Performance improvements (without interface changes)
- Security patches
- Dependency updates (backward compatible)

### Pre-Release Versions

For testing before official release:

- `1.1.0-alpha.1` - Alpha release (unstable, internal testing)
- `1.1.0-beta.1` - Beta release (more stable, external testing)
- `1.1.0-rc.1` - Release candidate (production-ready, final testing)

---

## Git Tagging Strategy

### Tag Format

```
v{MAJOR}.{MINOR}.{PATCH}[-{PRERELEASE}]
```

### Examples

```bash
# Production releases
git tag -a v1.0.0 -m "Initial production release"
git tag -a v1.1.0 -m "Added multi-region support"
git tag -a v1.1.1 -m "Fixed throughput calculation"

# Pre-releases
git tag -a v1.2.0-beta.1 -m "Beta release for 1.2.0"
git tag -a v2.0.0-rc.1 -m "Release candidate for 2.0.0"
```

### Tag Annotations

Include in tag message:
- Version number
- Brief summary of changes
- Breaking changes (if any)
- Migration notes (if needed)

**Example**:
```bash
git tag -a v1.1.0 -m "Version 1.1.0

Added Features:
- Multi-region upload support
- Web dashboard for monitoring
- Advanced scheduling options

Bug Fixes:
- Fixed permission issues on systemd service
- Corrected metric calculation for large files

Notes:
- No breaking changes
- All configurations from v1.0.x are compatible
"
```

---

## Changelog Maintenance

### Changelog Format

Follow [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
# Changelog

## [Unreleased]
### Added
- Features in development

## [1.1.0] - 2025-11-15
### Added
- New feature 1
- New feature 2

### Changed
- Modified behavior 1

### Fixed
- Bug fix 1
- Bug fix 2

### Security
- Security patch 1

## [1.0.0] - 2025-10-28
### Added
- Initial release
```

### Categories

- **Added**: New features
- **Changed**: Changes in existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security fixes

---

## Release Checklist Template

```markdown
## Release v{VERSION} Checklist

### Pre-Release
- [ ] All features/fixes complete
- [ ] Tests passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version numbers updated
- [ ] Package builds successfully
- [ ] Package tested in clean environment

### Release
- [ ] Version committed
- [ ] Git tag created
- [ ] Changes pushed to remote
- [ ] GitHub release created
- [ ] Release notes published
- [ ] Package uploaded

### Post-Release
- [ ] Users notified
- [ ] Documentation website updated
- [ ] Old versions archived
- [ ] Monitoring systems updated
- [ ] Support channels informed
```

---

## Resources

- [Semantic Versioning 2.0.0](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Git Tagging](https://git-scm.com/book/en/v2/Git-Basics-Tagging)

---

**Document Version:** 1.0.0
**Last Updated:** 2025-10-29
