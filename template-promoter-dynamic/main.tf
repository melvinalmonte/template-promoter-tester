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
  # Extract directory names from the file paths and sort them for consistent ordering
  template_directories = sort(toset([for f in local.template_files : dirname(f)]))
  
  # Determine which version should be active
  active_version = var.ACTIVE_VERSION != "" ? var.ACTIVE_VERSION : local.template_directories[0]
  
  # Create a list of version configurations
  template_versions = [for dir in local.template_directories : {
    name        = dir  # Use directory name as version name
    description = var.COMMIT_SHA != "" ? "${dir} - Deployed from commit: ${var.COMMIT_SHA}" : "${dir} - Active version"
    directory   = "../templates/${dir}"
    active      = dir == local.active_version  # Only one version can be active
  }]
}

# Output information about the versions
output "available_versions" {
  value = local.template_directories
  description = "List of available template versions"
}

output "active_version" {
  value = local.active_version
  description = "The currently active template version"
}

# Create a single template resource with multiple versions
resource "coderd_template" "multi_version_template" {
  name        = "multi-template"
  description = "Multi-version template containing all templates"
  
  # Directly assign the list of versions
  versions = local.template_versions
}
