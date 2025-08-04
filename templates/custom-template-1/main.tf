# Local values for workspace
locals {
  workspace_name = lower("${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}")
  workspace_dir  = "/tmp/workspace-${local.workspace_name}"
  
  # Devcontainer configuration
  devcontainer_config = {
    name = "Development Container"
    image = "mcr.microsoft.com/devcontainers/universal:2"
    
    features = {
      "ghcr.io/devcontainers/features/common-utils:2" = {
        installZsh = true
        configureZshAsDefaultShell = true
        installOhMyZsh = true
      }
      "ghcr.io/devcontainers/features/node:1" = {
        nodeGypDependencies = true
        version = "lts"
      }
      "ghcr.io/devcontainers/features/python:1" = {
        version = "3.11"
      }
      "ghcr.io/devcontainers/features/git:1" = {
        ppa = true
        version = "latest"
      }
    }
    
    customizations = {
      vscode = {
        extensions = [
          "ms-vscode.vscode-typescript-next",
          "esbenp.prettier-vscode",
          "ms-python.python"
        ]
        settings = {
          "terminal.integrated.defaultProfile.linux" = "zsh"
          "editor.formatOnSave" = true
        }
      }
    }
    
    forwardPorts = [3000, 8000, 8080]
    postCreateCommand = "echo 'Devcontainer ready!'"
    remoteUser = "vscode"
  }
}

# Create workspace directory structure
resource "null_resource" "workspace_dirs" {
  count = data.coder_workspace.me.start_count
  
  provisioner "local-exec" {
    command = "mkdir -p ${local.workspace_dir}/.devcontainer"
  }
}

# Create devcontainer.json file
resource "local_file" "devcontainer_json" {
  count    = data.coder_workspace.me.start_count
  filename = "${local.workspace_dir}/.devcontainer/devcontainer.json"
  content  = jsonencode(local.devcontainer_config)
  
  depends_on = [null_resource.workspace_dirs]
}

# Create a simple README
resource "local_file" "readme" {
  count    = data.coder_workspace.me.start_count
  filename = "${local.workspace_dir}/README.md"
  content  = <<-EOT
# ${title(replace(local.workspace_name, "-", " "))} Devcontainer Workspace

This workspace includes a preconfigured devcontainer.

## Usage

1. Open this workspace in VS Code
2. Click "Reopen in Container" when prompted  
3. VS Code will build and start the development container

## What's Included

- Node.js (LTS) and Python 3.11
- Git, Zsh with Oh My Zsh
- VS Code extensions for TypeScript, Python, and Prettier
- Port forwarding for ports 3000, 8000, and 8080

The devcontainer configuration is in `.devcontainer/devcontainer.json`.
  EOT
  
  depends_on = [null_resource.workspace_dirs]
}