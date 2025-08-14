# Server Setup

This directory contains the server-side components for the speed test suite.

## Quick Start

1. Generate SSL certificates (for testing):
```bash
chmod +x generate_cert.sh
./generate_cert.sh
```

2. Create test files:
```bash
mkdir -p test-files
# Create a 200MB random test file
dd if=/dev/urandom of=test-files/random-200mb.bin bs=1M count=200
```

3. Start the servers:
```bash
docker-compose up -d
```

4. Check status:
```bash
docker-compose ps
docker-compose logs
```

## Architecture

- **gRPC Server**: Handles file upload/download via gRPC protocol (port 50051 internal)
- **Nginx Proxy**: 
  - HTTPS termination on port 443
  - HTTP file serving
  - HTTP PUT upload support
  - gRPC reverse proxy
  
## Endpoints

- **HTTPS**: `https://<your-domain>:443/`
- **HTTP Upload**: `PUT https://<your-domain>:443/upload/<filename>`
- **HTTP Download**: `GET https://<your-domain>:443/files/<filename>`
- **gRPC**: `https://<your-domain>:443` (via `/fileservice.FileService/` path)

## Directories

- `certs/`: SSL certificates
- `uploads/`: Uploaded files storage
- `test-files/`: Pre-created test files for download testing