package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/credentials/insecure"

	pb "gwbench-client/proto"
)

const (
	chunkSize = 1024 * 1024 // 1MB chunks
)

func createConnection(host string, useSSL bool) (*grpc.ClientConn, error) {
	opts := []grpc.DialOption{
		grpc.WithDefaultCallOptions(
			grpc.MaxCallRecvMsgSize(500*1024*1024),
			grpc.MaxCallSendMsgSize(500*1024*1024),
		),
	}

	if useSSL {
		// Use insecure TLS for self-signed certificates
		config := &tls.Config{
			InsecureSkipVerify: true,
		}
		creds := credentials.NewTLS(config)
		opts = append(opts, grpc.WithTransportCredentials(creds))
	} else {
		opts = append(opts, grpc.WithTransportCredentials(insecure.NewCredentials()))
	}

	conn, err := grpc.Dial(host, opts...)
	if err != nil {
		return nil, fmt.Errorf("failed to connect: %v", err)
	}

	return conn, nil
}

func uploadFile(client pb.FileServiceClient, filePath string) (time.Duration, float64, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return 0, 0, fmt.Errorf("failed to open file: %v", err)
	}
	defer file.Close()

	fileInfo, err := file.Stat()
	if err != nil {
		return 0, 0, fmt.Errorf("failed to get file info: %v", err)
	}

	filename := filepath.Base(filePath)
	fileSize := fileInfo.Size()

	fmt.Printf("Uploading %s (%.1f MB)\n", filename, float64(fileSize)/(1024*1024))

	stream, err := client.UploadFile(context.Background())
	if err != nil {
		return 0, 0, fmt.Errorf("failed to create upload stream: %v", err)
	}

	startTime := time.Now()
	buffer := make([]byte, chunkSize)
	var bytesSent int64

	for {
		n, err := file.Read(buffer)
		if err == io.EOF {
			break
		}
		if err != nil {
			return 0, 0, fmt.Errorf("failed to read file: %v", err)
		}

		chunk := &pb.FileChunk{
			Filename:  filename,
			Data:      buffer[:n],
			TotalSize: fileSize,
		}

		if err := stream.Send(chunk); err != nil {
			return 0, 0, fmt.Errorf("failed to send chunk: %v", err)
		}

		bytesSent += int64(n)

		// Progress reporting
		if bytesSent%(50*1024*1024) == 0 {
			fmt.Printf("  Progress: %.0fMB / %.0fMB\n", 
				float64(bytesSent)/(1024*1024), 
				float64(fileSize)/(1024*1024))
		}
	}

	response, err := stream.CloseAndRecv()
	if err != nil {
		return 0, 0, fmt.Errorf("failed to close stream: %v", err)
	}

	duration := time.Since(startTime)
	speedMBps := float64(fileSize) / duration.Seconds() / (1024 * 1024)

	fmt.Printf("Response: %s\n", response.Message)
	fmt.Printf("Time: %.2f seconds\n", duration.Seconds())
	fmt.Printf("Speed: %.2f MB/s\n", speedMBps)

	return duration, speedMBps, nil
}

func downloadFile(client pb.FileServiceClient, filename, outputPath string) (time.Duration, float64, error) {
	fmt.Printf("Downloading %s\n", filename)

	request := &pb.DownloadRequest{
		Filename: filename,
	}

	stream, err := client.DownloadFile(context.Background(), request)
	if err != nil {
		return 0, 0, fmt.Errorf("failed to create download stream: %v", err)
	}

	file, err := os.Create(outputPath)
	if err != nil {
		return 0, 0, fmt.Errorf("failed to create output file: %v", err)
	}
	defer file.Close()

	startTime := time.Now()
	var totalBytes int64

	for {
		chunk, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			return 0, 0, fmt.Errorf("failed to receive chunk: %v", err)
		}

		n, err := file.Write(chunk.Data)
		if err != nil {
			return 0, 0, fmt.Errorf("failed to write chunk: %v", err)
		}

		totalBytes += int64(n)

		// Progress reporting
		if totalBytes%(50*1024*1024) == 0 {
			fmt.Printf("  Progress: %.0fMB\n", float64(totalBytes)/(1024*1024))
		}
	}

	duration := time.Since(startTime)
	speedMBps := float64(totalBytes) / duration.Seconds() / (1024 * 1024)

	fmt.Printf("Downloaded: %.1f MB\n", float64(totalBytes)/(1024*1024))
	fmt.Printf("Time: %.2f seconds\n", duration.Seconds())
	fmt.Printf("Speed: %.2f MB/s\n", speedMBps)

	return duration, speedMBps, nil
}

// Remove main function - this is now a library