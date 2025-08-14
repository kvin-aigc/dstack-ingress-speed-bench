# Network Speed Test Suite

Comprehensive HTTP vs gRPC performance testing suite for dstack CVM with automated deployment and benchmarking.

## Quick Start

Run a complete benchmark on any server with a single command:

```bash
./run-bench.sh <ssh-server-name> <service-url>
```

### Example Usage

```bash
# Test on dev1 server via dstack gateway
./run-bench.sh dev1 https://6fd2b3f13a7deedb10480c914496e6daddefe1a6-8090.app.kvin.wang:12004/
```

## What It Does

1. **🚀 Auto-deploys** server components via SSH
2. **🔧 Sets up** nginx proxy + gRPC server using Docker Compose
3. **🧪 Runs** comprehensive HTTP and gRPC speed tests
4. **📊 Generates** performance comparison report
5. **🧹 Cleans up** remote server automatically

## Architecture

```
Client ──► Internet ──► Reverse Proxy/Gateway ──► Target Server
                            (your-url)              (nginx + gRPC)
```

## Requirements

- SSH access to target server
- Docker and Docker Compose on target server
- Python 3.8+ on client machine

## Output

- Console: Formatted performance table
- File: `benchmark_results.json` with detailed metrics
- Report: Complete analysis in `REPORT.md`

## Manual Testing

For detailed testing or custom scenarios, see:
- `server/README.md` - Manual server setup
- `client/README.md` - Individual test tools

## Benchmark Results

Result for tdxlab:
```
============================================================
BENCHMARK RESULTS - 400MB File
============================================================
Protocol     Operation         Speed (MB/s)     Time (s)     Status
======================================================================
HTTPS        Upload                   69.33         5.77          ✅
HTTPS        Download                109.42         3.66          ✅
gRPC         Upload                   74.15         5.39          ✅
gRPC         Download                104.83         3.82          ✅
```

Result for gpu08:
```
============================================================
BENCHMARK RESULTS - 400MB File
============================================================
Protocol     Operation         Speed (MB/s)     Time (s)     Status
======================================================================
HTTPS        Upload                   54.28         7.37          ✅
HTTPS        Download                 83.85         4.77          ✅
gRPC         Upload                   69.67         5.74          ✅
gRPC         Download                 89.41         4.47          ✅
```
