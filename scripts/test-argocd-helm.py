#!/usr/bin/env python3
"""
Test ArgoCD Helm Charts

This script tests Helm charts deployed with ArgoCD by checking application states
and verifying resources in the appropriate namespaces.
"""

import subprocess
import sys
import os
import json
import base64
import time

# ANSI color codes
GREEN = '\033[0;32m'
RED = '\033[0;31m'
YELLOW = '\033[0;33m'
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

def check_prerequisites():
    """Check if kubectl and ArgoCD are installed"""
    # Check if kubectl is installed
    if run_command("which kubectl", check=False) is None:
        print_color(RED, "kubectl is not installed. Please install it first.")
        sys.exit(1)
    
    # Check if ArgoCD is installed
    if run_command("kubectl get namespace argocd", check=False) is None:
        print_color(RED, "ArgoCD namespace not found. Please install ArgoCD first.")
        sys.exit(1)

def get_argocd_password():
    """Get ArgoCD admin password"""
    print_color(YELLOW, "Getting ArgoCD admin password...")
    password_base64 = run_command(
        "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\""
    )
    if password_base64:
        password = base64.b64decode(password_base64).decode('utf-8')
        print_color(GREEN, f"ArgoCD admin password retrieved: {password}")
        print_color(YELLOW, "To access ArgoCD UI, run:")
        print("kubectl port-forward svc/argocd-server -n argocd 8080:443")
        print(f"Then access ArgoCD at https://localhost:8080 with username: admin, password: {password}")
        return password
    else:
        print_color(RED, "Failed to get ArgoCD admin password.")
        return None

def test_application(app_name):
    """Test an ArgoCD application"""
    # Extract environment from app name
    env = app_name.split('-')[-1]
    
    print()
    print_color(YELLOW, f"Testing application: {app_name}")
    
    # Check if application exists
    if run_command(f"kubectl get application {app_name} -n argocd", check=False) is None:
        print_color(RED, f"Application {app_name} does not exist in ArgoCD.")
        return False
    
    # Check application status
    print_color(YELLOW, "Checking application status...")
    sync_status = run_command(
        f"kubectl get application {app_name} -n argocd -o jsonpath=\"{{.status.sync.status}}\""
    )
    if sync_status:
        print_color(GREEN, f"Sync Status: {sync_status}")
    else:
        print_color(RED, f"Failed to get sync status for {app_name}")
        return False
    
    # Check health status
    print_color(YELLOW, "Checking health status...")
    health_status = run_command(
        f"kubectl get application {app_name} -n argocd -o jsonpath=\"{{.status.health.status}}\""
    )
    if health_status:
        print_color(GREEN, f"Health Status: {health_status}")
    else:
        print_color(RED, f"Failed to get health status for {app_name}")
        return False
    
    # Check Kubernetes resources based on environment
    print_color(YELLOW, "Checking Kubernetes resources...")
    
    resource_commands = {
        'dev': f"kubectl get deployments,services,configmaps -n dev -l \"app.kubernetes.io/instance={app_name}\" -o wide",
        'staging': f"kubectl get deployments,services,configmaps,ingress -n staging -l \"app.kubernetes.io/instance={app_name}\" -o wide",
        'production': f"kubectl get deployments,services,configmaps,ingress,hpa -n production -l \"app.kubernetes.io/instance={app_name}\" -o wide"
    }
    
    if env in resource_commands:
        print_color(YELLOW, f"Checking {env} environment resources...")
        run_command(resource_commands[env], capture_output=False, check=False)
    else:
        print_color(YELLOW, f"Unknown environment: {env}. Checking basic resources...")
        run_command(f"kubectl get deployments,services -l \"app.kubernetes.io/instance={app_name}\" -o wide", 
                   capture_output=False, check=False)
    
    print_color(GREEN, f"Test completed for {app_name}")
    return True

def main():
    """Main function"""
    check_prerequisites()
    get_argocd_password()
    
    # Test applications
    applications = ["app1-dev", "app1-staging", "app1-production"]
    success = True
    
    for app in applications:
        if not test_application(app):
            success = False
    
    print()
    print_color(GREEN, "All tests completed.")
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main()) 