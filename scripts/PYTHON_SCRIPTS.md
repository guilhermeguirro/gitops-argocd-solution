# Python Scripts for ArgoCD Helm Testing

This directory contains Python scripts for testing and modifying Helm charts with ArgoCD. These scripts provide improved error handling, better YAML processing, and more structured code compared to their shell script counterparts.

## Prerequisites

- Python 3.6+
- kubectl
- ArgoCD installed in your Kubernetes cluster

### Optional Dependencies

- PyYAML: For better YAML handling
  ```
  pip install pyyaml
  ```

## Scripts

### test-argocd-helm.py

This script tests Helm charts deployed with ArgoCD by checking application states and verifying resources in the appropriate namespaces.

#### Usage

```bash
./test-argocd-helm.py
```

#### Features

- Checks if kubectl and ArgoCD are installed
- Retrieves the ArgoCD admin password
- Tests applications by checking their existence, sync status, health status, and Kubernetes resources
- Provides detailed output for each test

### modify-and-test-helm.py

This script modifies a Helm chart value and tests the changes using ArgoCD. It updates the values file, applies the changes to ArgoCD, and verifies the deployment.

#### Usage

```bash
./modify-and-test-helm.py <app-name> <environment> <key> <value>
```

#### Example

```bash
./modify-and-test-helm.py app1 dev replicaCount 3
./modify-and-test-helm.py app1 dev image.tag 1.25.3-debian-11-r5
```

#### Features

- Validates input parameters
- Creates the necessary directories and files if they don't exist
- Modifies the specified key in the Helm values file
- Updates the ArgoCD application with the new values
- Refreshes the application in ArgoCD
- Waits for the sync to complete
- Verifies the changes in the Kubernetes resources

### promote-blue-green.py

This script promotes the green deployment in a blue-green deployment setup. It scales up the green deployment, updates the services, and scales down the blue deployment.

#### Usage

```bash
./promote-blue-green.py <app-name> <namespace> [--replicas REPLICAS] [--skip-confirmation]
```

#### Example

```bash
# Promote the green deployment for app1 in the production namespace
./promote-blue-green.py app1 production

# Promote with 4 replicas and skip the confirmation prompt
./promote-blue-green.py app1 production --replicas 4 --skip-confirmation
```

#### Features

- Scales up the green deployment to the specified number of replicas
- Waits for the green deployment to be ready
- Updates the preview service to point to the green deployment
- Allows for manual verification before proceeding (can be skipped)
- Updates the active service to point to the green deployment
- Scales down the blue deployment

## Comparison with Shell Scripts

The Python scripts offer several advantages over their shell script counterparts:

1. **Better Error Handling**: More robust error handling with try-except blocks
2. **Improved YAML Processing**: Better handling of YAML files, especially with PyYAML
3. **Structured Code**: More organized code with functions and classes
4. **Cross-Platform**: Works on Windows, macOS, and Linux
5. **Better Parameter Handling**: Uses argparse for better command-line argument parsing

## Troubleshooting

### PyYAML Not Installed

If you see the message "PyYAML not installed", the script will fall back to simple text-based YAML processing. For better YAML handling, install PyYAML:

```bash
pip install pyyaml
```

### ArgoCD Not Accessible

If the script cannot access ArgoCD, make sure ArgoCD is installed and running in your Kubernetes cluster:

```bash
kubectl get pods -n argocd
```

### Application Not Found

If the script cannot find the application, make sure the application exists in ArgoCD:

```bash
kubectl get applications -n argocd
``` 