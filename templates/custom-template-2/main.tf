# Local values for convenience
locals {
  namespace = "coder"  # Using the coder namespace we created
  
  # Create a safe name for Kubernetes resources
  workspace_name = lower("${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}")
  
  # Common labels for all resources
  common_labels = {
    "coder.owner"          = data.coder_workspace.me.owner
    "coder.owner_id"       = data.coder_workspace.me.owner_id
    "coder.workspace_id"   = data.coder_workspace.me.id
    "coder.workspace_name" = data.coder_workspace.me.name
  }
}

# Persistent Volume Claim for home directory
resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${local.workspace_name}-home"
    namespace = local.namespace
    labels    = local.common_labels
  }
  
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${data.coder_parameter.disk_size.value}Gi"
      }
    }
  }
  
  # This ensures the PVC is deleted when the workspace is deleted
  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

# The main workspace pod
resource "kubernetes_pod" "workspace" {
  count = data.coder_workspace.me.start_count  # 0 when stopped, 1 when started
  
  metadata {
    name      = "coder-${local.workspace_name}"
    namespace = local.namespace
    labels    = local.common_labels
  }
  
  spec {
    # Security context for the pod
    security_context {
      run_as_user  = 1000
      fs_group     = 1000
      run_as_non_root = true
    }
    
    # Main development container
    container {
      name  = "dev"
      image = "codercom/enterprise-base:ubuntu"  # Coder's base image with common tools
      
      # Keep the container running
      command = ["sh", "-c"]
      args = ["coder agent"]
      
      # Security context for the container
      security_context {
        run_as_user                = 1000
        allow_privilege_escalation = false
        run_as_non_root           = true
      }
      
      # Environment variables
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.main.token
      }
      
      env {
        name  = "HOME"
        value = "/home/coder"
      }
      
      # Resource limits
      resources {
        requests = {
          cpu    = "${data.coder_parameter.cpu.value}"
          memory = "${data.coder_parameter.memory.value}Gi"
        }
        limits = {
          cpu    = "${data.coder_parameter.cpu.value}"
          memory = "${data.coder_parameter.memory.value}Gi"
        }
      }
      
      # Mount the home directory
      volume_mount {
        name       = "home"
        mount_path = "/home/coder"
      }
    }
    
    # Define the volume
    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata[0].name
      }
    }
  }
}

# Coder agent handles the connection between Coder and the workspace
resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"
  
  # Startup script runs when the workspace starts
  startup_script = <<-EOT
    #!/bin/bash
    set -e
    
    # Set up home directory if it's new
    if [ ! -f ~/.bashrc ]; then
      cp /etc/skel/.bashrc ~/
      cp /etc/skel/.profile ~/
    fi
    
    # Clone dotfiles if specified
    if [ -n "${data.coder_parameter.dotfiles_repo.value}" ]; then
      echo "Setting up dotfiles from ${data.coder_parameter.dotfiles_repo.value}..."
      
      # Clone to a temporary directory
      temp_dir=$(mktemp -d)
      git clone "${data.coder_parameter.dotfiles_repo.value}" "$temp_dir/dotfiles"
      
      # Copy dotfiles to home (customize this based on your dotfiles structure)
      if [ -f "$temp_dir/dotfiles/install.sh" ]; then
        cd "$temp_dir/dotfiles" && ./install.sh
      else
        # Simple copy for common dotfiles
        for file in .bashrc .vimrc .gitconfig .tmux.conf; do
          [ -f "$temp_dir/dotfiles/$file" ] && cp "$temp_dir/dotfiles/$file" ~/
        done
      fi
      
      rm -rf "$temp_dir"
    fi
    
    # Install any additional tools you want here
    # For example:
    # sudo apt-get update && sudo apt-get install -y htop tree
    
    echo "Workspace setup complete!"
  EOT
  
  # Optional: specify connection modes
  display_apps {
    vscode          = true
    vscode_insiders = false
    web_terminal    = true
    ssh_helper      = true
  }
}

# VS Code in the browser
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "vscode"
  display_name = "VS Code"
  url          = "http://localhost:13337?folder=/home/coder"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"
  
  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

# Web terminal
resource "coder_app" "terminal" {
  agent_id     = coder_agent.main.id
  slug         = "terminal"
  display_name = "Terminal"
  icon         = "/icon/terminal.svg"
  command      = "bash"
}

# Resource metadata - shows in the Coder UI
resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = kubernetes_pod.workspace[0].id
  
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
    key   = "Image"
    value = "codercom/enterprise-base:ubuntu"
  }
}