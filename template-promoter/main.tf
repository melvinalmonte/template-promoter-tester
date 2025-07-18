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
}

# Create a template resource for each directory found in templates/
resource "coderd_template" "templates" {
  for_each = local.template_directories
  
  name        = each.value  # Uses the directory name as the template name
  description = "Template: ${each.value}"
  
  versions = [
    {
      name        = "active"  # Use a stable version name
      description = var.COMMIT_SHA != "" ? "Deployed from commit: ${var.COMMIT_SHA}" : "Active version"
      directory   = "../templates/${each.value}"
      active      = true
    }
  ]
}