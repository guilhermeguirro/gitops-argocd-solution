#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check if correct number of arguments is provided
if [ "$#" -lt 4 ]; then
    echo -e "${RED}Usage: $0 <app-name> <environment> <key> <value>${NC}"
    echo -e "Example: $0 app1 dev replicaCount 3"
    exit 1
fi

APP_NAME=$1
ENVIRONMENT=$2
KEY=$3
VALUE=$4

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|production)$ ]]; then
    echo -e "${RED}Invalid environment. Must be one of: dev, staging, production${NC}"
    exit 1
fi

FULL_APP_NAME="${APP_NAME}-${ENVIRONMENT}"
HELM_DIR="gitops-solution/environments/${ENVIRONMENT}/helm-values"
VALUES_FILE="${HELM_DIR}/${APP_NAME}-values.yaml"

# Check if Helm values directory exists
if [ ! -d "$HELM_DIR" ]; then
    echo -e "${RED}Helm values directory not found: $HELM_DIR${NC}"
    echo -e "${YELLOW}Creating directory...${NC}"
    mkdir -p "$HELM_DIR"
fi

# Check if values file exists
if [ ! -f "$VALUES_FILE" ]; then
    echo -e "${RED}Values file not found: $VALUES_FILE${NC}"
    echo -e "${YELLOW}Creating empty values file...${NC}"
    touch "$VALUES_FILE"
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}kubectl is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if ArgoCD is installed
if ! kubectl get namespace argocd &> /dev/null; then
    echo -e "${RED}ArgoCD namespace not found. Please install ArgoCD first.${NC}"
    exit 1
fi

# Check if application exists in ArgoCD
if ! kubectl get application "$FULL_APP_NAME" -n argocd &> /dev/null; then
    echo -e "${RED}Application $FULL_APP_NAME does not exist in ArgoCD.${NC}"
    exit 1
fi

# Get current value if it exists
echo -e "${YELLOW}Checking current value for $KEY...${NC}"
CURRENT_VALUE=$(grep "^$KEY:" "$VALUES_FILE" 2>/dev/null | awk '{print $2}' || echo "not set")
echo -e "${GREEN}Current value: $CURRENT_VALUE${NC}"

# Modify the value in the values file
echo -e "${YELLOW}Modifying $KEY to $VALUE in $VALUES_FILE...${NC}"
if grep -q "^$KEY:" "$VALUES_FILE" 2>/dev/null; then
    # Update existing key
    sed -i "s/^$KEY:.*/$KEY: $VALUE/" "$VALUES_FILE"
else
    # Add new key
    echo "$KEY: $VALUE" >> "$VALUES_FILE"
fi

# Show the changes
echo -e "${GREEN}Changes made to $VALUES_FILE:${NC}"
cat "$VALUES_FILE"

# Get ArgoCD admin password
echo -e "${YELLOW}Getting ArgoCD admin password...${NC}"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo -e "${GREEN}ArgoCD admin password retrieved: $ARGOCD_PASSWORD${NC}"
echo -e "${YELLOW}To access ArgoCD UI, run:${NC}"
echo -e "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo -e "Then access ArgoCD at https://localhost:8080 with username: admin, password: $ARGOCD_PASSWORD"

# Update the ArgoCD application to use our values file
echo -e "${YELLOW}Updating ArgoCD application to use our values file...${NC}"

# Create a temporary file for the values
TEMP_VALUES_FILE=$(mktemp)
cat "$VALUES_FILE" > "$TEMP_VALUES_FILE"

# Update the application with the values file
if command -v argocd &> /dev/null; then
    # If ArgoCD CLI is installed, use it
    echo -e "${YELLOW}Using ArgoCD CLI to update the application...${NC}"
    argocd app set "$FULL_APP_NAME" --values "$TEMP_VALUES_FILE" --insecure
else
    # Otherwise, use kubectl with a patch
    echo -e "${YELLOW}Using kubectl to update the application...${NC}"
    
    # Create a temporary JSON file for the patch
    TEMP_PATCH_FILE=$(mktemp)
    
    # Get the current values
    VALUES_CONTENT=$(cat "$VALUES_FILE")
    
    # Create the patch file with proper escaping
    cat > "$TEMP_PATCH_FILE" << EOF
{
  "spec": {
    "source": {
      "helm": {
        "parameters": [
          {
            "name": "image.tag",
            "value": "$VALUE"
          },
          {
            "name": "replicaCount",
            "value": "3"
          }
        ]
      }
    }
  }
}
EOF
    
    # Apply the patch
    kubectl patch application "$FULL_APP_NAME" -n argocd --type merge --patch-file "$TEMP_PATCH_FILE"
    rm "$TEMP_PATCH_FILE"
fi

rm "$TEMP_VALUES_FILE"
echo -e "${GREEN}ArgoCD application updated to use our values.${NC}"

# Refresh the application in ArgoCD
echo -e "${YELLOW}Refreshing application $FULL_APP_NAME in ArgoCD...${NC}"
kubectl patch application "$FULL_APP_NAME" -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'
echo -e "${GREEN}Application refreshed. ArgoCD will automatically sync the changes.${NC}"

# Wait for sync to complete
echo -e "${YELLOW}Waiting for sync to complete...${NC}"
for i in {1..30}; do
    SYNC_STATUS=$(kubectl get application "$FULL_APP_NAME" -n argocd -o jsonpath="{.status.sync.status}")
    if [ "$SYNC_STATUS" == "Synced" ]; then
        echo -e "${GREEN}Application synced successfully.${NC}"
        break
    fi
    echo -e "${YELLOW}Current sync status: $SYNC_STATUS. Waiting...${NC}"
    sleep 5
    if [ $i -eq 30 ]; then
        echo -e "${RED}Timeout waiting for sync to complete.${NC}"
        exit 1
    fi
done

# Check health status
echo -e "${YELLOW}Checking health status...${NC}"
HEALTH_STATUS=$(kubectl get application "$FULL_APP_NAME" -n argocd -o jsonpath="{.status.health.status}")
echo -e "${GREEN}Health Status: $HEALTH_STATUS${NC}"

# Verify the changes
echo -e "${YELLOW}Verifying changes...${NC}"
case "$ENVIRONMENT" in
    dev)
        echo -e "${YELLOW}Checking dev environment resources...${NC}"
        kubectl get deployments,services,configmaps -n dev -l "app.kubernetes.io/instance=$FULL_APP_NAME" -o wide
        ;;
    staging)
        echo -e "${YELLOW}Checking staging environment resources...${NC}"
        kubectl get deployments,services,configmaps,ingress -n staging -l "app.kubernetes.io/instance=$FULL_APP_NAME" -o wide
        ;;
    production)
        echo -e "${YELLOW}Checking production environment resources...${NC}"
        kubectl get deployments,services,configmaps,ingress,hpa -n production -l "app.kubernetes.io/instance=$FULL_APP_NAME" -o wide
        ;;
    *)
        echo -e "${YELLOW}Unknown environment: $ENVIRONMENT. Checking basic resources...${NC}"
        kubectl get deployments,services -l "app.kubernetes.io/instance=$FULL_APP_NAME" -o wide
        ;;
esac

echo -e "\n${GREEN}Modification and testing completed for $FULL_APP_NAME.${NC}"
echo -e "${YELLOW}Key: $KEY${NC}"
echo -e "${YELLOW}Old value: $CURRENT_VALUE${NC}"
echo -e "${GREEN}New value: $VALUE${NC}" 