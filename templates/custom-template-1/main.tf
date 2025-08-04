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

# Create devcontainer info HTML page
resource "local_file" "devcontainer_info_html" {
  count    = data.coder_workspace.me.start_count
  filename = "${local.workspace_dir}/devcontainer-info.html"
  content  = <<-EOT
<!DOCTYPE html>
<html>
<head>
    <title>Devcontainer Configuration</title>
    <style>
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', monospace; 
            background: #1e1e1e; 
            color: #d4d4d4; 
            padding: 20px; 
            margin: 0;
        }
        .container { max-width: 1000px; margin: 0 auto; }
        h1 { color: #569cd6; }
        .info-box { 
            background: #2d2d30; 
            padding: 15px; 
            border-radius: 6px; 
            margin-bottom: 15px;
        }
        pre { 
            background: #0d1117; 
            padding: 15px; 
            border-radius: 6px; 
            overflow-x: auto;
            font-size: 12px;
        }
        .status { color: #4CAF50; }
        .path { color: #FFA726; font-family: monospace; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐳 Devcontainer Configuration</h1>
        
        <div class="info-box">
            <h3>Status</h3>
            <p class="status">✅ Devcontainer ready for VS Code</p>
            <p><strong>Workspace:</strong> <span class="path">${local.workspace_dir}</span></p>
        </div>

        <div class="info-box">
            <h3>Configuration</h3>
            <pre>${jsonencode(local.devcontainer_config)}</pre>
        </div>

        <div class="info-box">
            <h3>Quick Start</h3>
            <ol>
                <li>Open this workspace in VS Code</li>
                <li>Click "Reopen in Container" when prompted</li>
                <li>VS Code will build your development container</li>
            </ol>
        </div>
    </div>
</body>
</html>
  EOT
  
  depends_on = [local_file.devcontainer_json]
}

# Minimal agent for the devcontainer info button
resource "coder_agent" "main" {
  arch = "amd64" 
  os   = "darwin"
  dir  = local.workspace_dir
  
  startup_script = <<-EOT
    #!/bin/bash
    echo "🐳 Devcontainer workspace ready"
    cd ${local.workspace_dir}
    python3 -m http.server 8080 > /dev/null 2>&1 &
    echo "📄 Devcontainer info: http://localhost:8080/devcontainer-info.html"
  EOT
}

# Simple devcontainer info app
resource "coder_app" "devcontainer_info" {
  agent_id     = coder_agent.main.id
  slug         = "devcontainer"
  display_name = "Devcontainer Info"
  icon         = "/icon/docker.svg"
  url          = "http://localhost:8080/devcontainer-info.html"
  subdomain    = false
  share        = "owner"
}