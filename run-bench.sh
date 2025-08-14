#!/bin/bash

# Network Speed Test Benchmark Runner
# Usage: ./run-bench.sh <ssh-server-name> <reverse-baseurl>
# Example: ./run-bench.sh dev1 https://6fd2b3f13a7deedb10480c914496e6daddefe1a6-8090.app.kvin.wang:12004/

set -e

if [ $# -ne 2 ]; then
    echo "Usage: $0 <ssh-server-name> <reverse-baseurl>"
    echo "Example: $0 dev1 https://6fd2b3f13a7deedb10480c914496e6daddefe1a6-8090.app.kvin.wang:12004/"
    echo ""
    echo "The script will automatically:"
    echo "  - Parse the URL to construct SSH proxy and reverse proxy URLs"
    echo "  - Add SSH config if not present"
    echo "  - Deploy and test the speed benchmark"
    exit 1
fi

SSH_SERVER="$1"
INPUT_URL="$2"
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

        # Construct URLs
        SSH_PROXY_HOST="${hash}-22.${base_domain}"
        SSH_PROXY_PORT="$port"
        REVERSE_URL="${protocol}://${hash}-s.${base_domain}:${port}/"

        echo "Parsed URL components:"
        echo "  Input URL: $url"
        echo "  SSH Proxy: $SSH_PROXY_HOST:$SSH_PROXY_PORT"
        echo "  Reverse URL: $REVERSE_URL"
        return 0
    else
        echo "❌ Error: Cannot parse URL format. Expected format:"
        echo "   https://HASH-PORT.DOMAIN:EXTERNAL_PORT/"
        echo "   Examples:"
        echo "     https://6fd2b3f13a7deedb10480c914496e6daddefe1a6-8090.app.kvin.wang:12004/"
        echo "     https://4437f8170998567db7a46672757ef1c5810533bf-3000.dstack-prod10.phala.network/"
        return 1
    fi
}

# Function to check and setup SSH config
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
        read -p "Add this configuration automatically? [y/N]: " -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
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

# Parse the input URL
echo "=============================================="
echo "Network Speed Test Benchmark"
echo "=============================================="

if ! parse_url "$INPUT_URL"; then
    exit 1
fi

# Setup SSH configuration
setup_ssh_config "$SSH_SERVER" "$SSH_PROXY_HOST" "$SSH_PROXY_PORT"

REVERSE_URL="$REVERSE_URL"

# Extract host and port from reverse URL for client testing
CLIENT_HOST=$(echo "$REVERSE_URL" | sed 's|https\?://||' | sed 's|/.*||' | cut -d: -f1)
CLIENT_PORT=$(echo "$REVERSE_URL" | sed 's|https\?://||' | sed 's|/.*||' | cut -d: -f2)

# Default to 443 if no port specified
if [ "$CLIENT_HOST" = "$CLIENT_PORT" ]; then
    CLIENT_PORT=443
fi

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
    echo "❌ SSH connection failed. Please check:"
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

# Setup and start services on remote server
ssh "$SSH_SERVER" <<EOF
set -e
cd /tmp/speed-test-server

echo "🔧 Setting up server environment..."

# Generate SSL certificates with correct domain
chmod +x generate_cert.sh
./generate_cert.sh "$CLIENT_HOST"

# Create test files directory and sample file
mkdir -p test-files uploads
# Set proper permissions for nginx container (uid 101, gid 101)
chmod 777 uploads
if [ ! -f test-files/random-200mb.bin ]; then
    echo "📁 Creating 200MB test file..."
    dd if=/dev/urandom of=test-files/random-200mb.bin bs=1M count=200 2>/dev/null
fi
# Copy test file to uploads for gRPC download testing
cp test-files/random-200mb.bin uploads/

# Stop any existing containers
docker compose down 2>/dev/null || true

# Start services
echo "🚀 Starting services with Docker Compose..."
docker compose up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 15

# Check status
echo "📊 Service status:"
docker compose ps

# Test local connectivity
echo "🔍 Testing local connectivity..."
curl -k -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://localhost:443/ || echo "HTTPS endpoint not ready yet"

# Check gRPC server logs
echo "📋 gRPC server status:"
docker compose logs grpc-server --tail 5

echo "✅ Server setup complete!"
EOF

# Step 2: Collect server hardware info for report
echo ""
echo "📋 Collecting server hardware information..."

# Get server hardware info directly into variables
SERVER_CPU=$(ssh "$SSH_SERVER" "grep 'model name' /proc/cpuinfo | head -n 1 | cut -d: -f2 | sed 's/^[ \t]*//' || echo 'Unknown'")
SERVER_CPU_CORES=$(ssh "$SSH_SERVER" "nproc")
SERVER_MEMORY=$(ssh "$SSH_SERVER" "free -h | grep '^Mem:' | awk '{print \$2}'")
SERVER_DISK=$(ssh "$SSH_SERVER" "df -h / | tail -n 1 | awk '{print \$2}'")
SERVER_OS=$(ssh "$SSH_SERVER" "cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"'")
SERVER_KERNEL=$(ssh "$SSH_SERVER" "uname -r")
SERVER_DOCKER=$(ssh "$SSH_SERVER" "docker --version | cut -d' ' -f3 | tr -d ','")

echo "✅ Hardware information collected"

# Step 3: Run client tests
echo ""
echo "🧪 Running client-side benchmarks..."

cd client/

# Ensure dependencies are installed
if [ ! -d "venv" ]; then
    echo "📦 Setting up Python virtual environment..."
    python3 -m venv venv
fi

source venv/bin/activate
pip install -q -r requirements.txt

# Generate protobuf files if needed
if [ ! -f "file_service_pb2.py" ]; then
    echo "🔧 Generating protobuf files..."
    python -m grpc_tools.protoc --python_out=. --grpc_python_out=. -I. file_service.proto
fi

# Create local test file if needed
if [ ! -f "test-200mb.bin" ]; then
    echo "📁 Creating local test file..."
    dd if=/dev/urandom of=test-200mb.bin bs=1M count=200 2>/dev/null
fi

# Run the complete benchmark with hardware info
echo "🏃 Running benchmark against $CLIENT_HOST:$CLIENT_PORT..."
export SERVER_HW_CPU="$SERVER_CPU"
export SERVER_HW_CPU_CORES="$SERVER_CPU_CORES"
export SERVER_HW_MEMORY="$SERVER_MEMORY"
export SERVER_HW_DISK="$SERVER_DISK"
export SERVER_HW_OS="$SERVER_OS"
export SERVER_HW_KERNEL="$SERVER_KERNEL"
export SERVER_HW_DOCKER="$SERVER_DOCKER"
echo ""
echo "🔗 Test endpoint: $REVERSE_URL"
echo "Test Date: $(date +'%Y-%m-%d %H:%M:%S %z')"
echo ""
echo "🖥️  Server Info:"
echo "   Name: $SSH_SERVER"
echo "   CPU Cores: $SERVER_CPU_CORES"
echo "   Memory: $SERVER_MEMORY"
echo "   OS: $SERVER_OS"
python benchmark.py --server "$CLIENT_HOST" --port "$CLIENT_PORT" --size 200

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
echo "✅ Cleanup complete!"
EOF

else
    echo "⚠️  Cleanup disabled for debugging - server left running"
fi

echo ""
echo "=============================================="
echo "✅ Benchmark Complete!"
echo "=============================================="
echo "📊 Results saved to benchmark_results.json"
echo "📋 Check the detailed report above"
echo "=============================================="
