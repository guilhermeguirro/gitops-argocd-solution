#!/usr/bin/env python3
"""
Blue-Green Deployment Promotion Script

This script promotes the green deployment in a blue-green deployment setup.
It scales up the green deployment, updates the services, and scales down the blue deployment.
"""

import subprocess
import sys
import time
import argparse

# ANSI color codes
GREEN = '\033[0;32m'
RED = '\033[0;31m'
YELLOW = '\033[0;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'  # No Color

def print_color(color, message):
    """Print colored message"""
    print(f"{color}{message}{NC}")

def run_command(command, capture_output=True, check=True):
    """Run a shell command and return the output"""
    try:
        result = subprocess.run(
            command,
            shell=True,
            check=check,
            text=True,
            stdout=subprocess.PIPE if capture_output else None,
            stderr=subprocess.PIPE if capture_output else None
        )
        return result.stdout.strip() if capture_output else None
    except subprocess.CalledProcessError as e:
        if capture_output:
            print_color(RED, f"Command failed: {command}")
            print_color(RED, f"Error: {e.stderr}")
        return None

def promote_blue_green(app_name, namespace, replicas=3, skip_confirmation=False):
    """Promote the green deployment in a blue-green setup"""
    print_color(BLUE, f"===== Promoting Green Deployment for {app_name} in {namespace} =====")
    
    # Scale up the green deployment
    print_color(YELLOW, ">> Scaling up the green deployment...")
    run_command(f"kubectl scale deployment {app_name}-green -n {namespace} --replicas={replicas}", capture_output=False)
    
    # Wait for the green deployment to be ready
    print_color(YELLOW, ">> Waiting for the green deployment to be ready...")
    run_command(f"kubectl rollout status deployment {app_name}-green -n {namespace}", capture_output=False)
    
    # Update the preview service to point to the green deployment
    print_color(YELLOW, ">> Updating the preview service to point to the green deployment...")
    run_command(f"kubectl patch service {app_name}-bg-preview -n {namespace} -p '{{\"spec\":{{\"selector\":{{\"version\":\"green\"}}}}}}'", capture_output=False)
    
    # Wait for manual verification
    if not skip_confirmation:
        print_color(YELLOW, f">> Green deployment is now available for preview at {app_name}-bg-preview service.")
        print_color(YELLOW, ">> Please verify the green deployment before proceeding.")
        input("Press Enter to continue with the promotion or Ctrl+C to abort...")
    
    # Update the active service to point to the green deployment
    print_color(YELLOW, ">> Updating the active service to point to the green deployment...")
    run_command(f"kubectl patch service {app_name}-bg-active -n {namespace} -p '{{\"spec\":{{\"selector\":{{\"version\":\"green\"}}}}}}'", capture_output=False)
    
    # Wait a bit to allow traffic to shift
    print_color(YELLOW, ">> Waiting for traffic to shift to the green deployment...")
    time.sleep(5)
    
    # Scale down the blue deployment
    print_color(YELLOW, ">> Scaling down the blue deployment...")
    run_command(f"kubectl scale deployment {app_name}-blue -n {namespace} --replicas=0", capture_output=False)
    
    print_color(GREEN, "✅ Green deployment promoted successfully!")

def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='Promote a blue-green deployment')
    parser.add_argument('app_name', help='Application name (e.g., app1)')
    parser.add_argument('namespace', help='Namespace (e.g., production)')
    parser.add_argument('--replicas', type=int, default=3, help='Number of replicas for the green deployment')
    parser.add_argument('--skip-confirmation', action='store_true', help='Skip confirmation prompt')
    
    args = parser.parse_args()
    
    promote_blue_green(args.app_name, args.namespace, args.replicas, args.skip_confirmation)
    
    return 0

if __name__ == "__main__":
    sys.exit(main()) 