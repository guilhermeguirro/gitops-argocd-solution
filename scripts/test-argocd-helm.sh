#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

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

# Get ArgoCD admin password
echo -e "${YELLOW}Getting ArgoCD admin password...${NC}"
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo -e "${GREEN}ArgoCD admin password retrieved: $ARGOCD_PASSWORD${NC}"
echo -e "${YELLOW}To access ArgoCD UI, run:${NC}"
echo -e "kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo -e "Then access ArgoCD at https://localhost:8080 with username: admin, password: $ARGOCD_PASSWORD"

# Function to test an application
test_application() {
    local app_name=$1
    local env=${app_name##*-}  # Extract environment from app name
    local app_base=${app_name%-*}  # Extract base app name without environment
    
    echo -e "\n${YELLOW}Testing application: ${app_name}${NC}"
    
    # Check if application exists
    if ! kubectl get application "$app_name" -n argocd &> /dev/null; then
        echo -e "${RED}Application $app_name does not exist in ArgoCD.${NC}"
        return 1
    fi
    
    # Check application status
    echo -e "${YELLOW}Checking application status...${NC}"
    kubectl get application "$app_name" -n argocd -o jsonpath="{.status.sync.status}" > /dev/null
    if [ $? -eq 0 ]; then
        SYNC_STATUS=$(kubectl get application "$app_name" -n argocd -o jsonpath="{.status.sync.status}")
        echo -e "${GREEN}Sync Status: $SYNC_STATUS${NC}"
    else
        echo -e "${RED}Failed to get sync status for $app_name${NC}"
        return 1
    fi
    
    # Check health status
    echo -e "${YELLOW}Checking health status...${NC}"
    kubectl get application "$app_name" -n argocd -o jsonpath="{.status.health.status}" > /dev/null
    if [ $? -eq 0 ]; then
        HEALTH_STATUS=$(kubectl get application "$app_name" -n argocd -o jsonpath="{.status.health.status}")
        echo -e "${GREEN}Health Status: $HEALTH_STATUS${NC}"
    else
        echo -e "${RED}Failed to get health status for $app_name${NC}"
        return 1
    fi
    
    # Check Kubernetes resources based on environment
    echo -e "${YELLOW}Checking Kubernetes resources...${NC}"
    case "$env" in
        dev)
            echo -e "${YELLOW}Checking dev environment resources...${NC}"
            kubectl get deployments,services,configmaps -n dev -l "app.kubernetes.io/instance=$app_name" -o wide || echo "No resources found with label app.kubernetes.io/instance=$app_name in dev namespace"
            ;;
        staging)
            echo -e "${YELLOW}Checking staging environment resources...${NC}"
            kubectl get deployments,services,configmaps,ingress -n staging -l "app.kubernetes.io/instance=$app_name" -o wide || echo "No resources found with label app.kubernetes.io/instance=$app_name in staging namespace"
            ;;
        production)
            echo -e "${YELLOW}Checking production environment resources...${NC}"
            kubectl get deployments,services,configmaps,ingress,hpa -n production -l "app.kubernetes.io/instance=$app_name" -o wide || echo "No resources found with label app.kubernetes.io/instance=$app_name in production namespace"
            ;;
        *)
            echo -e "${YELLOW}Unknown environment: $env. Checking basic resources...${NC}"
            kubectl get deployments,services -l "app.kubernetes.io/instance=$app_name" -o wide || echo "No resources found with label app.kubernetes.io/instance=$app_name"
            ;;
    esac
    
    echo -e "${GREEN}Test completed for $app_name${NC}"
    return 0
}

# Test applications
test_application "app1-dev"
test_application "app1-staging"
test_application "app1-production"

echo -e "\n${GREEN}All tests completed.${NC}" 