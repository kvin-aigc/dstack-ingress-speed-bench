package main

import (
	"crypto/tls"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

func createHTTPClient() *http.Client {
	// Create HTTP client that accepts self-signed certificates
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	return &http.Client{
		Transport: tr,
		Timeout:   300 * time.Second,
	}
}

func uploadHTTP(baseURL, filePath string) (time.Duration, float64, error) {
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
	url := strings.TrimSuffix(baseURL, "/") + "/upload/" + filename

	fmt.Printf("Uploading %s (%.1f MB)\n", filename, float64(fileSize)/(1024*1024))

	client := createHTTPClient()

	startTime := time.Now()
	req, err := http.NewRequest("PUT", url, file)
	if err != nil {
		return 0, 0, fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("Content-Type", "application/octet-stream")
	req.ContentLength = fileSize

	resp, err := client.Do(req)
	if err != nil {
		return 0, 0, fmt.Errorf("upload request failed: %v", err)
	}
	defer resp.Body.Close()

	duration := time.Since(startTime)

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated && resp.StatusCode != http.StatusNoContent {
		body, _ := io.ReadAll(resp.Body)
		return 0, 0, fmt.Errorf("upload failed with status %d: %s", resp.StatusCode, string(body))
	}

	speedMBps := float64(fileSize) / duration.Seconds() / (1024 * 1024)

	fmt.Printf("Time: %.2f seconds\n", duration.Seconds())
	fmt.Printf("Speed: %.2f MB/s\n", speedMBps)

	return duration, speedMBps, nil
}

func downloadHTTP(baseURL, filename, outputPath string) (time.Duration, float64, error) {
	url := strings.TrimSuffix(baseURL, "/") + "/files/" + filename
	
	fmt.Printf("Downloading %s\n", filename)

	client := createHTTPClient()

	startTime := time.Now()
	resp, err := client.Get(url)
	if err != nil {
		return 0, 0, fmt.Errorf("download request failed: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return 0, 0, fmt.Errorf("download failed with status %d", resp.StatusCode)
	}

	file, err := os.Create(outputPath)
	if err != nil {
		return 0, 0, fmt.Errorf("failed to create output file: %v", err)
	}
	defer file.Close()

	// Copy with progress tracking
	var totalBytes int64
	buffer := make([]byte, 32*1024) // 32KB buffer

	for {
		n, err := resp.Body.Read(buffer)
		if n > 0 {
			if _, writeErr := file.Write(buffer[:n]); writeErr != nil {
				return 0, 0, fmt.Errorf("failed to write to file: %v", writeErr)
			}
			totalBytes += int64(n)

			// Progress reporting
			if totalBytes%(50*1024*1024) == 0 {
				fmt.Printf("  Progress: %.0fMB\n", float64(totalBytes)/(1024*1024))
			}
		}
		if err == io.EOF {
			break
		}
		if err != nil {
			return 0, 0, fmt.Errorf("failed to read response: %v", err)
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