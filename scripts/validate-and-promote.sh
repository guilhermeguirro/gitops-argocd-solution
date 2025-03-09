#!/bin/bash

# Script to validate application health and promote to the next environment
# This demonstrates a sophisticated GitOps workflow with validation gates

set -e

APP_NAME=$1
SOURCE_ENV=$2
TARGET_ENV=$3

if [ -z "$APP_NAME" ] || [ -z "$SOURCE_ENV" ] || [ -z "$TARGET_ENV" ]; then
  echo "Usage: $0 <app-name> <source-env> <target-env>"
  echo "Example: $0 nginx-dev dev staging"
  exit 1
fi

echo "===== Validating and Promoting $APP_NAME from $SOURCE_ENV to $TARGET_ENV ====="

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

# Validate source application health
echo -e "\n>> Validating $APP_NAME in $SOURCE_ENV environment..."
APP_HEALTH=$(argocd app get $APP_NAME -o json | jq -r '.status.health.status')
APP_SYNC=$(argocd app get $APP_NAME -o json | jq -r '.status.sync.status')

if [ "$APP_HEALTH" != "Healthy" ] || [ "$APP_SYNC" != "Synced" ]; then
  echo "Error: $APP_NAME in $SOURCE_ENV is not healthy or not synced."
  echo "Health: $APP_HEALTH, Sync: $APP_SYNC"
  exit 1
fi

# Run additional validation tests
echo -e "\n>> Running additional validation tests..."

# Check if all pods are running
PODS_RUNNING=$(kubectl get pods -n $SOURCE_ENV -l app.kubernetes.io/instance=$APP_NAME -o json | jq '.items | length')
PODS_READY=$(kubectl get pods -n $SOURCE_ENV -l app.kubernetes.io/instance=$APP_NAME -o json | jq '[.items[] | select(.status.phase=="Running")] | length')

if [ "$PODS_RUNNING" != "$PODS_READY" ]; then
  echo "Error: Not all pods are running for $APP_NAME in $SOURCE_ENV."
  echo "Running: $PODS_READY/$PODS_RUNNING"
  exit 1
fi

# Check if service is available
if ! kubectl get service -n $SOURCE_ENV -l app.kubernetes.io/instance=$APP_NAME &> /dev/null; then
  echo "Error: Service not found for $APP_NAME in $SOURCE_ENV."
  exit 1
fi

# Check if endpoints are available
ENDPOINTS=$(kubectl get endpoints -n $SOURCE_ENV -l app.kubernetes.io/instance=$APP_NAME -o json | jq '.items[0].subsets[0].addresses | length')
if [ "$ENDPOINTS" -eq 0 ]; then
  echo "Error: No endpoints available for $APP_NAME in $SOURCE_ENV."
  exit 1
fi

echo "✅ Validation passed for $APP_NAME in $SOURCE_ENV!"

# Get the current configuration
echo -e "\n>> Getting current configuration from $APP_NAME..."
REPLICAS=$(argocd app get $APP_NAME -o json | jq -r '.spec.source.helm.parameters[] | select(.name=="replicaCount") | .value')
IMAGE_TAG=$(argocd app get $APP_NAME -o json | jq -r '.spec.source.helm.parameters[] | select(.name=="image.tag") | .value')

# Determine target application name
TARGET_APP_NAME=$(echo $APP_NAME | sed "s/$SOURCE_ENV/$TARGET_ENV/")

echo -e "\n>> Promoting configuration from $APP_NAME to $TARGET_APP_NAME..."
echo "Replicas: $REPLICAS"
echo "Image Tag: $IMAGE_TAG"

# Update the target application with the same configuration
argocd app set $TARGET_APP_NAME --helm-set replicaCount=$REPLICAS
argocd app set $TARGET_APP_NAME --helm-set image.tag=$IMAGE_TAG

# Sync the target application
echo -e "\n>> Syncing $TARGET_APP_NAME..."
argocd app sync $TARGET_APP_NAME

# Wait for the application to be healthy
echo -e "\n>> Waiting for $TARGET_APP_NAME to be healthy..."
argocd app wait $TARGET_APP_NAME --health --timeout 300

echo -e "\n>> Promotion completed successfully!"
echo "✅ $APP_NAME has been promoted from $SOURCE_ENV to $TARGET_ENV" 