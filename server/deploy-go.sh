#!/bin/bash

# Generate SSL certificates if they don't exist
if [ ! -f certs/server.crt ]; then
    ./generate_cert.sh
fi

# Stop any existing containers
docker-compose -f docker-compose.go.yml down

# Build and start the Go version
docker-compose -f docker-compose.go.yml up --build -d

echo "Go gRPC server is running!"
echo "HTTPS endpoint: https://localhost:443"
echo "gRPC endpoint: localhost:443"