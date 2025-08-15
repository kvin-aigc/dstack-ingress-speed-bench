#!/bin/bash

# Network Speed Test Benchmark Runner
# Usage: ./run-bench.sh <ssh-server-name> <reverse-baseurl> [file-size-mb]
# Example: ./run-bench.sh dev1 https://6fd2b3f13a7deedb10480c914496e6daddefe1a6-8090.app.kvin.wang:12004/ 100
# The TLS-passthrough HTTPS/gRPC base URL would be https://6fd2b3f13a7deedb10480c914496e6daddefe1a6-s.app.kvin.wang:12004/
# The TLS-terminate HTTP base URL would be https://6fd2b3f13a7deedb10480c914496e6daddefe1a6-80.app.kvin.wang:12004/
# The TLS-terminate gRPC base URL would be https://6fd2b3f13a7deedb10480c914496e6daddefe1a6-50051p.app.kvin.wang:12004/

set -e

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
    echo "Usage: $0 <ssh-server-name> <reverse-baseurl> [file-size-mb]"
    echo "Example: $0 dev1 https://6fd2b3f13a7deedb10480c914496e6daddefe1a6-8090.app.kvin.wang:12004/ 200"
    echo ""
    echo "Parameters:"
    echo "  ssh-server-name: SSH server configuration name"
    echo "  reverse-baseurl: Base URL for the reverse proxy"
    echo "  file-size-mb: Test file size in MB (optional, default: 200)"
    echo ""
    echo "The script will automatically:"
    echo "  - Parse the URL to construct SSH proxy and reverse proxy URLs"
    echo "  - Add SSH config if not present"
    echo "  - Deploy and test the speed benchmark"
    exit 1
fi

SSH_SERVER="$1"
INPUT_URL="$2"
FILE_SIZE_MB="${3:-200}" # Default to 200MB if not specified
CLEANUP=true

# Function to parse and construct URLs
parse_url() {
    local url="$1"

    # Extract components: https://6fd2b3f13a7deedb10480c914496e6daddefe1a6-8090.app.kvin.wang:12004/
    local protocol=$(echo "$url" | sed 's|://.*||')
    local rest=$(echo "$url" | sed 's|^[^:]*://||')
    local domain_port=$(echo "$rest" | sed 's|/.*||')
    local path=$(echo "$rest" | sed 's|^[^/]*||')

    # Extract domain and port
    if [[ "$domain_port" == *":"* ]]; then
        local domain=$(echo "$domain_port" | cut -d: -f1)
        local port=$(echo "$domain_port" | cut -d: -f2)
    else
        local domain="$domain_port"
        local port="443" # Default HTTPS port
    fi

    # Parse domain components - support any port number including single 's'
    if [[ "$domain" =~ ^([a-f0-9]+)-([0-9]+|s)\.(.+)$ ]]; then
        local hash="${BASH_REMATCH[1]}"
        local service_port="${BASH_REMATCH[2]}"
        local base_domain="${BASH_REMATCH[3]}"

        # Construct SSH proxy URLs
        SSH_PROXY_HOST="${hash}-22.${base_domain}"
        SSH_PROXY_PORT="$port"
        # Construct all three URL flavors for testing
        TLS_PASSTHROUGH_ENDPOINT="${protocol}://${hash}-s.${base_domain}:${port}${path}"
        TLS_TERMINATE_HTTP_ENDPOINT="${protocol}://${hash}-80.${base_domain}:${port}${path}"
        TLS_TERMINATE_GRPC_ENDPOINT="${protocol}://${hash}-50051g.${base_domain}:${port}${path}"
    else
        echo "❌ Error: Unable to parse the input URL"
        echo "   Expected format: <hash>-<port>.<domain>"
        exit 1
    fi
}

setup_ssh_config() {
    local ssh_host="$1"
    local proxy_host="$2"
    local proxy_port="$3"

    # Check if SSH config exists
    if ! grep -q "^Host $ssh_host$" ~/.ssh/config 2>/dev/null; then
        echo ""
        echo "⚠️  SSH configuration for '$ssh_host' not found in ~/.ssh/config"
        echo ""
        echo "Suggested configuration:"
        echo "Host $ssh_host"
        echo "    User root"
        echo "    ProxyCommand openssl s_client -quiet -connect $proxy_host:$proxy_port"
        echo ""
        # Check if running in interactive shell
        if [[ -t 0 ]]; then
            read -p "Add this configuration automatically? [y/N]: " -n 1 -r
            echo
            auto_add=$REPLY
        else
            # Non-interactive shell, default to yes
            echo "Non-interactive shell detected, automatically adding SSH configuration..."
            auto_add="y"
        fi

        if [[ $auto_add =~ ^[Yy]$ ]]; then
            # Backup existing config
            if [ -f ~/.ssh/config ]; then
                cp ~/.ssh/config ~/.ssh/config.backup.$(date +%s)
                echo "📋 Backed up existing SSH config"
            fi

            # Add new config
            echo "" >>~/.ssh/config
            echo "Host $ssh_host" >>~/.ssh/config
            echo "    User root" >>~/.ssh/config
            echo "    ProxyCommand openssl s_client -quiet -connect $proxy_host:$proxy_port" >>~/.ssh/config

            echo "✅ SSH configuration added successfully!"

            # Accept the server's host key automatically
            echo "🔑 Accepting server host key..."
            ssh-keyscan -H $proxy_host 2>/dev/null >>~/.ssh/known_hosts || true

        else
            echo "❌ SSH configuration required. Please add manually and run again."
            exit 1
        fi
    else
        echo "✅ SSH configuration for '$ssh_host' found"

        # Still try to accept host key if not already present
        echo "🔑 Ensuring server host key is accepted..."
        ssh-keyscan -H $proxy_host 2>/dev/null >>~/.ssh/known_hosts || true
    fi
}

echo "=============================================="
echo "Network Speed Test Benchmark"
echo "=============================================="

# Parse URL
echo "Parsed URL components:"
echo "  Input URL: $INPUT_URL"
parse_url "$INPUT_URL"
echo "  SSH Proxy: $SSH_PROXY_HOST:$SSH_PROXY_PORT"
echo "  Reverse URL: $REVERSE_URL"

setup_ssh_config "$SSH_SERVER" "$SSH_PROXY_HOST" "$SSH_PROXY_PORT"

echo ""
echo "SSH Server: $SSH_SERVER"
echo "SSH Proxy: $SSH_PROXY_HOST:$SSH_PROXY_PORT"
echo "Target URL: $REVERSE_URL"
echo "Client Test: $CLIENT_HOST:$CLIENT_PORT"
echo "=============================================="

# Test SSH connectivity
echo "🔍 Testing SSH connectivity..."
# First, automatically accept the SSH server's host key if needed
ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_SERVER" 'echo "SSH connection successful"' 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ SSH connection successful"
else
    echo "❌ Failed to connect to $SSH_SERVER via SSH. Please check:"
    echo "   1. SSH configuration is correct"
    echo "   2. Network connectivity to $SSH_PROXY_HOST:$SSH_PROXY_PORT"
    echo "   3. Target server is accessible"
    exit 1
fi

# Step 1: Deploy server components
echo "📦 Deploying server components to $SSH_SERVER..."

# Create remote directory and copy server files
ssh "$SSH_SERVER" "mkdir -p /tmp/speed-test-server"
scp -r server/* "$SSH_SERVER:/tmp/speed-test-server/"

# Setup and start services on remote server with Go version
ssh "$SSH_SERVER" <<EOF
set -e
cd /tmp/speed-test-server

echo "🔧 Setting up server environment..."

# Generate SSL certificates with correct domain
if [ ! -f certs/server.crt ]; then
    ./generate_cert.sh
fi

ls -la certs/

echo "📁 Creating ${FILE_SIZE_MB}MB test file..."
mkdir -p test-files uploads
if [ ! -f test-files/random-${FILE_SIZE_MB}mb.bin ]; then
    dd if=/dev/urandom of=test-files/random-${FILE_SIZE_MB}mb.bin bs=1M count=${FILE_SIZE_MB}
fi
# Copy test file to uploads directory for gRPC server access
cp test-files/random-${FILE_SIZE_MB}mb.bin uploads/random-${FILE_SIZE_MB}mb.bin
# Set proper permissions for nginx uploads
chmod 777 uploads

echo "🚀 Starting services with Docker Compose..."
# Stop any existing containers first
docker compose down 2>/dev/null || true

# Start the server
docker compose up -d --build

echo "⏳ Waiting for services to start..."
sleep 10

# Check service status
echo "📊 Service status:"
docker compose ps

# Test endpoints
echo "🔍 Testing local connectivity..."
curl -k -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://localhost:443/ || echo "HTTPS endpoint not ready yet"

# Check gRPC server logs
echo "📋 gRPC server status:"
docker compose logs grpc-server --tail 5

echo "✅ gRPC server setup complete!"
EOF

# Step 2: Collect server hardware info for report
echo ""
echo "📋 Collecting server hardware information..."

# Get server hardware info directly into variables
SERVER_CPU=$(ssh "$SSH_SERVER" "grep 'model name' /proc/cpuinfo | head -n 1 | cut -d: -f2 | sed 's/^[ \t]*//' || echo 'Unknown'")
SERVER_CPU_CORES=$(ssh "$SSH_SERVER" "nproc")
SERVER_MEMORY=$(ssh "$SSH_SERVER" "free -h | grep '^Mem:' | awk '{print \$2}'")
SERVER_DISK=$(ssh "$SSH_SERVER" "df -h / | tail -1 | awk '{print \$2}'")
SERVER_OS=$(ssh "$SSH_SERVER" "cat /etc/os-release | grep '^PRETTY_NAME' | cut -d= -f2 | tr -d '\"' || uname -a")
SERVER_KERNEL=$(ssh "$SSH_SERVER" "uname -r")
SERVER_DOCKER=$(ssh "$SSH_SERVER" "docker --version | cut -d' ' -f3 | tr -d ','")

# Get server hostname
SERVER_HOSTNAME=$(ssh "$SSH_SERVER" "hostname")

# Export server hardware info as environment variables
export SERVER_HW_CPU="$SERVER_CPU"
export SERVER_HW_CPU_CORES="$SERVER_CPU_CORES"
export SERVER_HW_MEMORY="$SERVER_MEMORY"
export SERVER_HW_DISK="$SERVER_DISK"
export SERVER_HW_OS="$SERVER_OS"
export SERVER_HW_KERNEL="$SERVER_KERNEL"
export SERVER_HW_DOCKER="$SERVER_DOCKER"

echo "✅ Hardware information collected"

# Step 3: Run client tests
echo ""
echo "🧪 Running client-side benchmarks..."

pushd client

# Build Go client if needed
if [ ! -f "benchmark" ]; then
    echo "📦 Building Go benchmark client..."
    ./build.sh
fi

# Create test file if it doesn't exist
if [ ! -f test-${FILE_SIZE_MB}mb.bin ]; then
    echo "📁 Creating local test file..."
    dd if=/dev/urandom of=test-${FILE_SIZE_MB}mb.bin bs=1M count=${FILE_SIZE_MB}
fi

# Run benchmarks against all URL flavors
echo "🏃 Running benchmarks against all URL flavors..."

echo ""
echo "Test Date: $(date -u +"%Y-%m-%d %H:%M:%S %z")"
echo ""
echo "🖥️  Server Info:"
echo "   Name: $SERVER_HOSTNAME"
echo "   CPU Cores: $SERVER_CPU_CORES"
echo "   Memory: $SERVER_MEMORY"
echo "   OS: $SERVER_OS"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "🔗 Testing TLS-passthrough endpoint"
echo "   HTTPS URL: $TLS_PASSTHROUGH_ENDPOINT"
echo "   gRPC URL: (defaults to HTTPS endpoint)"
echo "═══════════════════════════════════════════════════════════════"
echo "🚀 Running TLS-passthrough endpoint benchmark..."
if ./benchmark -https "$TLS_PASSTHROUGH_ENDPOINT" -size ${FILE_SIZE_MB}; then
    echo "✅ TLS-passthrough endpoint test completed successfully"
else
    echo "❌ TLS-passthrough endpoint test failed"
fi
echo "═══════════════════════════════════════════════════════════════"
echo "🔗 Testing TLS-terminate endpoints"
echo "   HTTPS URL: $TLS_TERMINATE_HTTP_ENDPOINT"
echo "   gRPC URL: $TLS_TERMINATE_GRPC_ENDPOINT"
echo "═══════════════════════════════════════════════════════════════"
echo "🚀 Running TLS-terminate endpoint benchmark..."
if ./benchmark -https "$TLS_TERMINATE_HTTP_ENDPOINT" -grpc "$TLS_TERMINATE_GRPC_ENDPOINT" -size ${FILE_SIZE_MB}; then
    echo "✅ TLS-terminate endpoint test completed successfully"
else
    echo "❌ TLS-terminate endpoint test failed"
fi
echo "═══════════════════════════════════════════════════════════════"
echo "✅ All URL flavor tests completed!"
echo "═══════════════════════════════════════════════════════════════"
popd

# Step 3: Cleanup and summary
echo ""
echo "🧹 Cleaning up remote server..."

if [ "$CLEANUP" = true ]; then
    ssh "$SSH_SERVER" <<'EOF'
cd /tmp/speed-test-server
echo "🛑 Stopping services..."
docker compose down -v
echo "🗑️  Removing temporary files..."
rm -rf /tmp/speed-test-server
rm -rf ./client/*.bin
echo "✅ Cleanup complete!"
EOF

else
    echo "⚠️  Cleanup disabled for debugging - server left running"
fi

echo ""
echo "✅ Benchmark complete!"
