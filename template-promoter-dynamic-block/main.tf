terraform {
  required_providers {
    coderd = {
      source = "coder/coderd"
    }
  }
}

provider "coderd" {
  url   = "http://localhost:3000"
  token = "zaJjUFyChE-iVsuTpP6ed1CAUvdZwwi8X"
}

variable "COMMIT_SHA" {
  type        = string
  default     = ""
  description = "The commit SHA to use for the template version description. Optional."
}

variable "ACTIVE_VERSION" {
  type        = string
  default     = ""
  description = "The name of the template version to make active. If not specified, the first one will be active."
}

locals {
  # Discover all template directories by looking for main.tf files
  template_files = fileset("${path.module}/../templates", "*/main.tf")
  # Extract directory names from the file paths and sort them
  template_directories = sort(toset([for f in local.template_files : dirname(f)]))
  
  # Determine which version should be active
  active_version = var.ACTIVE_VERSION != "" ? var.ACTIVE_VERSION : local.template_directories[0]
}

# Output information about discovered templates
output "discovered_templates" {
  value = local.template_directories
  description = "List of discovered template directories"
}

output "active_version" {
  value = local.active_version
  description = "The currently active template version"
}

# Create template using dynamic blocks (this will show the provider limitation)
resource "coderd_template" "dynamic_block_template" {
  name        = "dynamic-block-template"
  description = "Template attempting to use dynamic blocks for versions"
  
  dynamic "versions" {
    for_each = local.template_directories
    content {
      name        = versions.value
      description = var.COMMIT_SHA != "" ? "${versions.value} - Deployed from commit: ${var.COMMIT_SHA}" : "${versions.value} - Active version"
      directory   = "../templates/${versions.value}"
      active      = versions.value == local.active_version  # Only one can be active
    }
  }
}
