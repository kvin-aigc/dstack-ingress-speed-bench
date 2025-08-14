#!/usr/bin/env python3
"""
gRPC Speed Test Client
Tests upload and download speeds using gRPC protocol
"""

import grpc
import time
import os
import sys
import argparse
import subprocess
import ssl

# Import protobuf definitions (generated at runtime)
def generate_protobuf():
    """Generate Python files from proto definition"""
    import grpc_tools.protoc
    grpc_tools.protoc.main([
        'grpc_tools.protoc',
        '--python_out=.',
        '--grpc_python_out=.',
        '-I.',
        'file_service.proto'
    ])

try:
    import file_service_pb2
    import file_service_pb2_grpc
except ImportError:
    generate_protobuf()
    import file_service_pb2
    import file_service_pb2_grpc

def create_channel(host, use_ssl=True):
    """Create gRPC channel with optional SSL"""
    options = [
        ('grpc.max_send_message_length', 500 * 1024 * 1024),
        ('grpc.max_receive_message_length', 500 * 1024 * 1024),
    ]
    
    if use_ssl:
        # Try to fetch server certificate for self-signed certs
        cert_file = '/tmp/server.crt'
        try:
            result = subprocess.run(
                ['sh', '-c', f'echo | openssl s_client -connect {host} -showcerts 2>/dev/null | openssl x509 -outform PEM'],
                capture_output=True,
                text=True,
                timeout=5
            )
            with open(cert_file, 'w') as f:
                f.write(result.stdout)
            
            with open(cert_file, 'rb') as f:
                root_certificates = f.read()
            
            credentials = grpc.ssl_channel_credentials(root_certificates=root_certificates)
        except:
            # Fall back to default SSL
            credentials = grpc.ssl_channel_credentials()
        
        channel = grpc.secure_channel(host, credentials, options=options)
    else:
        channel = grpc.insecure_channel(host, options=options)
    
    return channel

def upload_file(stub, filepath, filename=None):
    """Upload file via gRPC streaming"""
    if not filename:
        filename = os.path.basename(filepath)
    
    chunk_size = 1024 * 1024  # 1MB chunks
    file_size = os.path.getsize(filepath)
    
    def generate_chunks():
        with open(filepath, 'rb') as f:
            bytes_sent = 0
            while True:
                chunk_data = f.read(chunk_size)
                if not chunk_data:
                    break
                bytes_sent += len(chunk_data)
                if bytes_sent % (50 * 1024 * 1024) == 0:
                    print(f"  Progress: {bytes_sent / (1024*1024):.0f}MB / {file_size / (1024*1024):.0f}MB")
                yield file_service_pb2.FileChunk(
                    filename=filename,
                    data=chunk_data,
                    total_size=file_size
                )
    
    print(f"Uploading {filename} ({file_size / (1024*1024):.1f} MB)")
    
    start_time = time.time()
    response = stub.UploadFile(generate_chunks(), timeout=300)
    end_time = time.time()
    
    duration = end_time - start_time
    speed_mbps = (file_size / duration) / (1024 * 1024)
    
    print(f"Response: {response.message}")
    print(f"Time: {duration:.2f} seconds")
    print(f"Speed: {speed_mbps:.2f} MB/s")
    
    return duration, speed_mbps, True

def download_file(stub, filename, output_path):
    """Download file via gRPC streaming"""
    request = file_service_pb2.DownloadRequest(filename=filename)
    
    print(f"Downloading {filename}")
    
    start_time = time.time()
    total_bytes = 0
    
    with open(output_path, 'wb') as f:
        for chunk in stub.DownloadFile(request, timeout=300):
            f.write(chunk.data)
            total_bytes += len(chunk.data)
            if total_bytes % (50 * 1024 * 1024) == 0:
                print(f"  Progress: {total_bytes / (1024*1024):.0f}MB")
    
    end_time = time.time()
    duration = end_time - start_time
    speed_mbps = (total_bytes / duration) / (1024 * 1024)
    
    print(f"Downloaded: {total_bytes / (1024*1024):.1f} MB")
    print(f"Time: {duration:.2f} seconds")
    print(f"Speed: {speed_mbps:.2f} MB/s")
    
    return duration, speed_mbps, True

def main():
    parser = argparse.ArgumentParser(description='gRPC Speed Test')
    parser.add_argument('action', choices=['upload', 'download', 'both'])
    parser.add_argument('--host', required=True, help='gRPC server host:port')
    parser.add_argument('--file', help='File to upload or filename to download')
    parser.add_argument('--output', help='Output path for download')
    parser.add_argument('--no-ssl', action='store_true', help='Use insecure connection')
    
    args = parser.parse_args()
    
    channel = create_channel(args.host, use_ssl=not args.no_ssl)
    stub = file_service_pb2_grpc.FileServiceStub(channel)
    
    try:
        if args.action in ['upload', 'both']:
            if not args.file or not os.path.exists(args.file):
                print("Error: File not found for upload")
                sys.exit(1)
            upload_file(stub, args.file)
        
        if args.action in ['download', 'both']:
            if not args.file:
                print("Error: Filename required for download")
                sys.exit(1)
            output = args.output or f"downloaded_{args.file}"
            download_file(stub, args.file, output)
    
    except grpc.RpcError as e:
        print(f"gRPC Error: {e.code()}: {e.details()}")
        sys.exit(1)

if __name__ == '__main__':
    main()