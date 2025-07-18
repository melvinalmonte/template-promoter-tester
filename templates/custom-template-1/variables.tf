# Coder-specific data sources for parameters
data "coder_parameter" "cpu" {
  name         = "cpu"
  display_name = "CPU Cores"
  description  = "Number of CPU cores for your workspace"
  default      = "2"
  type         = "number"
  mutable      = true  # Can be changed after workspace creation
  validation {
    min = 1
    max = 8
  }
}

data "coder_parameter" "memory" {
  name         = "memory"
  display_name = "Memory (GB)"
  description  = "Amount of memory for your workspace"
  default      = "4"
  type         = "number"
  mutable      = true
  validation {
    min = 1
    max = 16
  }
}

data "coder_parameter" "disk_size" {
  name         = "disk_size"
  display_name = "Disk Size (GB)"
  description  = "Size of the persistent home directory"
  default      = "10"
  type         = "number"
  mutable      = false  # Can't change after creation
  validation {
    min = 1
    max = 100
  }
}

data "coder_parameter" "dotfiles_repo" {
  name         = "dotfiles_repo"
  display_name = "Dotfiles Repository (optional)"
  description  = "Git repository URL for your dotfiles"
  default      = ""
  type         = "string"
  mutable      = true
}

# Get information about the current workspace
data "coder_workspace" "me" {}