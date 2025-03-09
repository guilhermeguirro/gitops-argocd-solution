# GitOps Solution with ArgoCD

[![Validate GitOps Solution](https://github.com/guilhermeguirro/gitops-argocd-solution/actions/workflows/validate.yml/badge.svg)](https://github.com/guilhermeguirro/gitops-argocd-solution/actions/workflows/validate.yml)
[![Test Deployment](https://github.com/guilhermeguirro/gitops-argocd-solution/actions/workflows/test-deployment.yml/badge.svg)](https://github.com/guilhermeguirro/gitops-argocd-solution/actions/workflows/test-deployment.yml)
[![Security Scan](https://github.com/guilhermeguirro/gitops-argocd-solution/actions/workflows/security-scan.yml/badge.svg)](https://github.com/guilhermeguirro/gitops-argocd-solution/actions/workflows/security-scan.yml)

This repository contains a comprehensive GitOps solution using ArgoCD, demonstrating best practices for continuous delivery with Kubernetes.

## Features

- **Multi-Environment Deployment**: Automated deployment across dev, staging, and production environments
- **Progressive Delivery**: Controlled promotion of changes through environments with validation gates
- **Advanced Deployment Strategies**: Canary and Blue-Green deployment patterns
- **Validation Gates**: Automated health checks before promotion
- **Rollback Capability**: Easy rollback to previous versions

## Architecture

The solution follows these GitOps principles:

1. **Git as Single Source of Truth**: All configuration is stored in Git
2. **Declarative Infrastructure**: All resources are defined as code
3. **Continuous Deployment**: Changes are automatically deployed
4. **Progressive Delivery**: Changes are gradually rolled out across environments
5. **Automated Validation**: Health checks are performed before promotion

## Directory Structure

```
gitops-solution/
├── base/                   # Base templates for applications
├── environments/           # Environment-specific configurations
│   ├── dev/                # Development environment
│   ├── staging/            # Staging environment
│   └── production/         # Production environment
├── manifests/              # Kubernetes manifests for advanced deployment patterns
│   ├── canary/             # Canary deployment manifests
│   └── blue-green/         # Blue-Green deployment manifests
└── scripts/                # Utility scripts for managing the GitOps workflow
```

## Scripts

The `scripts` directory contains various utility scripts to help with the GitOps workflow:

### Setup Scripts

- **setup-argocd.sh**: Sets up ArgoCD in your Kubernetes cluster and creates the necessary namespaces.

### Deployment Scripts

- **validate-and-promote.sh**: Validates a deployment in one environment and promotes it to the next environment.
- **promote-blue-green.sh**: Promotes a blue-green deployment by switching traffic from blue to green.
- **canary-promote.sh**: Promotes a canary deployment by gradually increasing traffic to the new version.
- **rollback.sh**: Rolls back a deployment to a previous version.
- **promote-blue-green.py**: Python version of the blue-green promotion script with improved error handling and command-line options.

### Testing Scripts

- **test-argocd-helm.sh**: Tests Helm charts with ArgoCD by checking application states and verifying resources.
  ```
  ./test-argocd-helm.sh
  ```

- **test-argocd-helm.py**: Python version of the test script with improved error handling and output formatting.
  ```
  ./test-argocd-helm.py
  ```

- **modify-and-test-helm.sh**: Modifies a Helm chart value and tests the changes using ArgoCD.
  ```
  ./modify-and-test-helm.sh <app-name> <environment> <key> <value>
  
  Example:
  ./modify-and-test-helm.sh app1 dev replicaCount 3
  ```

- **modify-and-test-helm.py**: Python version of the modification script with improved error handling and better YAML processing.
  ```
  ./modify-and-test-helm.py <app-name> <environment> <key> <value>
  
  Example:
  ./modify-and-test-helm.py app1 dev replicaCount 3
  ```

For more details on the Python scripts, see [PYTHON_SCRIPTS.md](scripts/PYTHON_SCRIPTS.md).

## Getting Started

### Prerequisites

- Kubernetes cluster (minikube, kind, or any other)
- kubectl
- ArgoCD CLI
- jq

### Setup

1. **Setup ArgoCD**:
   ```
   cd scripts
   ./setup-argocd.sh
   ```

2. **Access ArgoCD UI**:
   ```
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
   Then access ArgoCD at https://localhost:8080 with username: admin, password: (retrieved from script)

3. **Test Applications**:
   ```
   cd scripts
   ./test-argocd-helm.sh
   ```

4. **Modify and Test Helm Values**:
   ```
   cd scripts
   ./modify-and-test-helm.sh app1 dev replicaCount 3
   ```

5. **Validate and Promote**:
   ```
   cd scripts
   ./validate-and-promote.sh app1 dev staging
   ```

6. **Promote Blue-Green Deployment**:
   ```
   cd scripts
   ./promote-blue-green.sh
   ```

7. **Promote Blue-Green Deployment (Python Version)**:
   ```
   cd scripts
   ./promote-blue-green.py app1 production --replicas 4 --skip-confirmation
   ```

8. **Promote Canary Deployment**:
   ```
   cd scripts
   ./canary-promote.sh app1 production 50
   ```

9. **Rollback Deployment**:
   ```
   cd scripts
   ./rollback.sh app1 production
   ```

## Best Practices

1. Always test changes in dev before promoting to staging and production
2. Use feature flags for risky changes
3. Monitor deployments closely
4. Have a rollback plan ready
5. Document all changes

## Extending the Solution

This solution can be extended with:

1. **CI/CD Integration**: Connect to Jenkins, GitHub Actions, or GitLab CI
2. **Monitoring**: Add Prometheus and Grafana for monitoring
3. **Notifications**: Configure ArgoCD to send notifications
4. **Security Scanning**: Add container image scanning
5. **Policy Enforcement**: Implement Open Policy Agent (OPA)

## Troubleshooting

### Port Forwarding Issues

If you see errors like "broken pipe" in the port forwarding output, this is normal and doesn't affect functionality. These are just connection resets from the browser.

### Application Sync Issues

If an application fails to sync:

1. Check the application status: `argocd app get <app-name>`
2. Check the logs: `kubectl logs -n argocd deployment/argocd-application-controller`
3. Try manual sync: `argocd app sync <app-name> --force`

## License

This project is licensed under the MIT License - see the LICENSE file for details. 