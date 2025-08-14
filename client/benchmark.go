package main

import (
	"crypto/tls"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"

	pb "gwbench-client/proto"
)

type TestResult struct {
	SpeedMBps float64       `json:"speed_mbps"`
	Duration  time.Duration `json:"duration"`
	Success   bool          `json:"success"`
}

type BenchmarkResults struct {
	Timestamp      time.Time             `json:"timestamp"`
	FileSizeMB     int                   `json:"file_size_mb"`
	ServerHardware map[string]string     `json:"server_hardware"`
	HTTP           map[string]TestResult `json:"http"`
	GRPC           map[string]TestResult `json:"grpc"`
}

func createTestFile(sizeMB int) string {
	filename := fmt.Sprintf("test-%dmb.bin", sizeMB)
	if _, err := os.Stat(filename); err == nil {
		return filename // File already exists
	}

	fmt.Printf("Creating %dMB test file...\n", sizeMB)

	file, err := os.Create(filename)
	if err != nil {
		fmt.Printf("Failed to create test file: %v\n", err)
		os.Exit(1)
	}
	defer file.Close()

	// Create file with pseudo-random data
	buffer := make([]byte, 1024*1024) // 1MB buffer
	for i := range buffer {
		buffer[i] = byte(i % 256)
	}

	for i := 0; i < sizeMB; i++ {
		if _, err := file.Write(buffer); err != nil {
			fmt.Printf("Failed to write test file: %v\n", err)
			os.Exit(1)
		}
	}

	return filename
}

func testHTTP(baseURL, testFile string, fileSizeMB int) map[string]TestResult {
	results := make(map[string]TestResult)

	// HTTP Upload Test
	fmt.Println("\n=== HTTP Upload Test ===")
	duration, speed, err := uploadHTTP(baseURL, testFile)
	results["upload"] = TestResult{
		SpeedMBps: speed,
		Duration:  duration,
		Success:   err == nil,
	}
	if err != nil {
		fmt.Printf("HTTP upload error: %v\n", err)
	}

	// HTTP Download Test
	fmt.Println("\n=== HTTP Download Test ===")
	downloadFileName := fmt.Sprintf("random-%dmb.bin", fileSizeMB)
	duration, speed, err = downloadHTTP(baseURL, downloadFileName, "downloaded-http.bin")
	results["download"] = TestResult{
		SpeedMBps: speed,
		Duration:  duration,
		Success:   err == nil,
	}
	if err != nil {
		fmt.Printf("HTTP download error: %v\n", err)
	}

	return results
}

func testGRPC(host, testFile string, fileSizeMB int) map[string]TestResult {
	results := make(map[string]TestResult)

	// Create gRPC connection
	config := &tls.Config{InsecureSkipVerify: true}
	creds := credentials.NewTLS(config)

	opts := []grpc.DialOption{
		grpc.WithTransportCredentials(creds),
		grpc.WithDefaultCallOptions(
			grpc.MaxCallRecvMsgSize(500*1024*1024),
			grpc.MaxCallSendMsgSize(500*1024*1024),
		),
	}

	conn, err := grpc.Dial(host, opts...)
	if err != nil {
		fmt.Printf("Failed to connect to gRPC server: %v\n", err)
		results["upload"] = TestResult{Success: false}
		results["download"] = TestResult{Success: false}
		return results
	}
	defer conn.Close()

	client := pb.NewFileServiceClient(conn)

	// gRPC Upload Test
	fmt.Println("\n=== gRPC Upload Test ===")
	duration, speed, err := uploadFile(client, testFile)
	results["upload"] = TestResult{
		SpeedMBps: speed,
		Duration:  duration,
		Success:   err == nil,
	}
	if err != nil {
		fmt.Printf("gRPC upload error: %v\n", err)
	}

	// gRPC Download Test
	fmt.Println("\n=== gRPC Download Test ===")
	downloadFileName := fmt.Sprintf("random-%dmb.bin", fileSizeMB)
	duration, speed, err = downloadFile(client, downloadFileName, "downloaded-grpc.bin")
	results["download"] = TestResult{
		SpeedMBps: speed,
		Duration:  duration,
		Success:   err == nil,
	}
	if err != nil {
		fmt.Printf("gRPC download error: %v\n", err)
	}

	return results
}

func loadServerHardwareInfo() map[string]string {
	hwInfo := map[string]string{
		"CPU":       getEnvOrDefault("SERVER_HW_CPU", "Unknown"),
		"CPU_Cores": getEnvOrDefault("SERVER_HW_CPU_CORES", "Unknown"),
		"Memory":    getEnvOrDefault("SERVER_HW_MEMORY", "Unknown"),
		"Disk":      getEnvOrDefault("SERVER_HW_DISK", "Unknown"),
		"OS":        getEnvOrDefault("SERVER_HW_OS", "Unknown"),
		"Kernel":    getEnvOrDefault("SERVER_HW_KERNEL", "Unknown"),
		"Docker":    getEnvOrDefault("SERVER_HW_DOCKER", "Unknown"),
	}

	// Check if any hardware info was provided
	hasInfo := false
	for _, value := range hwInfo {
		if value != "Unknown" {
			hasInfo = true
			break
		}
	}

	if !hasInfo {
		return map[string]string{"Error": "Hardware info not available"}
	}

	return hwInfo
}

func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func generateReport(httpResults, grpcResults map[string]TestResult, fileSizeMB int) {
	serverHW := loadServerHardwareInfo()

	fmt.Printf("\n%s\n", strings.Repeat("=", 60))
	fmt.Printf("BENCHMARK RESULTS - %dMB File\n", fileSizeMB)
	fmt.Printf("%s\n", strings.Repeat("=", 60))

	// Print table header
	fmt.Printf("%-12s %-13s %16s %12s %10s\n", "Protocol", "Operation", "Speed (MB/s)", "Time (s)", "Status")
	fmt.Printf("%s\n", strings.Repeat("=", 70))

	// HTTP results
	if upload, ok := httpResults["upload"]; ok {
		status := "✅"
		if !upload.Success {
			status = "❌"
		}
		fmt.Printf("%-12s %-13s %16.2f %12.2f %10s\n",
			"HTTPS", "Upload", upload.SpeedMBps, upload.Duration.Seconds(), status)
	}

	if download, ok := httpResults["download"]; ok {
		status := "✅"
		if !download.Success {
			status = "❌"
		}
		fmt.Printf("%-12s %-13s %16.2f %12.2f %10s\n",
			"HTTPS", "Download", download.SpeedMBps, download.Duration.Seconds(), status)
	}

	// gRPC results
	if upload, ok := grpcResults["upload"]; ok {
		status := "✅"
		if !upload.Success {
			status = "❌"
		}
		fmt.Printf("%-12s %-13s %16.2f %12.2f %10s\n",
			"gRPC", "Upload", upload.SpeedMBps, upload.Duration.Seconds(), status)
	}

	if download, ok := grpcResults["download"]; ok {
		status := "✅"
		if !download.Success {
			status = "❌"
		}
		fmt.Printf("%-12s %-13s %16.2f %12.2f %10s\n",
			"gRPC", "Download", download.SpeedMBps, download.Duration.Seconds(), status)
	}

	// Save results to JSON
	results := BenchmarkResults{
		Timestamp:      time.Now(),
		FileSizeMB:     fileSizeMB,
		ServerHardware: serverHW,
		HTTP:           httpResults,
		GRPC:           grpcResults,
	}

	jsonData, err := json.MarshalIndent(results, "", "  ")
	if err != nil {
		fmt.Printf("Failed to marshal results: %v\n", err)
		return
	}

	if err := os.WriteFile("benchmark_results.json", jsonData, 0644); err != nil {
		fmt.Printf("Failed to save results: %v\n", err)
		return
	}

	fmt.Println("\nResults saved to benchmark_results.json")
}

func main() {
	var (
		server   = flag.String("server", "", "Server address (required)")
		port     = flag.Int("port", 443, "Server port")
		size     = flag.Int("size", 200, "Test file size in MB")
		skipHTTP = flag.Bool("skip-http", false, "Skip HTTP tests")
		skipGRPC = flag.Bool("skip-grpc", false, "Skip gRPC tests")
	)
	flag.Parse()

	if *server == "" {
		fmt.Println("Error: --server is required")
		flag.Usage()
		os.Exit(1)
	}

	// Create test file
	testFile := createTestFile(*size)

	// Construct URLs
	httpURL := fmt.Sprintf("https://%s:%d", *server, *port)
	grpcHost := fmt.Sprintf("%s:%d", *server, *port)

	var httpResults, grpcResults map[string]TestResult

	// Run HTTP tests
	if !*skipHTTP {
		fmt.Printf("\nTesting HTTPS at %s\n", httpURL)
		httpResults = testHTTP(httpURL, testFile, *size)
	} else {
		httpResults = make(map[string]TestResult)
	}

	// Run gRPC tests
	if !*skipGRPC {
		fmt.Printf("\nTesting gRPC at %s\n", grpcHost)
		grpcResults = testGRPC(grpcHost, testFile, *size)
	} else {
		grpcResults = make(map[string]TestResult)
	}

	// Generate report
	generateReport(httpResults, grpcResults, *size)
}
