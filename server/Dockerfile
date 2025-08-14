FROM golang:1.22-alpine AS builder

# Install dependencies
RUN apk add --no-cache git protobuf protobuf-dev

WORKDIR /app

# Copy go mod files
COPY go.mod go.sum* ./
RUN go mod download

# Install protoc plugins with compatible versions
RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.2 && \
    go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.4.0

# Copy source files
COPY file_service.proto .
COPY server.go .

# Generate proto files
RUN mkdir -p proto && \
    protoc --go_out=proto --go_opt=paths=source_relative \
           --go-grpc_out=proto --go-grpc_opt=paths=source_relative \
           file_service.proto

# Build the binary
RUN go build -o server .

# Final stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /app

# Create uploads directory
RUN mkdir -p /app/uploads

# Copy the binary from builder
COPY --from=builder /app/server .

# Create a 200MB test file
RUN dd if=/dev/urandom of=/app/uploads/random-200mb.bin bs=1024 count=204800

EXPOSE 50051

CMD ["./server"]