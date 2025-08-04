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
  
  # Simulate provisioning
  provisioner "local-exec" {
    command = "echo 'Starting dummy workspace ${local.workspace_name} with ${data.coder_parameter.cpu.value} CPUs and ${data.coder_parameter.memory.value}GB RAM'"
  }
  
  # Simulate cleanup
  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Stopping dummy workspace ${self.triggers.workspace_name}'"
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
    status        = local.fake_resource_status
    devcontainer  = true
  })
  
  depends_on = [null_resource.workspace]
}

# Coder agent - this is required for Coder to manage the workspace
resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"
  dir  = local.workspace_dir
  
  # Environment variables for VS Code integration
  env = {
    GIT_AUTHOR_NAME     = data.coder_workspace.me.owner
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace.me.owner}@example.com"
    GIT_COMMITTER_NAME  = data.coder_workspace.me.owner
    GIT_COMMITTER_EMAIL = "${data.coder_workspace.me.owner}@example.com"
  }
  
  # Startup script that simulates workspace initialization
  startup_script = <<-EOT
    #!/bin/bash
    set -e
    
    echo "🚀 Starting dummy workspace with VS Code support..."
    echo "📊 Resources allocated:"
    echo "   - CPU: ${data.coder_parameter.cpu.value} cores"
    echo "   - Memory: ${data.coder_parameter.memory.value} GB"
    echo "   - Disk: ${data.coder_parameter.disk_size.value} GB"
    
    echo "📁 Workspace directory: ${local.workspace_dir}"
    echo "🐳 Devcontainer configuration ready at: ${local.workspace_dir}/.devcontainer/devcontainer.json"
    
    # Install code-server for web-based VS Code
    echo "🔧 Installing code-server..."
    curl -fsSL https://code-server.dev/install.sh | sh > /dev/null 2>&1 || {
      echo "⚠️  Failed to install code-server, using simulated version"
      # Create a simple HTTP server as fallback
      mkdir -p ~/.local/share/code-server
      cd ${local.workspace_dir}
      python3 -m http.server 13337 > /dev/null 2>&1 &
      echo $! > ~/.local/share/code-server/pid
      CODE_SERVER_STARTED="simulated"
    }
    
    # Start code-server if installation succeeded
    if [ "$CODE_SERVER_STARTED" != "simulated" ]; then
      echo "🚀 Starting code-server on port 13337..."
      mkdir -p ~/.local/share/code-server
      code-server \
        --bind-addr 0.0.0.0:13337 \
        --auth none \
        --disable-telemetry \
        --disable-update-check \
        ${local.workspace_dir} > ~/.local/share/code-server/log 2>&1 &
      echo $! > ~/.local/share/code-server/pid
      
      # Wait for code-server to start
      for i in {1..30}; do
        if curl -s http://localhost:13337/healthz > /dev/null 2>&1; then
          echo "✅ Code-server started successfully"
          break
        fi
        sleep 1
      done
    fi
    
    # Create VS Code workspace file
    echo "📝 Creating VS Code workspace configuration..."
    cat > ${local.workspace_dir}/workspace.code-workspace << 'EOF'
{
  "folders": [
    {
      "name": "Workspace Root",
      "path": "."
    },
    {
      "name": "Source Code",
      "path": "./src"
    }
  ],
  "settings": {
    "terminal.integrated.defaultProfile.linux": "bash",
    "editor.formatOnSave": true,
    "files.autoSave": "afterDelay",
    "editor.minimap.enabled": false,
    "workbench.colorTheme": "Default Dark+",
    "workbench.startupEditor": "readme"
  },
  "extensions": {
    "recommendations": [
      "ms-vscode.vscode-typescript-next",
      "bradlc.vscode-tailwindcss",
      "esbenp.prettier-vscode",
      "ms-python.python"
    ]
  }
}
EOF
    
    # Simulate dotfiles setup
    if [ -n "${data.coder_parameter.dotfiles_repo.value}" ]; then
      echo "📁 Would clone dotfiles from: ${data.coder_parameter.dotfiles_repo.value}"
      echo "   (This is a dummy workspace - no actual cloning performed)"
    fi
    
    echo "✅ Dummy workspace with VS Code ready!"
    echo "🔧 VS Code connection options:"
    echo "   1. Web VS Code: http://localhost:13337 (accessible via Coder dashboard)"
    echo "   2. Desktop VS Code: Use the 'VS Code Desktop' app in Coder dashboard"
    echo "   3. VS Code Insiders: Use the 'VS Code Insiders' app in Coder dashboard"
    echo "   4. Devcontainer: Open workspace.code-workspace and click 'Reopen in Container'"
    echo "ℹ️  This is a simulated environment for testing purposes"
    
    # Keep the agent running
    while true; do
      sleep 30
      if [ -f ~/.local/share/code-server/pid ]; then
        PID=$(cat ~/.local/share/code-server/pid)
        if ! kill -0 "$PID" 2>/dev/null; then
          echo "⚠️  Code-server process died, restarting..."
          # Restart the appropriate service
          if [ "$CODE_SERVER_STARTED" = "simulated" ]; then
            cd ${local.workspace_dir}
            python3 -m http.server 13337 > /dev/null 2>&1 &
            echo $! > ~/.local/share/code-server/pid
          else
            code-server \
              --bind-addr 0.0.0.0:13337 \
              --auth none \
              --disable-telemetry \
              --disable-update-check \
              ${local.workspace_dir} > ~/.local/share/code-server/log 2>&1 &
            echo $! > ~/.local/share/code-server/pid
          fi
        fi
      fi
      echo "💓 Dummy workspace heartbeat at $(date)"
    done &
  EOT
  
  # Shutdown script
  shutdown_script = <<-EOT
    #!/bin/bash
    echo "🛑 Shutting down dummy workspace..."
    
    # Stop code-server if running
    if [ -f ~/.local/share/code-server/pid ]; then
      PID=$(cat ~/.local/share/code-server/pid)
      if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping code-server (PID: $PID)..."
        kill "$PID" || true
        sleep 2
        kill -9 "$PID" 2>/dev/null || true
      fi
      rm -f ~/.local/share/code-server/pid
    fi
    
    # Cleanup any remaining processes
    pkill -f "code-server" || true
    pkill -f "python3 -m http.server" || true
    
    echo "✅ Dummy workspace stopped"
  EOT
  
  # Connection options
  display_apps {
    vscode          = true
    vscode_insiders = true
    web_terminal    = true
    ssh_helper      = true
    port_forwarding_helper = true
  }
}

# VS Code Desktop App
resource "coder_app" "vscode_desktop" {
  agent_id     = coder_agent.main.id
  slug         = "vscode-desktop"
  display_name = "VS Code Desktop"
  icon         = "/icon/code.svg"
  command      = "code --folder-uri vscode-remote://coder+${data.coder_workspace.me.name}${local.workspace_dir}"
}

# VS Code Web (code-server)
resource "coder_app" "code_server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code Web"
  url          = "http://localhost:13337?folder=${local.workspace_dir}"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"
  
  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 10
    threshold = 3
  }
}

# VS Code Insiders Desktop App  
resource "coder_app" "vscode_insiders" {
  agent_id     = coder_agent.main.id
  slug         = "vscode-insiders"
  display_name = "VS Code Insiders"
  icon         = "/icon/code.svg"
  command      = "code-insiders --folder-uri vscode-remote://coder+${data.coder_workspace.me.name}${local.workspace_dir}"
}

# Web terminal
resource "coder_app" "terminal" {
  agent_id     = coder_agent.main.id
  slug         = "terminal"
  display_name = "Terminal"
  icon         = "/icon/terminal.svg"
  command      = "cd ${local.workspace_dir} && bash"
}

# SSH connection info
resource "coder_app" "ssh" {
  agent_id     = coder_agent.main.id
  slug         = "ssh"
  display_name = "SSH"
  icon         = "/icon/terminal.svg"
  command      = "ssh coder.${data.coder_workspace.me.name}"
}

# Status page showing dummy info
resource "coder_app" "status" {
  agent_id     = coder_agent.main.id
  slug         = "status"
  display_name = "Workspace Status"
  icon         = "/icon/info.svg"
  url          = "http://localhost:8080"
  subdomain    = false
  share        = "owner"
}

# Devcontainer info app
resource "coder_app" "devcontainer_info" {
  agent_id     = coder_agent.main.id
  slug         = "devcontainer"
  display_name = "Devcontainer Info"
  icon         = "/icon/docker.svg"
  command      = "cat ${local.workspace_dir}/.devcontainer/devcontainer.json"
}

# VS Code workspace file app
resource "coder_app" "vscode_workspace" {
  agent_id     = coder_agent.main.id
  slug         = "workspace-file"
  display_name = "Open VS Code Workspace"
  icon         = "/icon/code.svg"
  command      = "code ${local.workspace_dir}/workspace.code-workspace"
}

# Metadata for the Coder UI
resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = null_resource.workspace[0].id
  
  item {
    key   = "Type"
    value = "Dummy Workspace with Devcontainer"
  }
  
  item {
    key   = "CPU"
    value = "${data.coder_parameter.cpu.value} cores (simulated)"
  }
  
  item {
    key   = "Memory"
    value = "${data.coder_parameter.memory.value} GB (simulated)"
  }
  
  item {
    key   = "Disk"
    value = "${data.coder_parameter.disk_size.value} GB (simulated)"
  }
  
  item {
    key   = "Container ID"
    value = local.fake_resource_status.container_id
  }
  
  item {
    key   = "IP Address"
    value = local.fake_resource_status.ip_address
  }
  
  item {
    key   = "Status"
    value = local.fake_resource_status.status
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