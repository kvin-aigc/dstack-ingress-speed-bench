import grpc
from concurrent import futures
import file_service_pb2
import file_service_pb2_grpc
import os
import time
import sys

class FileService(file_service_pb2_grpc.FileServiceServicer):
    def __init__(self):
        self.upload_dir = "/app/uploads"
        os.makedirs(self.upload_dir, exist_ok=True)
        print(f"FileService initialized with upload_dir: {self.upload_dir}", flush=True)

    def UploadFile(self, request_iterator, context):
        print("UploadFile called", flush=True)
        filename = None
        total_bytes = 0
        file_data = b""
        
        for chunk in request_iterator:
            if filename is None:
                filename = chunk.filename
                print(f"Receiving file: {filename}", flush=True)
            file_data += chunk.data
            total_bytes += len(chunk.data)
            if total_bytes % (10 * 1024 * 1024) == 0:
                print(f"Received {total_bytes / (1024*1024):.1f} MB", flush=True)
        
        if filename:
            filepath = os.path.join(self.upload_dir, filename)
            with open(filepath, 'wb') as f:
                f.write(file_data)
            print(f"File saved: {filepath} ({total_bytes} bytes)", flush=True)
        
        return file_service_pb2.UploadResponse(
            message=f"File {filename} uploaded successfully",
            bytes_received=total_bytes
        )

    def DownloadFile(self, request, context):
        print(f"DownloadFile called for: {request.filename}", flush=True)
        filepath = os.path.join(self.upload_dir, request.filename)
        
        if not os.path.exists(filepath):
            context.set_code(grpc.StatusCode.NOT_FOUND)
            context.set_details(f"File {request.filename} not found")
            return
        
        chunk_size = 64 * 1024  # 64KB chunks
        bytes_sent = 0
        with open(filepath, 'rb') as f:
            while True:
                chunk_data = f.read(chunk_size)
                if not chunk_data:
                    break
                bytes_sent += len(chunk_data)
                if bytes_sent % (10 * 1024 * 1024) == 0:
                    print(f"Sent {bytes_sent / (1024*1024):.1f} MB", flush=True)
                yield file_service_pb2.FileChunk(
                    filename=request.filename,
                    data=chunk_data
                )
        print(f"Download complete: {bytes_sent} bytes sent", flush=True)

def serve():
    print("Starting gRPC server...", flush=True)
    server = grpc.server(
        futures.ThreadPoolExecutor(max_workers=10),
        options=[
            ('grpc.max_send_message_length', 500 * 1024 * 1024),
            ('grpc.max_receive_message_length', 500 * 1024 * 1024),
        ]
    )
    file_service_pb2_grpc.add_FileServiceServicer_to_server(FileService(), server)
    listen_addr = '[::]:50051'
    server.add_insecure_port(listen_addr)
    
    print(f"Server listening on {listen_addr}", flush=True)
    server.start()
    print("Server started successfully", flush=True)
    
    try:
        server.wait_for_termination()
    except KeyboardInterrupt:
        print("Server stopped", flush=True)
        server.stop(0)

if __name__ == '__main__':
    serve()