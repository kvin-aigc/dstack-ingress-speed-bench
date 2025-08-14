# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a comprehensive network speed testing benchmark suite that compares HTTP vs gRPC performance across different server deployments. The project consists of:

- **Client**: Go-based benchmarking client that tests both HTTP and gRPC protocols
- **Server**: Dockerized services with nginx proxy + gRPC servers (Python and Go implementations)
- **Orchestration**: Automated deployment and testing scripts via SSH

## Architecture

```
Client ──► Internet ──► Reverse Proxy/Gateway ──► Target Server
                            (custom URL)          (nginx + gRPC server)
```

### Components
- **nginx**: HTTPS termination, HTTP file serving, gRPC reverse proxy (port 443/80)
- **gRPC Server**: Go-based file upload/download service (internal port 50051)
- **Go Client**: Benchmark runner with HTTP and gRPC test implementations
- **Test Infrastructure**: SSH-based remote deployment with auto URL parsing

## Key Commands

### Primary Benchmarking
```bash
# Run complete benchmark with default 200MB file size
./run-bench.sh <ssh-server-name> <reverse-baseurl>

# Run complete benchmark with custom file size (in MB)
./run-bench.sh <ssh-server-name> <reverse-baseurl> <file-size-mb>

# Example usage
./run-bench.sh dev1 https://6fd2b3f13a7deedb10480c914496e6daddefe1a6-8090.app.kvin.wang:12004/ 200
./run-bench.sh dev1 https://6fd2b3f13a7deedb10480c914496e6daddefe1a6-8090.app.kvin.wang:12004/ 50
```

### Client-side Testing
```bash
cd client

# Build Go client
./build.sh

# Run benchmark directly (requires server to be running)
./benchmark --server <host> --port <port> --size <file-size-mb>
```

### Server Operations
```bash
cd server

# Generate SSL certificates
./generate_cert.sh

# Start server stack
docker compose up -d

# Check status
docker compose ps
docker compose logs

# Cleanup
docker compose down -v
```

## Development Workflow

### Testing Changes
1. Modify client or server code
2. For client changes: Run `./build.sh` in client directory
3. For server changes: Restart relevant docker services
4. Run benchmarks to validate changes

### URL Format
The system expects URLs in this format: `<hash>-<port>.<domain>`
- SSH proxy: `<hash>-22.<domain>:<port>`  
- Service endpoint: `<hash>-s.<domain>:<port>`

### File Structure
- `client/`: Go benchmark client with HTTP/gRPC implementations
- `server/`: Docker services (nginx + gRPC servers in Python/Go)
- `run-bench*.sh`: Main orchestration scripts
- `result.md`: Benchmark results and performance comparisons

## Test Infrastructure
- Uses SSH tunneling for remote server access
- Automatically configures SSH proxy settings
- Deploys via Docker Compose on remote servers
- Tests 200MB file transfers for both upload/download
- Collects server hardware information for reporting
- Automatically cleans up resources after testing

## Protocol Details
- **HTTP**: Uses PUT for uploads, GET for downloads via nginx
- **gRPC**: Uses streaming file service with protobuf definitions
- **SSL**: Self-signed certificates for testing (nginx terminates SSL)
- **Proxy**: nginx handles both HTTP and gRPC traffic routing