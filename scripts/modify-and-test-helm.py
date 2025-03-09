#!/usr/bin/env python3
"""
Modify and Test Helm Charts with ArgoCD

This script modifies a Helm chart value and tests the changes using ArgoCD.
It updates the values file, applies the changes to ArgoCD, and verifies the deployment.
"""

import subprocess
import sys
import os
import json
import base64
import time
import tempfile
import re
import argparse

# Try to import yaml, but don't require it
try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False
    print("PyYAML not installed. Simple text-based YAML processing will be used.")
    print("For better YAML handling, install PyYAML: pip install pyyaml")

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

def check_prerequisites(app_name, environment):
    """Check if kubectl and ArgoCD are installed and application exists"""
    # Check if kubectl is installed
    if run_command("which kubectl", check=False) is None:
        print_color(RED, "kubectl is not installed. Please install it first.")
        sys.exit(1)
    
    # Check if ArgoCD is installed
    if run_command("kubectl get namespace argocd", check=False) is None:
        print_color(RED, "ArgoCD namespace not found. Please install ArgoCD first.")
        sys.exit(1)
    
    # Check if application exists in ArgoCD
    full_app_name = f"{app_name}-{environment}"
    if run_command(f"kubectl get application {full_app_name} -n argocd", check=False) is None:
        print_color(RED, f"Application {full_app_name} does not exist in ArgoCD.")
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

def modify_helm_values(app_name, environment, key, value):
    """Modify Helm values file"""
    global HAS_YAML
    
    helm_dir = f"gitops-solution/environments/{environment}/helm-values"
    values_file = f"{helm_dir}/{app_name}-values.yaml"
    
    # Create directory if it doesn't exist
    if not os.path.exists(helm_dir):
        print_color(RED, f"Helm values directory not found: {helm_dir}")
        print_color(YELLOW, "Creating directory...")
        os.makedirs(helm_dir, exist_ok=True)
    
    # Create file if it doesn't exist
    if not os.path.exists(values_file):
        print_color(RED, f"Values file not found: {values_file}")
        print_color(YELLOW, "Creating empty values file...")
        open(values_file, 'a').close()
    
    # Get current value if it exists
    print_color(YELLOW, f"Checking current value for {key}...")
    current_value = "not set"
    
    try:
        with open(values_file, 'r') as f:
            for line in f:
                if line.strip().startswith(f"{key}:"):
                    current_value = line.strip().split(':', 1)[1].strip()
                    break
    except Exception as e:
        print_color(RED, f"Error reading values file: {e}")
    
    print_color(GREEN, f"Current value: {current_value}")
    
    # Modify the value in the values file
    print_color(YELLOW, f"Modifying {key} to {value} in {values_file}...")
    
    if HAS_YAML:
        # Use PyYAML for better YAML handling
        try:
            # Load existing values
            values = {}
            if os.path.getsize(values_file) > 0:
                with open(values_file, 'r') as f:
                    values = yaml.safe_load(f) or {}
            
            # Update the value
            keys = key.split('.')
            if len(keys) == 1:
                values[key] = value
            else:
                # Handle nested keys
                current = values
                for k in keys[:-1]:
                    if k not in current:
                        current[k] = {}
                    current = current[k]
                current[keys[-1]] = value
            
            # Write back to file
            with open(values_file, 'w') as f:
                yaml.dump(values, f, default_flow_style=False)
        
        except Exception as e:
            print_color(RED, f"Error modifying values file with PyYAML: {e}")
            print_color(YELLOW, "Falling back to simple text processing...")
            HAS_YAML = False
    
    if not HAS_YAML:
        # Simple text-based processing
        try:
            with open(values_file, 'r') as f:
                content = f.read()
            
            # Check if key exists
            key_exists = False
            new_content = []
            
            for line in content.splitlines():
                if line.strip().startswith(f"{key}:"):
                    new_content.append(f"{key}: {value}")
                    key_exists = True
                else:
                    new_content.append(line)
            
            # Add key if it doesn't exist
            if not key_exists:
                new_content.append(f"{key}: {value}")
            
            # Write back to file
            with open(values_file, 'w') as f:
                f.write('\n'.join(new_content))
                if not new_content[-1].endswith('\n'):
                    f.write('\n')
        
        except Exception as e:
            print_color(RED, f"Error modifying values file: {e}")
            sys.exit(1)
    
    # Show the changes
    print_color(GREEN, f"Changes made to {values_file}:")
    with open(values_file, 'r') as f:
        print(f.read())
    
    return current_value, values_file

def update_argocd_application(app_name, environment, key, value, values_file):
    """Update ArgoCD application with new values"""
    full_app_name = f"{app_name}-{environment}"
    
    print_color(YELLOW, "Updating ArgoCD application to use our values...")
    
    # Read the values file content
    with open(values_file, 'r') as f:
        values_content = f.read()
    
    # Create a temporary JSON file for the patch
    with tempfile.NamedTemporaryFile(mode='w', delete=False) as temp_file:
        # Create the patch with both parameters and values
        patch = {
            "spec": {
                "source": {
                    "helm": {
                        "parameters": [],
                        "values": values_content
                    }
                }
            }
        }
        
        # Add all values as parameters too for better compatibility
        with open(values_file, 'r') as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#'):
                    try:
                        k, v = line.split(':', 1)
                        patch["spec"]["source"]["helm"]["parameters"].append({
                            "name": k.strip(),
                            "value": v.strip()
                        })
                    except ValueError:
                        # Skip lines that don't have a colon
                        pass
        
        json.dump(patch, temp_file, indent=2)
        temp_file_path = temp_file.name
    
    run_command(f"kubectl patch application {full_app_name} -n argocd --type merge --patch-file {temp_file_path}")
    os.unlink(temp_file_path)
    
    print_color(GREEN, "ArgoCD application updated to use our values.")

def refresh_and_wait_for_sync(app_name, environment):
    """Refresh the application in ArgoCD and wait for sync to complete"""
    full_app_name = f"{app_name}-{environment}"
    
    # Refresh the application in ArgoCD
    print_color(YELLOW, f"Refreshing application {full_app_name} in ArgoCD...")
    run_command(f"kubectl patch application {full_app_name} -n argocd --type merge -p '{{\"spec\":{{\"syncPolicy\":{{\"automated\":{{\"prune\":true,\"selfHeal\":true}}}}}}}}'")
    print_color(GREEN, "Application refreshed. ArgoCD will automatically sync the changes.")
    
    # Wait for sync to complete
    print_color(YELLOW, "Waiting for sync to complete...")
    for i in range(30):
        sync_status = run_command(f"kubectl get application {full_app_name} -n argocd -o jsonpath=\"{{.status.sync.status}}\"")
        if sync_status == "Synced":
            print_color(GREEN, "Application synced successfully.")
            break
        print_color(YELLOW, f"Current sync status: {sync_status}. Waiting...")
        time.sleep(5)
        if i == 29:
            print_color(RED, "Timeout waiting for sync to complete.")
            sys.exit(1)
    
    # Check health status
    print_color(YELLOW, "Checking health status...")
    health_status = run_command(f"kubectl get application {full_app_name} -n argocd -o jsonpath=\"{{.status.health.status}}\"")
    print_color(GREEN, f"Health Status: {health_status}")

def verify_changes(app_name, environment):
    """Verify the changes in Kubernetes resources"""
    full_app_name = f"{app_name}-{environment}"
    
    print_color(YELLOW, "Verifying changes...")
    
    resource_commands = {
        'dev': f"kubectl get deployments,services,configmaps -n dev -l \"app.kubernetes.io/instance={full_app_name}\" -o wide",
        'staging': f"kubectl get deployments,services,configmaps,ingress -n staging -l \"app.kubernetes.io/instance={full_app_name}\" -o wide",
        'production': f"kubectl get deployments,services,configmaps,ingress,hpa -n production -l \"app.kubernetes.io/instance={full_app_name}\" -o wide"
    }
    
    if environment in resource_commands:
        print_color(YELLOW, f"Checking {environment} environment resources...")
        run_command(resource_commands[environment], capture_output=False, check=False)
    else:
        print_color(YELLOW, f"Unknown environment: {environment}. Checking basic resources...")
        run_command(f"kubectl get deployments,services -l \"app.kubernetes.io/instance={full_app_name}\" -o wide", 
                   capture_output=False, check=False)

def main():
    """Main function"""
    parser = argparse.ArgumentParser(description='Modify and test Helm charts with ArgoCD')
    parser.add_argument('app_name', help='Application name (e.g., app1)')
    parser.add_argument('environment', help='Environment (dev, staging, production)')
    parser.add_argument('key', help='Helm value key to modify')
    parser.add_argument('value', help='New value for the key')
    
    args = parser.parse_args()
    
    # Validate environment
    if args.environment not in ['dev', 'staging', 'production']:
        print_color(RED, "Invalid environment. Must be one of: dev, staging, production")
        sys.exit(1)
    
    # Check prerequisites
    check_prerequisites(args.app_name, args.environment)
    
    # Get ArgoCD password
    get_argocd_password()
    
    # Modify Helm values
    current_value, values_file = modify_helm_values(args.app_name, args.environment, args.key, args.value)
    
    # Update ArgoCD application
    update_argocd_application(args.app_name, args.environment, args.key, args.value, values_file)
    
    # Refresh and wait for sync
    refresh_and_wait_for_sync(args.app_name, args.environment)
    
    # Verify changes
    verify_changes(args.app_name, args.environment)
    
    # Print summary
    full_app_name = f"{args.app_name}-{args.environment}"
    print()
    print_color(GREEN, f"Modification and testing completed for {full_app_name}.")
    print_color(YELLOW, f"Key: {args.key}")
    print_color(YELLOW, f"Old value: {current_value}")
    print_color(GREEN, f"New value: {args.value}")
    
    return 0

if __name__ == "__main__":
    sys.exit(main()) 