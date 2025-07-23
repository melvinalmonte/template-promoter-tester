# Local values for convenience
locals {
  workspace_name = lower("${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}")
  
  # Simulated resource status
  fake_resource_status = {
    container_id = "dummy-${substr(md5(local.workspace_name), 0, 12)}"
    ip_address   = "10.0.0.${(data.coder_workspace.me.transition == "start" ? "100" : "0")}"
    status       = data.coder_workspace.me.transition == "start" ? "running" : "stopped"
  }
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
    resources    = {
      cpu    = data.coder_parameter.cpu.value
      memory = data.coder_parameter.memory.value
      disk   = data.coder_parameter.disk_size.value
    }
    dotfiles_repo = data.coder_parameter.dotfiles_repo.value
    status        = local.fake_resource_status
  })
}

# Coder agent - this is required for Coder to manage the workspace
resource "coder_agent" "main" {
  arch = "amd64"
  os   = "linux"
  
  # Startup script that simulates workspace initialization
  startup_script = <<-EOT
    #!/bin/bash
    set -e
    
    echo "🚀 Starting dummy workspace..."
    echo "📊 Resources allocated:"
    echo "   - CPU: ${data.coder_parameter.cpu.value} cores"
    echo "   - Memory: ${data.coder_parameter.memory.value} GB"
    echo "   - Disk: ${data.coder_parameter.disk_size.value} GB"
    
    # Simulate dotfiles setup
    if [ -n "${data.coder_parameter.dotfiles_repo.value}" ]; then
      echo "📁 Would clone dotfiles from: ${data.coder_parameter.dotfiles_repo.value}"
      echo "   (This is a dummy workspace - no actual cloning performed)"
    fi
    
    # Create a dummy process to keep the agent alive
    echo "✅ Dummy workspace ready!"
    echo "ℹ️  This is a simulated environment for testing purposes"
    
    # Keep the agent running
    while true; do
      sleep 30
      echo "💓 Dummy workspace heartbeat at $(date)"
    done &
  EOT
  
  # Connection options
  display_apps {
    vscode          = true
    vscode_insiders = false
    web_terminal    = true
    ssh_helper      = false  # SSH not available in dummy mode
  }
}

# Dummy VS Code app (simulated)
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "vscode"
  display_name = "VS Code (Dummy)"
  url          = "http://localhost:13337?folder=/tmp/dummy-workspace"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"
  
  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 30
    threshold = 3
  }
}

# Web terminal (simulated)
resource "coder_app" "terminal" {
  agent_id     = coder_agent.main.id
  slug         = "terminal"
  display_name = "Terminal (Dummy)"
  icon         = "/icon/terminal.svg"
  command      = "echo 'This is a dummy terminal - no real shell available' && cat"
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

# Metadata for the Coder UI
resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = null_resource.workspace[0].id
  
  item {
    key   = "Type"
    value = "Dummy Workspace"
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
}

# Show some helpful info in the logs
resource "null_resource" "startup_message" {
  count = data.coder_workspace.me.start_count
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "=========================================="
      echo "🎭 DUMMY WORKSPACE CREATED"
      echo "=========================================="
      echo "This is a simulated workspace for testing."
      echo "No real resources have been provisioned."
      echo ""
      echo "Workspace Details:"
      echo "- Name: ${local.workspace_name}"
      echo "- Owner: ${data.coder_workspace.me.owner}"
      echo "- ID: ${data.coder_workspace.me.id}"
      echo ""
      echo "Simulated Resources:"
      echo "- CPU: ${data.coder_parameter.cpu.value} cores"
      echo "- Memory: ${data.coder_parameter.memory.value} GB"
      echo "- Disk: ${data.coder_parameter.disk_size.value} GB"
      echo "=========================================="
    EOT
  }
} 