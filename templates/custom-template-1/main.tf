# Local values for convenience
locals {
  workspace_name = lower("${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}")
  workspace_dir  = "/tmp/workspace-${local.workspace_name}"
  
  # Simulated resource status
  fake_resource_status = {
    container_id = "dummy-${substr(md5(local.workspace_name), 0, 12)}"
    ip_address   = "10.0.0.${(data.coder_workspace.me.transition == "start" ? "100" : "0")}"
    status       = data.coder_workspace.me.transition == "start" ? "running" : "stopped"
  }
  
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
      "ghcr.io/devcontainers/features/docker-in-docker:2" = {
        version = "latest"
        moby = true
      }
    }
    
    customizations = {
      vscode = {
        extensions = [
          "ms-vscode.vscode-typescript-next",
          "bradlc.vscode-tailwindcss",
          "esbenp.prettier-vscode",
          "ms-python.python",
          "ms-python.pylint"
        ]
        settings = {
          "terminal.integrated.defaultProfile.linux" = "zsh"
          "editor.formatOnSave" = true
          "editor.codeActionsOnSave" = {
            "source.fixAll" = true
          }
        }
      }
    }
    
    forwardPorts = [3000, 8000, 8080]
    portsAttributes = {
      "3000" = {
        label = "Application"
        onAutoForward = "notify"
      }
      "8000" = {
        label = "Development Server"
        onAutoForward = "openPreview"
      }
    }
    
    postCreateCommand = "echo 'Welcome to your development environment!' && npm --version && python3 --version"
    
    remoteUser = "vscode"
    
    mounts = [
      "source=/var/run/docker.sock,target=/var/run/docker-host.sock,type=bind"
    ]
  }
}

# Create workspace directory structure
resource "null_resource" "workspace_dirs" {
  count = data.coder_workspace.me.start_count
  
  triggers = {
    workspace_dir = local.workspace_dir
  }
  
  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${local.workspace_dir}/.devcontainer
      mkdir -p ${local.workspace_dir}/src
      mkdir -p ${local.workspace_dir}/.vscode
    EOT
  }
  
  provisioner "local-exec" {
    when = destroy
    command = "rm -rf ${self.triggers.workspace_dir}"
  }
}

# Create devcontainer.json file
resource "local_file" "devcontainer_json" {
  count    = data.coder_workspace.me.start_count
  filename = "${local.workspace_dir}/.devcontainer/devcontainer.json"
  content  = jsonencode(local.devcontainer_config)
  
  depends_on = [null_resource.workspace_dirs]
}

# Create a sample README for the workspace
resource "local_file" "readme" {
  count    = data.coder_workspace.me.start_count
  filename = "${local.workspace_dir}/README.md"
  content  = <<-EOT
# ${title(replace(local.workspace_name, "-", " "))} Development Workspace

This workspace is configured with a devcontainer for consistent development environments.

## Getting Started

1. Open this workspace in VS Code
2. When prompted, click "Reopen in Container" or run the command "Dev Containers: Reopen in Container"
3. VS Code will build the development container with all necessary tools and extensions

## What's Included

- **Base Image**: Microsoft's Universal devcontainer image
- **Languages**: Node.js (LTS), Python 3.11
- **Tools**: Git, Docker-in-Docker, Oh My Zsh
- **VS Code Extensions**: TypeScript, Tailwind CSS, Prettier, Python support
- **Port Forwarding**: Ports 3000, 8000, and 8080 are automatically forwarded

## Workspace Structure

```
${local.workspace_name}/
├── .devcontainer/
│   └── devcontainer.json    # Container configuration
├── .vscode/                 # VS Code settings
├── src/                     # Your source code
└── README.md               # This file
```

## Development

The container includes:
- Node.js and npm for JavaScript/TypeScript development
- Python 3.11 with pip for Python development  
- Docker-in-Docker for containerized applications
- Git for version control
- Zsh with Oh My Zsh for an enhanced terminal experience

Happy coding! 🚀
  EOT
  
  depends_on = [null_resource.workspace_dirs]
}

# Create basic VS Code workspace settings
resource "local_file" "vscode_settings" {
  count    = data.coder_workspace.me.start_count
  filename = "${local.workspace_dir}/.vscode/settings.json"
  content = jsonencode({
    "terminal.integrated.defaultProfile.linux" = "zsh"
    "editor.formatOnSave" = true
    "files.autoSave" = "afterDelay"
    "editor.minimap.enabled" = false
    "workbench.colorTheme" = "Default Dark+"
  })
  
  depends_on = [null_resource.workspace_dirs]
}

# Dummy resource that represents our "infrastructure"
resource "null_resource" "workspace" {
  count = data.coder_workspace.me.start_count
  
  triggers = {
    workspace_id   = data.coder_workspace.me.id
    workspace_name = local.workspace_name
    cpu            = data.coder_parameter.cpu.value
    memory         = data.coder_parameter.memory.value
    always_run     = timestamp()
  }
  
  # Download and run the Coder agent binary
  provisioner "local-exec" {
    command = <<-EOT
      echo 'Setting up devcontainer workspace ${local.workspace_name}'
      
      # Create the workspace directory first
      mkdir -p ${local.workspace_dir}
      cd ${local.workspace_dir}
      
      # Run the startup script to set up file server and devcontainer
      bash -c '${replace(coder_agent.main.init_script, "'", "'\\''")}' > /tmp/coder-agent-${local.workspace_name}-setup.log 2>&1
      
      # Download the Coder agent binary
      echo 'Downloading Coder agent...'
      curl -fsSL "${data.coder_workspace.me.access_url}/bin/coder-darwin-amd64" -o /tmp/coder-agent-${local.workspace_name} || {
        echo 'Failed to download agent, using curl fallback'
        curl -fsSL "${data.coder_workspace.me.access_url}/api/v2/users/me/workspace/agent" -H "Coder-Session-Token: ${coder_agent.main.token}" -o /tmp/coder-agent-${local.workspace_name}
      }
      chmod +x /tmp/coder-agent-${local.workspace_name}
      
      # Start the Coder agent with proper environment
      echo 'Starting Coder agent...'
      cd ${local.workspace_dir}
      CODER_AGENT_TOKEN="${coder_agent.main.token}" \
      CODER_AGENT_URL="${data.coder_workspace.me.access_url}" \
      nohup /tmp/coder-agent-${local.workspace_name} > /tmp/coder-agent-${local.workspace_name}.log 2>&1 &
      echo $! > /tmp/coder-agent-${local.workspace_name}.pid
      
      echo 'Coder agent started successfully'
    EOT
  }
  
  # Cleanup agent and resources
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo 'Stopping devcontainer workspace ${self.triggers.workspace_name}'
      
      # Stop the Coder agent
      if [ -f /tmp/coder-agent-${self.triggers.workspace_name}.pid ]; then
        PID=$(cat /tmp/coder-agent-${self.triggers.workspace_name}.pid)
        kill $PID 2>/dev/null || true
        rm -f /tmp/coder-agent-${self.triggers.workspace_name}.pid
        rm -f /tmp/coder-agent-${self.triggers.workspace_name}.log
        rm -f /tmp/coder-agent-${self.triggers.workspace_name}-setup.log
        rm -f /tmp/coder-agent-${self.triggers.workspace_name}
      fi
      
      # Stop the file server
      if [ -f /tmp/devcontainer-server.pid ]; then
        PID=$(cat /tmp/devcontainer-server.pid)
        kill $PID 2>/dev/null || true
        rm -f /tmp/devcontainer-server.pid
      fi
      
      echo 'Cleanup completed'
    EOT
  }
  
  depends_on = [
    local_file.devcontainer_json,
    local_file.readme,
    local_file.vscode_settings
  ]
}

# Create a dummy state file to simulate persistence
resource "local_file" "workspace_state" {
  count    = data.coder_workspace.me.start_count
  filename = "/tmp/coder-dummy-${local.workspace_name}.state"
  content  = jsonencode({
    workspace_id = data.coder_workspace.me.id
    owner        = data.coder_workspace.me.owner
    name         = data.coder_workspace.me.name
    created_at   = timestamp()
    workspace_dir = local.workspace_dir
    resources    = {
      cpu    = data.coder_parameter.cpu.value
      memory = data.coder_parameter.memory.value
      disk   = data.coder_parameter.disk_size.value
    }
    dotfiles_repo = data.coder_parameter.dotfiles_repo.value
    container_status = "running"
    devcontainer     = true
  })
  
  depends_on = [null_resource.workspace]
}

# Coder agent - this is required for Coder to manage the workspace
resource "coder_agent" "main" {
  arch = "amd64"
  os   = "darwin"  # macOS
  dir  = local.workspace_dir
  
  # Environment variables for VS Code integration
  env = {
    GIT_AUTHOR_NAME     = data.coder_workspace.me.owner
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace.me.owner}@example.com"
    GIT_COMMITTER_NAME  = data.coder_workspace.me.owner
    GIT_COMMITTER_EMAIL = "${data.coder_workspace.me.owner}@example.com"
  }
  
  # Startup script that sets up the environment but doesn't block
  startup_script = <<-EOT
    #!/bin/bash
    set -e
    
    echo "🐳 Starting devcontainer workspace..."
    echo "📊 Resources allocated:"
    echo "   - CPU: ${data.coder_parameter.cpu.value} cores"
    echo "   - Memory: ${data.coder_parameter.memory.value} GB"
    echo "   - Disk: ${data.coder_parameter.disk_size.value} GB"
    
    echo "📁 Workspace directory: ${local.workspace_dir}"
    echo "🐳 Devcontainer configuration ready!"
    
    # Simple HTTP server to serve devcontainer files
    echo "🌐 Starting simple file server..."
    cd ${local.workspace_dir}
    python3 -m http.server 8080 > /dev/null 2>&1 &
    echo $! > /tmp/devcontainer-server.pid
    
    echo "✅ Devcontainer workspace ready!"
    echo "📄 Devcontainer config: ${local.workspace_dir}/.devcontainer/devcontainer.json"
    echo "🌐 File server: http://localhost:8080"
  EOT
  
  # Shutdown script
  shutdown_script = <<-EOT
    #!/bin/bash
    echo "🛑 Shutting down devcontainer workspace..."
    
    # Stop file server if running
    if [ -f /tmp/devcontainer-server.pid ]; then
      PID=$(cat /tmp/devcontainer-server.pid)
      if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping file server (PID: $PID)..."
        kill "$PID" || true
      fi
      rm -f /tmp/devcontainer-server.pid
    fi
    
    # Cleanup any remaining processes
    pkill -f "python3 -m http.server" || true
    
    echo "✅ Devcontainer workspace stopped"
  EOT
  
  # Minimal connection options - no VS Code apps
  display_apps {
    web_terminal    = false
    ssh_helper      = false
    port_forwarding_helper = false
  }
}

# Devcontainer info app - simple file browser
resource "coder_app" "devcontainer_info" {
  agent_id     = coder_agent.main.id
  slug         = "devcontainer"
  display_name = "Devcontainer Info"
  icon         = "/icon/docker.svg"
  url          = "http://localhost:8080/.devcontainer/devcontainer.json"
  subdomain    = false
  share        = "owner"
  
  healthcheck {
    url       = "http://localhost:8080"
    interval  = 30
    threshold = 3
  }
}

# Metadata for the Coder UI
resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = null_resource.workspace[0].id
  
  item {
    key   = "Type"
    value = "Devcontainer Workspace"
  }
  
  item {
    key   = "CPU"
    value = "${data.coder_parameter.cpu.value} cores"
  }
  
  item {
    key   = "Memory"
    value = "${data.coder_parameter.memory.value} GB"
  }
  
  item {
    key   = "Disk"
    value = "${data.coder_parameter.disk_size.value} GB"
  }
  
  item {
    key   = "File Server"
    value = "http://localhost:8080"
  }
  
  item {
    key   = "Devcontainer Config"
    value = "${local.workspace_dir}/.devcontainer/devcontainer.json"
  }
  
  item {
    key   = "Workspace Path"
    value = local.workspace_dir
  }
  
  item {
    key   = "Devcontainer"
    value = "✅ Configured"
  }
}

# Show some helpful info in the logs
resource "null_resource" "startup_message" {
  count = data.coder_workspace.me.start_count
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "=========================================="
      echo "🎭 DUMMY WORKSPACE WITH DEVCONTAINER CREATED"
      echo "=========================================="
      echo "This is a simulated workspace for testing."
      echo "No real resources have been provisioned."
      echo ""
      echo "Workspace Details:"
      echo "- Name: ${local.workspace_name}"
      echo "- Owner: ${data.coder_workspace.me.owner}"
      echo "- ID: ${data.coder_workspace.me.id}"
      echo "- Path: ${local.workspace_dir}"
      echo ""
      echo "Simulated Resources:"
      echo "- CPU: ${data.coder_parameter.cpu.value} cores"
      echo "- Memory: ${data.coder_parameter.memory.value} GB"
      echo "- Disk: ${data.coder_parameter.disk_size.value} GB"
      echo ""
      echo "🐳 Devcontainer Features:"
      echo "- Base Image: mcr.microsoft.com/devcontainers/universal:2"
      echo "- Languages: Node.js (LTS), Python 3.11"
      echo "- Tools: Git, Docker-in-Docker, Oh My Zsh"
      echo "- VS Code Extensions: TypeScript, Python, Prettier, etc."
      echo "- Port Forwarding: 3000, 8000, 8080"
      echo ""
      echo "📝 Files Created:"
      echo "- ${local.workspace_dir}/.devcontainer/devcontainer.json"
      echo "- ${local.workspace_dir}/README.md"
      echo "- ${local.workspace_dir}/.vscode/settings.json"
      echo "=========================================="
    EOT
  }
  
  depends_on = [
    local_file.devcontainer_json,
    local_file.readme,
    local_file.vscode_settings
  ]
}