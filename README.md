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

## Test Results

The suite tests 200MB file transfers and compares:

| Protocol | Upload Speed | Download Speed | Use Case |
|----------|--------------|----------------|----------|
| HTTPS | ~37 MB/s | ~6 MB/s | File transfers |
| gRPC | ~5.4 MB/s | ~5.3 MB/s | Streaming APIs |

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

| Test Date | Server | CPU Cores | Memory | OS Version | HTTPS Upload (MB/s) | HTTPS Download (MB/s) | gRPC Upload (MB/s) | gRPC Download (MB/s) | Best Upload | Best Download |
|-----------|---------|-----------|---------|------------|--------------------|-----------------------|--------------------|----------------------|-------------|---------------|
| 2025-08-14 04:52:12 | gpu08-test0 | 16 | 30.4G | DStack 0.5.2 | **39.15**<br/>`█████████▉░░░░░░░░░░` | 5.03<br/>`█░░░░░░░░░░░░░░░░░░░` | 10.62<br/>`██████▋░░░░░░░░░░░░░` | **5.04**<br/>`█░░░░░░░░░░░░░░░░░░░` | HTTPS (39.15) | gRPC (5.04) |
| 2025-08-14 04:37:49 | gpu08-test1 | 2 | 30.4G | DStack 0.5.2 | **33.88**<br/>`████████▌░░░░░░░░░░░` | 5.76<br/>`█▏░░░░░░░░░░░░░░░░░░` | 8.47<br/>`█████▎░░░░░░░░░░░░░░` | **5.37**<br/>`█▏░░░░░░░░░░░░░░░░░░` | HTTPS (33.88) | gRPC (5.37) |
| 2025-08-14 04:43:51 | tdxlab-test0 | 2 | 30.4G | DStack 0.5.3 | **71.32**<br/>`███████████████████░` | 86.25<br/>`████████████████████` | 12.81<br/>`████████░░░░░░░░░░░░` | **91.22**<br/>`████████████████████` | HTTPS (71.32) | gRPC (91.22) |
| 2025-08-14 04:46:28 | tdxlab-test1 | 16 | 30.4G | DStack 0.5.3 | **52.30**<br/>`█████████████░░░░░░░` | 87.83<br/>`████████████████████` | 13.83<br/>`████████▋░░░░░░░░░░░` | **88.13**<br/>`████████████████████` | HTTPS (52.30) | gRPC (88.13) |
| 2025-08-14 04:48:01 | tdxlab-test1 | 16 | 30.4G | DStack 0.5.3 | **64.87**<br/>`████████████████▏░░░` | 82.63<br/>`███████████████████▏` | 14.00<br/>`████████▊░░░░░░░░░░░` | **85.53**<br/>`███████████████████▊` | HTTPS (64.87) | gRPC (85.53) |
| 2025-08-14 05:48:29 | prod2-test0 | 8 | 14.7G | DStack 0.3.6 | **95.38**<br/>`████████████████████` | 86.25<br/>`████████████████████` | 15.88<br/>`██████████░░░░░░░░░░` | **77.50**<br/>`█████████████████░░░` | HTTPS (95.38) | HTTPS (86.25) |
| 2025-08-14 05:54:19 | prod5-test0 | 8 | 14.7G | DStack 0.3.6 | **33.90**<br/>`████████▌░░░░░░░░░░░` | 32.77<br/>`███████▌░░░░░░░░░░░░` | 7.50<br/>`████▋░░░░░░░░░░░░░░░` | **29.47**<br/>`██████▊░░░░░░░░░░░░░` | HTTPS (33.90) | HTTPS (32.77) |
| 2025-08-14 05:55:57 | prod5-test0 | 8 | 14.7G | DStack 0.3.6 | **47.88**<br/>`████████████░░░░░░░░` | 48.24<br/>`███████████▏░░░░░░░░` | 9.48<br/>`██████░░░░░░░░░░░░░░` | **46.72**<br/>`██████████▊░░░░░░░░░` | HTTPS (47.88) | HTTPS (48.24) |
| 2025-08-14 05:58:24 | prod8-test0 | 8 | 14.7G | DStack 0.3.6 | **41.49**<br/>`██████████▍░░░░░░░░░` | 43.96<br/>`██████████▏░░░░░░░░░` | 7.96<br/>`█████░░░░░░░░░░░░░░░` | **62.15**<br/>`██████████████▍░░░░░` | HTTPS (41.49) | gRPC (62.15) |
| 2025-08-14 05:18:55 | prod10-test0 | 8 | 14.7G | DStack 0.3.6 | **16.03**<br/>`████░░░░░░░░░░░░░░░░` | 9.13<br/>`██▏░░░░░░░░░░░░░░░░░` | 11.47<br/>`███████▏░░░░░░░░░░░░` | **7.87**<br/>`█▊░░░░░░░░░░░░░░░░░░` | HTTPS (16.03) | HTTPS (9.13) |

---
