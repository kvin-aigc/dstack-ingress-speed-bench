#!/usr/bin/env python3
"""
Complete Benchmark Suite
Runs all tests and generates a comparison report
"""

import subprocess
import os
import sys
import json
import time
from tabulate import tabulate
import argparse

def create_test_file(size_mb=200):
    """Create a random test file"""
    filename = f"test-{size_mb}mb.bin"
    if not os.path.exists(filename):
        print(f"Creating {size_mb}MB test file...")
        subprocess.run([
            'dd', 'if=/dev/urandom', f'of={filename}', 
            'bs=1M', f'count={size_mb}'
        ], check=True, capture_output=True)
    return filename

def run_http_test(url, test_file, verify_ssl=False):
    """Run HTTP upload and download tests"""
    results = {}
    
    # Upload test
    print("\n=== HTTP Upload Test ===")
    cmd = ['python3', 'http_test.py', 'upload', '--url', url, '--file', test_file]
    if verify_ssl:
        cmd.append('--verify-ssl')
    
    start = time.time()
    result = subprocess.run(cmd, capture_output=True, text=True)
    duration = time.time() - start
    
    if "Speed:" in result.stdout:
        speed_line = [l for l in result.stdout.split('\n') if 'Speed:' in l][0]
        speed = float(speed_line.split(':')[1].strip().split()[0])
        results['upload'] = {'speed_mbps': speed, 'duration': duration, 'success': True}
    else:
        results['upload'] = {'speed_mbps': 0, 'duration': duration, 'success': False}
    
    # Download test  
    print("\n=== HTTP Download Test ===")
    cmd = ['python3', 'http_test.py', 'download', '--url', url, 
           '--file', 'random-200mb.bin']  # Download the pre-existing server file
    if verify_ssl:
        cmd.append('--verify-ssl')
    
    start = time.time()
    result = subprocess.run(cmd, capture_output=True, text=True)
    duration = time.time() - start
    
    if "Speed:" in result.stdout:
        speed_line = [l for l in result.stdout.split('\n') if 'Speed:' in l][0]
        speed = float(speed_line.split(':')[1].strip().split()[0])
        results['download'] = {'speed_mbps': speed, 'duration': duration, 'success': True}
    else:
        results['download'] = {'speed_mbps': 0, 'duration': duration, 'success': False}
    
    return results

def run_grpc_test(host, test_file, use_ssl=True):
    """Run gRPC upload and download tests"""
    results = {}
    
    # Upload test
    print("\n=== gRPC Upload Test ===")
    cmd = ['python3', 'grpc_test.py', 'upload', '--host', host, '--file', test_file]
    if not use_ssl:
        cmd.append('--no-ssl')
    
    start = time.time()
    result = subprocess.run(cmd, capture_output=True, text=True)
    duration = time.time() - start
    
    if "Speed:" in result.stdout:
        speed_line = [l for l in result.stdout.split('\n') if 'Speed:' in l][0]
        speed = float(speed_line.split(':')[1].strip().split()[0])
        results['upload'] = {'speed_mbps': speed, 'duration': duration, 'success': True}
    else:
        results['upload'] = {'speed_mbps': 0, 'duration': duration, 'success': False}
    
    # Download test  
    print("\n=== gRPC Download Test ===")
    cmd = ['python3', 'grpc_test.py', 'download', '--host', host,
           '--file', 'random-200mb.bin']  # Download the pre-existing server file
    if not use_ssl:
        cmd.append('--no-ssl')
    
    start = time.time()
    result = subprocess.run(cmd, capture_output=True, text=True)
    duration = time.time() - start
    
    if "Speed:" in result.stdout:
        speed_line = [l for l in result.stdout.split('\n') if 'Speed:' in l][0]
        speed = float(speed_line.split(':')[1].strip().split()[0])
        results['download'] = {'speed_mbps': speed, 'duration': duration, 'success': True}
    else:
        results['download'] = {'speed_mbps': 0, 'duration': duration, 'success': False}
    
    return results

def load_server_hw_info():
    """Load server hardware information from environment variables"""
    hw_info = {
        "CPU": os.getenv("SERVER_HW_CPU", "Unknown"),
        "CPU_Cores": os.getenv("SERVER_HW_CPU_CORES", "Unknown"), 
        "Memory": os.getenv("SERVER_HW_MEMORY", "Unknown"),
        "Disk": os.getenv("SERVER_HW_DISK", "Unknown"),
        "OS": os.getenv("SERVER_HW_OS", "Unknown"),
        "Kernel": os.getenv("SERVER_HW_KERNEL", "Unknown"),
        "Docker": os.getenv("SERVER_HW_DOCKER", "Unknown")
    }
    
    # Check if any hardware info was provided
    if all(value == "Unknown" for value in hw_info.values()):
        return {"Error": "Hardware info not available"}
    
    return hw_info

def generate_report(http_results, grpc_results, file_size_mb):
    """Generate comparison report"""
    
    # Load server hardware info
    server_hw = load_server_hw_info()
    
    headers = ['Protocol', 'Operation', 'Speed (MB/s)', 'Time (s)', 'Status']
    data = []
    
    # HTTP results
    if 'upload' in http_results:
        data.append([
            'HTTPS',
            'Upload',
            f"{http_results['upload']['speed_mbps']:.2f}",
            f"{http_results['upload']['duration']:.2f}",
            '✅' if http_results['upload']['success'] else '❌'
        ])
    
    if 'download' in http_results:
        data.append([
            'HTTPS',
            'Download',
            f"{http_results['download']['speed_mbps']:.2f}",
            f"{http_results['download']['duration']:.2f}",
            '✅' if http_results['download']['success'] else '❌'
        ])
    
    # gRPC results
    if 'upload' in grpc_results:
        data.append([
            'gRPC',
            'Upload',
            f"{grpc_results['upload']['speed_mbps']:.2f}",
            f"{grpc_results['upload']['duration']:.2f}",
            '✅' if grpc_results['upload']['success'] else '❌'
        ])
    
    if 'download' in grpc_results:
        data.append([
            'gRPC',
            'Download',
            f"{grpc_results['download']['speed_mbps']:.2f}",
            f"{grpc_results['download']['duration']:.2f}",
            '✅' if grpc_results['download']['success'] else '❌'
        ])
    
    print(f"\n{'='*60}")
    print(f"BENCHMARK RESULTS - {file_size_mb}MB File")
    print(f"{'='*60}")
    
    print(tabulate(data, headers=headers, tablefmt='grid'))
    
    # Save results to JSON
    results = {
        'timestamp': time.strftime('%Y-%m-%d %H:%M:%S'),
        'file_size_mb': file_size_mb,
        'server_hardware': server_hw,
        'http': http_results,
        'grpc': grpc_results
    }
    
    with open('benchmark_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print("\nResults saved to benchmark_results.json")

def main():
    parser = argparse.ArgumentParser(description='Speed Test Benchmark Suite')
    parser.add_argument('--server', required=True, help='Server address (e.g., example.com)')
    parser.add_argument('--port', default=443, type=int, help='Server port')
    parser.add_argument('--size', default=200, type=int, help='Test file size in MB')
    parser.add_argument('--skip-http', action='store_true', help='Skip HTTP tests')
    parser.add_argument('--skip-grpc', action='store_true', help='Skip gRPC tests')
    
    args = parser.parse_args()
    
    # Create test file
    test_file = create_test_file(args.size)
    
    # Construct URLs
    http_url = f"https://{args.server}:{args.port}"
    grpc_host = f"{args.server}:{args.port}"
    
    http_results = {}
    grpc_results = {}
    
    # Run HTTP tests
    if not args.skip_http:
        print(f"\nTesting HTTPS at {http_url}")
        http_results = run_http_test(http_url, test_file)
    
    # Run gRPC tests
    if not args.skip_grpc:
        print(f"\nTesting gRPC at {grpc_host}")
        grpc_results = run_grpc_test(grpc_host, test_file)
    
    # Generate report
    generate_report(http_results, grpc_results, args.size)

if __name__ == '__main__':
    main()