variable "aws_subnet_router_issuer" {
  description = "Account-specific AWS STS OIDC issuer URL used by the lab subnet router workload identity federation trust."
  type        = string
}

variable "aws_subnet_router_subject" {
  description = "Exact AWS principal ARN that the tailnet trust configuration accepts for the AWS subnet router."
  type        = string
}

variable "aws_subnet_router_tag" {
  description = "Tailnet tag granted to the AWS subnet router when it registers through workload identity federation."
  type        = string
  default     = "tag:subnet-router"

  validation {
    condition     = startswith(var.aws_subnet_router_tag, "tag:")
    error_message = "aws_subnet_router_tag must start with 'tag:'."
  }
}

variable "tailscale_tailnet" {
  description = "Tailscale tailnet name or organization ID."
  type        = string
}

variable "tailscale_oauth_client_id" {
  description = "OAuth client ID with write access to the Tailscale DNS and trust-credential APIs."
  type        = string
  sensitive   = true
}

variable "tailscale_oauth_client_secret" {
  description = "OAuth client secret with write access to the Tailscale DNS and trust-credential APIs."
  type        = string
  sensitive   = true
}
