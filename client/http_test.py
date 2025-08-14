#!/usr/bin/env python3
"""
HTTPS Speed Test Client
Tests upload and download speeds using standard HTTP methods
"""

import requests
import time
import os
import sys
import argparse
from urllib3.exceptions import InsecureRequestWarning

# Suppress SSL warnings for self-signed certificates
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)

def upload_file(url, filepath, verify_ssl=False):
    """Upload file using HTTP PUT"""
    filename = os.path.basename(filepath)
    upload_url = f"{url}/upload/{filename}"
    
    print(f"Uploading {filename} ({os.path.getsize(filepath) / (1024*1024):.1f} MB) to {upload_url}")
    
    with open(filepath, 'rb') as f:
        start_time = time.time()
        try:
            response = requests.put(upload_url, data=f, verify=verify_ssl, timeout=60)
            end_time = time.time()
        except Exception as e:
            end_time = time.time()
            print(f"Upload failed: {e}")
            duration = end_time - start_time
            return duration, 0, False
    
    duration = end_time - start_time
    file_size = os.path.getsize(filepath)
    
    if response.status_code in [200, 201, 204]:
        speed_mbps = (file_size / duration) / (1024 * 1024)
        print(f"Status: {response.status_code}")
        print(f"Time: {duration:.2f} seconds")
        print(f"Speed: {speed_mbps:.2f} MB/s")
        return duration, speed_mbps, True
    else:
        print(f"Upload failed - Status: {response.status_code}")
        print(f"Response: {response.text[:200]}")
        return duration, 0, False

def download_file(url, filename, output_path, verify_ssl=False):
    """Download file using HTTP GET"""
    download_url = f"{url}/files/{filename}"
    
    print(f"Downloading {filename} from {download_url}")
    
    start_time = time.time()
    try:
        response = requests.get(download_url, stream=True, verify=verify_ssl, timeout=60)
        
        if response.status_code != 200:
            print(f"Download failed - Status: {response.status_code}")
            print(f"Response: {response.text[:200]}")
            return time.time() - start_time, 0, False
        
        total_bytes = 0
        with open(output_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=1024*1024):
                if chunk:
                    f.write(chunk)
                    total_bytes += len(chunk)
        
        end_time = time.time()
        duration = end_time - start_time
        speed_mbps = (total_bytes / duration) / (1024 * 1024)
        
        print(f"Downloaded: {total_bytes / (1024*1024):.1f} MB")
        print(f"Time: {duration:.2f} seconds")
        print(f"Speed: {speed_mbps:.2f} MB/s")
        
        return duration, speed_mbps, True
        
    except Exception as e:
        end_time = time.time()
        print(f"Download failed: {e}")
        duration = end_time - start_time
        return duration, 0, False

def main():
    parser = argparse.ArgumentParser(description='HTTPS Speed Test')
    parser.add_argument('action', choices=['upload', 'download', 'both'])
    parser.add_argument('--url', required=True, help='Server URL (e.g., https://example.com:443)')
    parser.add_argument('--file', help='File to upload or filename to download')
    parser.add_argument('--output', help='Output path for download')
    parser.add_argument('--verify-ssl', action='store_true', help='Verify SSL certificate')
    
    args = parser.parse_args()
    
    if args.action in ['upload', 'both']:
        if not args.file or not os.path.exists(args.file):
            print("Error: File not found for upload")
            sys.exit(1)
        upload_file(args.url, args.file, args.verify_ssl)
    
    if args.action in ['download', 'both']:
        if not args.file:
            print("Error: Filename required for download")
            sys.exit(1)
        output = args.output or f"downloaded_{args.file}"
        download_file(args.url, args.file, output, args.verify_ssl)

if __name__ == '__main__':
    main()