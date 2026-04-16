terraform {
  required_version = ">= 1.10"

  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.28"
    }
  }
}

provider "tailscale" {
  tailnet             = var.tailscale_tailnet
  oauth_client_id     = var.tailscale_oauth_client_id
  oauth_client_secret = var.tailscale_oauth_client_secret
}
