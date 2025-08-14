#!/bin/bash

echo "📦 Building Go benchmark client using Docker..."

# Create a temporary Dockerfile for building the client
cat > Dockerfile.client << 'EOF'
FROM golang:1.22-alpine AS builder

# Install protoc and other dependencies
RUN apk add --no-cache git protobuf protobuf-dev

WORKDIR /app

# Copy go.mod and go.sum first for better caching
COPY go.mod go.sum* ./
RUN go mod download

# Install protoc plugins
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.2
RUN go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.4.0

# Copy source files
COPY . .

# Create proto directory and generate Go code from proto file
RUN mkdir -p proto && \
    protoc --go_out=proto --go_opt=paths=source_relative \
           --go-grpc_out=proto --go-grpc_opt=paths=source_relative \
           file_service.proto

# Build the benchmark application
RUN go build -o benchmark ./benchmark.go ./grpc_client.go ./http_client.go

# Use a minimal image for the final stage
FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /app
COPY --from=builder /app/benchmark .
EOF

# Build the Docker image and extract the binary
docker build -f Dockerfile.client -t go-benchmark-builder . || {
    echo "❌ Failed to build Docker image"
    rm -f Dockerfile.client
    exit 1
}

# Create a temporary container and copy the binary out
CONTAINER_ID=$(docker create go-benchmark-builder)
docker cp "$CONTAINER_ID:/app/benchmark" ./benchmark || {
    echo "❌ Failed to extract benchmark binary"
    docker rm "$CONTAINER_ID"
    rm -f Dockerfile.client
    exit 1
}

# Clean up
docker rm "$CONTAINER_ID"
docker rmi go-benchmark-builder
rm -f Dockerfile.client

echo "✅ Benchmark client built successfully using Docker"
