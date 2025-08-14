package main

import (
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"path/filepath"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	pb "gwbench/proto"
)

const (
	port       = ":50051"
	uploadDir  = "/app/uploads"
	chunkSize  = 4 * 1024 * 1024 // 4MB chunks for better performance
)

type fileServer struct {
	pb.UnimplementedFileServiceServer
}

func (s *fileServer) UploadFile(stream pb.FileService_UploadFileServer) error {
	log.Println("UploadFile called")
	
	var filename string
	var file *os.File
	var totalBytes int64
	
	defer func() {
		if file != nil {
			file.Close()
		}
	}()
	
	for {
		chunk, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			return status.Errorf(codes.Internal, "Failed to receive chunk: %v", err)
		}
		
		// First chunk - create file
		if file == nil {
			filename = chunk.Filename
			filepath := filepath.Join(uploadDir, filename)
			
			file, err = os.Create(filepath)
			if err != nil {
				return status.Errorf(codes.Internal, "Failed to create file: %v", err)
			}
			
			log.Printf("Receiving file: %s\n", filename)
		}
		
		// Write chunk directly to disk
		n, err := file.Write(chunk.Data)
		if err != nil {
			return status.Errorf(codes.Internal, "Failed to write chunk: %v", err)
		}
		
		totalBytes += int64(n)
		
		// Progress logging
		if totalBytes%(10*1024*1024) == 0 {
			log.Printf("Received %.1f MB\n", float64(totalBytes)/(1024*1024))
		}
	}
	
	log.Printf("File saved: %s (%d bytes)\n", filename, totalBytes)
	
	return stream.SendAndClose(&pb.UploadResponse{
		Message:       fmt.Sprintf("File %s uploaded successfully", filename),
		BytesReceived: totalBytes,
	})
}

func (s *fileServer) DownloadFile(req *pb.DownloadRequest, stream pb.FileService_DownloadFileServer) error {
	log.Printf("DownloadFile called for: %s\n", req.Filename)
	
	filepath := filepath.Join(uploadDir, req.Filename)
	
	file, err := os.Open(filepath)
	if err != nil {
		return status.Errorf(codes.NotFound, "File %s not found", req.Filename)
	}
	defer file.Close()
	
	buffer := make([]byte, chunkSize)
	var bytesSent int64
	
	for {
		n, err := file.Read(buffer)
		if err == io.EOF {
			break
		}
		if err != nil {
			return status.Errorf(codes.Internal, "Failed to read file: %v", err)
		}
		
		chunk := &pb.FileChunk{
			Filename: req.Filename,
			Data:     buffer[:n],
		}
		
		if err := stream.Send(chunk); err != nil {
			return status.Errorf(codes.Internal, "Failed to send chunk: %v", err)
		}
		
		bytesSent += int64(n)
		
		// Progress logging
		if bytesSent%(10*1024*1024) == 0 {
			log.Printf("Sent %.1f MB\n", float64(bytesSent)/(1024*1024))
		}
	}
	
	log.Printf("Download complete: %d bytes sent\n", bytesSent)
	return nil
}

func main() {
	// Create upload directory
	if err := os.MkdirAll(uploadDir, 0755); err != nil {
		log.Fatalf("Failed to create upload directory: %v", err)
	}
	
	log.Printf("FileService initialized with upload_dir: %s\n", uploadDir)
	
	lis, err := net.Listen("tcp", port)
	if err != nil {
		log.Fatalf("Failed to listen: %v", err)
	}
	
	// Create gRPC server with increased message size limits
	s := grpc.NewServer(
		grpc.MaxRecvMsgSize(500*1024*1024), // 500MB
		grpc.MaxSendMsgSize(500*1024*1024), // 500MB
	)
	
	pb.RegisterFileServiceServer(s, &fileServer{})
	
	log.Printf("Server listening on %s\n", port)
	
	if err := s.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}