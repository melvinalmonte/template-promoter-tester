terraform {
  required_providers {
    coderd = {
      source  = "coder/coderd"
      version = ">= 0.0.11"
    }
  }
}

provider "coderd" {
  url   = "http://localhost:3000"
  token = ""
}
