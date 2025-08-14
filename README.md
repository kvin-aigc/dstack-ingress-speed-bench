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

| OS Version | Memory | CPU Cores | Client | Server | HTTPS Upload (MB/s) | HTTPS Download (MB/s) | gRPC Upload (MB/s) | gRPC Download (MB/s) | Best Upload | Best Download |
|---------|-----------|---------|------------|------------|--------------------|-----------------------|--------------------|----------------------|-------------|---------------|
| DStack 0.5.2 | 30.4G | 16 | tdxlab | gpu08 | **39.15**<br/>`█████████▉░░░░░░░░░░` | 5.03<br/>`█░░░░░░░░░░░░░░░░░░░` | 10.62<br/>`██████▋░░░░░░░░░░░░░` | **5.04**<br/>`█░░░░░░░░░░░░░░░░░░░` | HTTPS (39.15) | gRPC (5.04) |
| DStack 0.5.2 | 30.4G | 2 | tdxlab | gpu08 | **33.88**<br/>`████████▌░░░░░░░░░░░` | 5.76<br/>`█▏░░░░░░░░░░░░░░░░░░` | 8.47<br/>`█████▎░░░░░░░░░░░░░░` | **5.37**<br/>`█▏░░░░░░░░░░░░░░░░░░` | HTTPS (33.88) | gRPC (5.37) |
| DStack 0.5.2 | 30.4G | 16 | gpu08 | gpu08 | **48.80**<br/>`████████████▏░░░░░░░` | **88.84**<br/>`████████████████████` | 11.76<br/>`███████▍░░░░░░░░░░░░` | 53.86<br/>`████████████▌░░░░░░░` | HTTPS (48.80) | HTTPS (88.84) |
| DStack 0.5.3 | 30.4G | 2 | tdxlab | tdxlab | **71.32**<br/>`███████████████████░` | 86.25<br/>`████████████████████` | 12.81<br/>`████████░░░░░░░░░░░░` | **91.22**<br/>`████████████████████` | HTTPS (71.32) | gRPC (91.22) |
| DStack 0.5.3 | 30.4G | 16 | tdxlab | tdxlab | **52.30**<br/>`█████████████░░░░░░░` | 87.83<br/>`████████████████████` | 13.83<br/>`████████▋░░░░░░░░░░░` | **88.13**<br/>`████████████████████` | HTTPS (52.30) | gRPC (88.13) |
| DStack 0.5.3 | 30.4G | 16 | tdxlab | tdxlab | **64.87**<br/>`████████████████▏░░░` | 82.63<br/>`███████████████████▏` | 14.00<br/>`████████▊░░░░░░░░░░░` | **85.53**<br/>`███████████████████▊` | HTTPS (64.87) | gRPC (85.53) |
| DStack 0.3.6 | 14.7G | 8 | tdxlab | prod2 | **95.38**<br/>`████████████████████` | 86.25<br/>`████████████████████` | 15.88<br/>`██████████░░░░░░░░░░` | **77.50**<br/>`█████████████████░░░` | HTTPS (95.38) | HTTPS (86.25) |
| DStack 0.3.6 | 14.7G | 8 | tdxlab | prod5 | **47.88**<br/>`████████████░░░░░░░░` | 48.24<br/>`███████████▏░░░░░░░░` | 9.48<br/>`██████░░░░░░░░░░░░░░` | **46.72**<br/>`██████████▊░░░░░░░░░` | HTTPS (47.88) | HTTPS (48.24) |
| DStack 0.3.6 | 14.7G | 8 | tdxlab | prod8 | **41.49**<br/>`██████████▍░░░░░░░░░` | 43.96<br/>`██████████▏░░░░░░░░░` | 7.96<br/>`█████░░░░░░░░░░░░░░░` | **62.15**<br/>`██████████████▍░░░░░` | HTTPS (41.49) | gRPC (62.15) |
| DStack 0.3.6 | 14.7G | 8 | tdxlab | prod10 | **16.03**<br/>`████░░░░░░░░░░░░░░░░` | 9.13<br/>`██▏░░░░░░░░░░░░░░░░░` | 11.47<br/>`███████▏░░░░░░░░░░░░` | **7.87**<br/>`█▊░░░░░░░░░░░░░░░░░░` | HTTPS (16.03) | HTTPS (9.13) |

---
