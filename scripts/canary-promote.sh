#!/bin/bash

# Script to gradually promote a canary deployment

set -e

CANARY_WEIGHT=$1

if [ -z "$CANARY_WEIGHT" ]; then
  echo "Usage: $0 <canary-weight>"
  echo "Example: $0 25 (for 25% canary traffic)"
  exit 1
fi

echo "===== Promoting Canary Deployment to $CANARY_WEIGHT% ====="

# Calculate the number of replicas for stable and canary
TOTAL_REPLICAS=4
CANARY_REPLICAS=$(( $TOTAL_REPLICAS * $CANARY_WEIGHT / 100 ))
STABLE_REPLICAS=$(( $TOTAL_REPLICAS - $CANARY_REPLICAS ))

# Ensure at least one replica for each
if [ $CANARY_REPLICAS -lt 1 ]; then
  CANARY_REPLICAS=1
  STABLE_REPLICAS=$(( $TOTAL_REPLICAS - $CANARY_REPLICAS ))
fi

if [ $STABLE_REPLICAS -lt 1 ]; then
  STABLE_REPLICAS=1
  CANARY_REPLICAS=$(( $TOTAL_REPLICAS - $STABLE_REPLICAS ))
fi

echo ">> Setting canary replicas to $CANARY_REPLICAS and stable replicas to $STABLE_REPLICAS..."

# Scale the deployments
kubectl scale deployment nginx-canary -n canary --replicas=$CANARY_REPLICAS
kubectl scale deployment nginx-stable -n canary --replicas=$STABLE_REPLICAS

# Wait for the deployments to be ready
echo ">> Waiting for the canary deployment to be ready..."
kubectl rollout status deployment nginx-canary -n canary

echo ">> Waiting for the stable deployment to be ready..."
kubectl rollout status deployment nginx-stable -n canary

# Calculate the actual percentage
TOTAL_ACTUAL=$(( $CANARY_REPLICAS + $STABLE_REPLICAS ))
CANARY_PERCENTAGE=$(( $CANARY_REPLICAS * 100 / $TOTAL_ACTUAL ))

echo ">> Canary deployment is now receiving approximately $CANARY_PERCENTAGE% of traffic."
echo ">> Monitor the deployment for any issues before increasing the canary percentage."

if [ $CANARY_PERCENTAGE -eq 100 ]; then
  echo "✅ Canary deployment is now receiving 100% of traffic. Migration complete!"
fi 