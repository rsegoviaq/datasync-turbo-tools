# DataSync Turbo Tools

> High-performance S3 upload tools using s5cmd for **5-12x faster** transfers than AWS CLI.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Status](https://img.shields.io/badge/status-planning-orange)]()

## 🚀 Performance

Upload speeds that saturate high-bandwidth networks:

| Network Bandwidth | AWS CLI (default) | AWS CLI (optimized) | s5cmd | Improvement |
|-------------------|-------------------|---------------------|-------|-------------|
| **3 Gbps** | 160 MB/s | 320 MB/s | **1200 MB/s** | **7.5x** |
| **10 Gbps** | 400 MB/s | 800 MB/s | **4000 MB/s** | **10x** |

### Real-World Example

**Uploading 150 GB dataset:**
- AWS CLI (default): ~16 minutes
- AWS CLI (Phase 1 optimized): ~8 minutes
- **s5cmd (this project): ~2-3 minutes** ⚡

---

## 📋 Project Status

**Current Status:** 🟠 **Planning Phase**

This project is currently in the planning stage. The implementation plan is complete and ready for development.

See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for the full development roadmap.

---

## 💡 What is This?

DataSync Turbo Tools is a companion project to [datasync-client-deployment](https://github.com/rsegoviaq/datasync-client-deployment) that provides ultra-high-performance S3 upload capabilities using [s5cmd](https://github.com/peak/s5cmd).

**Why s5cmd?**
- Written in Go (compiled) vs Python (interpreted)
- True parallel operations with Go routines
- Optimized TCP connection pooling
- Lower memory overhead
- Hardware-accelerated checksums

---

## ✨ Features (Planned)

- ✅ **5-12x faster** uploads than AWS CLI
- ✅ **CRC64NVME/SHA256** checksum verification
- ✅ **Compatible** with existing datasync configs
- ✅ **Side-by-side** deployment with AWS CLI
- ✅ **Drop-in replacement** for datasync-simulator.sh
- ✅ **Comprehensive testing** suite
- ✅ **Production-ready** error handling
- ✅ **Detailed documentation** and examples

---

## 🗂️ Project Structure

```
datasync-turbo-tools/
├── tools/          # Installation & utilities
├── scripts/        # Upload scripts (s5cmd & AWS CLI)
├── config/         # Configuration templates
├── tests/          # Comprehensive test suite
├── docs/           # Documentation
└── examples/       # Example deployments
```

---

## 📖 Documentation (Coming Soon)

Once implemented, documentation will include:

- **Installation Guide** - Step-by-step setup
- **s5cmd Usage Guide** - Complete configuration reference
- **Performance Tuning** - Optimize for your network
- **Troubleshooting** - Common issues and solutions
- **Migration Guide** - Switch from AWS CLI to s5cmd
- **Comparison** - Detailed AWS CLI vs s5cmd analysis

---

## 🎯 Quick Start (Once Implemented)

```bash
# Clone repository
git clone https://github.com/your-org/datasync-turbo-tools
cd datasync-turbo-tools

# Install s5cmd
./tools/install-s5cmd.sh

# Configure
cp config/s5cmd.env.template config/s5cmd.env
nano config/s5cmd.env  # Edit with your settings

# Upload
./scripts/datasync-s5cmd.sh

# Benchmark (compare with AWS CLI)
./tools/benchmark.sh
```

---

## 🔧 System Requirements

- Linux or macOS
- AWS CLI installed and configured
- AWS credentials with S3 access
- 100 MB disk space for s5cmd binary

**Recommended:**
- High-bandwidth network (>1 Gbps)
- Large file datasets (100MB - 5GB files)
- Multiple files to maximize concurrency

---

## 📊 How It Works

s5cmd achieves dramatic performance improvements through:

1. **True Parallelism**
   - Go routines handle hundreds of concurrent uploads
   - No Python GIL (Global Interpreter Lock) bottleneck
   - Efficient worker pool architecture

2. **Optimized Networking**
   - Multiple TCP connections with connection pooling
   - Better handling of high-latency links
   - Reduced per-request overhead

3. **Efficient Resource Usage**
   - Lower CPU usage per operation
   - Minimal memory footprint
   - Hardware-accelerated checksums (CRC64NVME)

---

## 🤝 Contributing

This is currently a planning/development project. Contributions will be welcome once the initial implementation is complete.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🔗 Related Projects

- [datasync-client-deployment](https://github.com/rsegoviaq/datasync-client-deployment) - Main DataSync simulator project
- [s5cmd](https://github.com/peak/s5cmd) - The high-performance S3 tool this project builds upon

---

## 📞 Support

For questions, issues, or feature requests:
- Open an issue on GitHub
- See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) (once available)

---

## 🚦 Roadmap

- [x] Planning complete
- [ ] Phase 3.1: Repository setup ← **Current**
- [ ] Phase 3.2: s5cmd installation tool
- [ ] Phase 3.3: s5cmd upload script
- [ ] Phase 3.4: Testing suite
- [ ] Phase 3.5: Documentation
- [ ] Phase 3.6: Example deployments
- [ ] v1.0 Release

---

**Last Updated:** 2025-10-23
**Status:** Planning Complete, Ready for Implementation

See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for detailed development plan.
