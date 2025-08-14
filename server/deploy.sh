#!/bin/bash

# Generate SSL certificates if they don't exist
if [ ! -f certs/server.crt ]; then
    ./generate_cert.sh
fi

# Stop any existing containers
docker compose down

# Build and start the server
docker compose up --build -d

echo "gRPC server is running!"
echo "HTTPS endpoint: https://localhost:443"
echo "gRPC endpoint: localhost:443"