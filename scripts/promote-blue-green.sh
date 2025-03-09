#!/bin/bash

# Script to promote the green deployment in our blue-green setup

set -e

echo "===== Promoting Green Deployment ====="

# Scale up the green deployment
echo ">> Scaling up the green deployment..."
kubectl scale deployment nginx-green -n blue-green --replicas=3

# Wait for the green deployment to be ready
echo ">> Waiting for the green deployment to be ready..."
kubectl rollout status deployment nginx-green -n blue-green

# Update the preview service to point to the green deployment
echo ">> Updating the preview service to point to the green deployment..."
kubectl patch service nginx-bg-preview -n blue-green -p '{"spec":{"selector":{"version":"green"}}}'

# Wait for manual verification
echo ">> Green deployment is now available for preview at nginx-bg-preview service."
echo ">> Please verify the green deployment before proceeding."
read -p "Press Enter to continue with the promotion or Ctrl+C to abort..." 

# Update the active service to point to the green deployment
echo ">> Updating the active service to point to the green deployment..."
kubectl patch service nginx-bg-active -n blue-green -p '{"spec":{"selector":{"version":"green"}}}'

# Wait a bit to allow traffic to shift
echo ">> Waiting for traffic to shift to the green deployment..."
sleep 5

# Scale down the blue deployment
echo ">> Scaling down the blue deployment..."
kubectl scale deployment nginx-blue -n blue-green --replicas=0

echo "✅ Green deployment promoted successfully!" 