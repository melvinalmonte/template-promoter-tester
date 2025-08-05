# Custom Template 1 - Kubernetes Envbuilder Devcontainer

This template demonstrates running devcontainers on Kubernetes using Coder's envbuilder.

## Features

- **Kubernetes-native devcontainer execution** - Runs as pods in your cluster
- **Pre-configured development environment** with:
  - Ubuntu Noble base image  
  - Node.js (LTS), Python 3.11, Git
  - Zsh with Oh My Zsh
  - VS Code extensions and settings
- **Persistent workspace data** via Kubernetes PVCs
- **Integrated VS Code Server** for web-based development
- **Resource limits** configurable via template parameters

## How it Works

1. **Provisioning**: When you create a workspace:
   - Creates a ConfigMap with your devcontainer configuration
   - Creates a PVC for persistent workspace storage
   - Deploys a pod running envbuilder image

2. **Build Phase**: The envbuilder container:
   - Reads the devcontainer configuration from ConfigMap
   - Builds the development environment
   - Applies all devcontainer features

3. **Runtime**: The workspace runs as a Kubernetes pod with:
   - Coder agent for workspace management
   - Persistent volume for your code
   - Full devcontainer environment

## Usage

1. Create a workspace from this template
2. Access VS Code in your browser via the workspace dashboard
3. Start coding with all tools pre-installed!

## Architecture

```
KIND Cluster
  └── Kubernetes (coder namespace)
       └── Workspace Pod
            ├── Envbuilder Container
            ├── ConfigMap (devcontainer config)
            ├── PVC (workspace data)
            └── Coder Agent
```

## Parameters

- **CPU**: Number of CPU cores (1-8)
- **Memory**: RAM in GB (1-16)
- **Disk Size**: Storage in GB (1-100)

## Customization

The devcontainer configuration is embedded in the template. To customize:
1. Edit the `devcontainer_json` local in `main.tf`
2. Edit the `dockerfile_content` local in `main.tf`
3. Redeploy the template

## Requirements

- Coder instance running on Kubernetes
- StorageClass that supports dynamic PVC provisioning
- Sufficient cluster resources

## Troubleshooting

- **Pod not starting**: Check pod events with `kubectl describe pod`
- **Build failures**: Check envbuilder container logs
- **Storage issues**: Verify PVC is bound and StorageClass exists