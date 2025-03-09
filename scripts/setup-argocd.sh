#!/bin/bash

# Script to set up ArgoCD for GitOps
# This script installs ArgoCD in a local Kubernetes cluster and configures it for GitOps

set -e

echo "===== Setting up ArgoCD for GitOps ====="

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
  echo "Error: kubectl is not installed. Please install it first."
  exit 1
fi

# Check if a Kubernetes cluster is available
if ! kubectl cluster-info &> /dev/null; then
  echo "Error: No Kubernetes cluster is available. Please set up a cluster first."
  exit 1
fi

# Create ArgoCD namespace
echo -e "\n>> Creating ArgoCD namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo -e "\n>> Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo -e "\n>> Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get the ArgoCD admin password
echo -e "\n>> Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD admin password: $ARGOCD_PASSWORD"

# Set up port forwarding for ArgoCD server
echo -e "\n>> Setting up port forwarding for ArgoCD server..."
echo "Run the following command in a separate terminal:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "Then access ArgoCD UI at https://localhost:8080"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"

# Create namespaces for environments
echo -e "\n>> Creating namespaces for environments..."
kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace production --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace canary --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace blue-green --dry-run=client -o yaml | kubectl apply -f -

# Apply the application manifests
echo -e "\n>> Applying application manifests..."
kubectl apply -f ../environments/dev/nginx-app.yaml
kubectl apply -f ../environments/staging/nginx-app.yaml
kubectl apply -f ../environments/production/nginx-app.yaml

echo -e "\n>> ArgoCD setup complete!"
echo "You can now access the ArgoCD UI to see the applications being deployed."
echo "Remember to run the port forwarding command in a separate terminal:"
echo "kubectl port-forward svc/argocd-server -n argocd 8080:443" 