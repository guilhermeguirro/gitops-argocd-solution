#!/bin/bash

# Script to rollback an application to a previous version

set -e

APP_NAME=$1
REVISION=$2

if [ -z "$APP_NAME" ]; then
  echo "Usage: $0 <app-name> [revision]"
  echo "Example: $0 nginx-dev 2"
  exit 1
fi

echo "===== Rolling Back $APP_NAME ====="

# Check if ArgoCD is installed
if ! kubectl get namespace argocd &> /dev/null; then
  echo "Error: ArgoCD namespace not found. Please run setup-argocd.sh first."
  exit 1
fi

# Get ArgoCD admin password
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Login to ArgoCD
echo -e "\n>> Logging in to ArgoCD..."
echo "Make sure port forwarding is running: kubectl port-forward svc/argocd-server -n argocd 8080:443"
argocd login localhost:8080 --username admin --password $ARGOCD_PASSWORD --insecure

# Get the application history
echo -e "\n>> Getting application history..."
argocd app history $APP_NAME

# If revision is not provided, ask for it
if [ -z "$REVISION" ]; then
  read -p "Enter the revision number to rollback to: " REVISION
fi

# Rollback the application
echo -e "\n>> Rolling back $APP_NAME to revision $REVISION..."
argocd app rollback $APP_NAME $REVISION

# Wait for the application to be healthy
echo -e "\n>> Waiting for $APP_NAME to be healthy..."
argocd app wait $APP_NAME --health --timeout 300

echo -e "\n>> Rollback completed successfully!"
echo "✅ $APP_NAME has been rolled back to revision $REVISION" 