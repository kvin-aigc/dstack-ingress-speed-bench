# Client Test Suite

This directory contains client-side tools for testing network speed using both HTTP and gRPC protocols.

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Generate protocol buffer files (automatic on first run):
```bash
python -m grpc_tools.protoc --python_out=. --grpc_python_out=. -I. file_service.proto
```

## Individual Tests

### HTTP Test
```bash
# Upload
python http_test.py upload --url https://server.example.com:443 --file test.bin

# Download  
python http_test.py download --url https://server.example.com:443 --file test.bin --output downloaded.bin

# Both
python http_test.py both --url https://server.example.com:443 --file test.bin
```

### gRPC Test
```bash
# Upload
python grpc_test.py upload --host server.example.com:443 --file test.bin

# Download
python grpc_test.py download --host server.example.com:443 --file test.bin --output downloaded.bin

# Both
python grpc_test.py both --host server.example.com:443 --file test.bin
```

## Complete Benchmark

Run all tests and generate comparison report:
```bash
python benchmark.py --server server.example.com --port 443 --size 200
```

Options:
- `--server`: Server hostname or IP
- `--port`: Server port (default: 443)
- `--size`: Test file size in MB (default: 200)
- `--skip-http`: Skip HTTP tests
- `--skip-grpc`: Skip gRPC tests

## Output

The benchmark script generates:
- Console output with formatted table
- `benchmark_results.json` with detailed results
- Downloaded test files (can be deleted after tests)