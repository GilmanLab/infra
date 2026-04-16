variable "tailscale_tailnet" {
  description = "Tailscale tailnet name or organization ID."
  type        = string
}

variable "tailscale_oauth_client_id" {
  description = "OAuth client ID with write access to Tailscale DNS settings."
  type        = string
  sensitive   = true
}

variable "tailscale_oauth_client_secret" {
  description = "OAuth client secret with write access to Tailscale DNS settings."
  type        = string
  sensitive   = true
}
