terraform {
    required_providers {
      coder = {
        source  = "coder/coder"
        version = "~> 0.12.0"
      }
      kubernetes = {
        source  = "hashicorp/kubernetes"
        version = "~> 2.23"
      }
    }
  }
  
  # The Coder provider is automatically configured by Coder during workspace creation
  # So we don't need to specify authentication here
  
  # Configure Kubernetes provider to use the current context
  provider "kubernetes" {
    # This will use the Kubernetes context from the Coder server
    # In our case, it's the KIND cluster
  }