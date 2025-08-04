terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.12.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

# The Coder provider is automatically configured by Coder
provider "coder" {}

# Docker provider for container management
provider "docker" {}

# Null provider for dummy resources
provider "null" {}

# Local provider for file operations
provider "local" {} 