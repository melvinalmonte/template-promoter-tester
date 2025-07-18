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

locals {
  # Discover all template directories by looking for main.tf files
  template_files = fileset("${path.module}/../templates", "*/main.tf")
  # Extract directory names from the file paths
  template_directories = toset([for f in local.template_files : dirname(f)])
  
  # Read metadata from JSON files, with fallback values
  template_metadata = {
    for dir in local.template_directories : dir => try(
      jsondecode(file("${path.module}/../templates/${dir}/template.json")),
      {
        display_name = dir
        description  = "Template: ${dir}"
        icon        = "/emojis/1f4e6.png"  # Default package emoji
        tags        = []
        category    = "general"
      }
    )
  }
}

# Create a template resource for each directory found in templates/
resource "coderd_template" "templates" {
  for_each = local.template_metadata
  
  name         = each.key  # Directory name for internal reference
  display_name = each.value.display_name  # Friendly name from metadata
  description  = each.value.description   # Detailed description from metadata
  icon         = each.value.icon          # Icon from metadata
  
  versions = [
    {
      name        = "active"  # Use a stable version name
      description = var.COMMIT_SHA != "" ? "Deployed from commit: ${var.COMMIT_SHA}" : "Active version"
      directory   = "../templates/${each.key}"
      active      = true
    }
  ]
}

# Output template information
output "deployed_templates" {
  value = {
    for name, template in coderd_template.templates : name => {
      display_name = template.display_name
      description  = template.description
      icon        = template.icon
    }
  }
  description = "List of deployed templates with their metadata"
}