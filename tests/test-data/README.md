# Test Data Directory

This directory contains sample test data for validating datasync-turbo-tools functionality.

## Directory Structure

```
test-data/
├── README.md                 # This file
├── sample-small.txt          # Small text file (< 1 KB)
├── sample-medium.txt         # Medium text file (~ 100 KB)
└── .gitkeep                  # Keeps directory in git
```

## Usage

### Manual Testing

Use these files for quick manual tests:

```bash
# Test s5cmd upload
SOURCE_DIR=tests/test-data S3_BUCKET=your-bucket ./scripts/datasync-s5cmd.sh --dry-run

# Test AWS CLI upload
SOURCE_DIR=tests/test-data S3_BUCKET=your-bucket ./scripts/datasync-awscli.sh --dry-run
```

### Automated Testing

The test scripts will generate their own test data:

- `checksum-validation.sh` - Generates random binary files
- `performance-test.sh` - Generates test data via benchmark.sh
- `unit-tests.sh` - Uses existing installation
- `error-handling.sh` - Creates temporary test scenarios

## Generating Test Data

To generate larger test datasets for performance testing:

```bash
# Generate 100 MB of test data
dd if=/dev/urandom of=tests/test-data/large-file.bin bs=1M count=100

# Generate multiple small files
for i in {1..100}; do
    dd if=/dev/urandom of=tests/test-data/file-$i.bin bs=1K count=100
done
```

## Cleanup

Test scripts clean up after themselves by default. To manually clean up:

```bash
# Remove generated test files
rm -f tests/test-data/*.bin
rm -f tests/test-data/large-*

# Keep only the sample files
git clean -fd tests/test-data/
```

## Notes

- Test scripts create temporary directories for isolated testing
- Large files are not committed to git (see .gitignore)
- Only small sample files are version controlled
- Generated test data is automatically cleaned up after tests
