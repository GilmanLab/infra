variable "aws_region" {
  description = "AWS region in which the GitHub token broker Lambda is created."
  type        = string
  default     = "us-west-2"
}

variable "client_id_parameter_name" {
  description = "SSM parameter that stores the GitHub App client ID."
  type        = string
  default     = "/glab/bootstrap/github-app/client-id"

  validation {
    condition     = startswith(var.client_id_parameter_name, "/")
    error_message = "client_id_parameter_name must be an absolute SSM parameter path."
  }
}

variable "execution_role_name" {
  description = "IAM role name used by the GitHub token broker Lambda execution role."
  type        = string
  default     = "glab-github-token-broker"
}

variable "function_memory_size" {
  description = "Memory size, in MiB, assigned to the GitHub token broker Lambda."
  type        = number
  default     = 128

  validation {
    condition     = var.function_memory_size >= 128 && var.function_memory_size <= 10240
    error_message = "function_memory_size must be between 128 and 10240."
  }
}

variable "function_name" {
  description = "Name of the GitHub token broker Lambda function."
  type        = string
  default     = "glab-github-token-broker"
}

variable "function_timeout" {
  description = "Timeout, in seconds, for the GitHub token broker Lambda."
  type        = number
  default     = 10

  validation {
    condition     = var.function_timeout >= 1 && var.function_timeout <= 900
    error_message = "function_timeout must be between 1 and 900 seconds."
  }
}

variable "github_oidc_audience" {
  description = "GitHub Actions OIDC audience allowed to assume the publisher role."
  type        = string
  default     = "sts.amazonaws.com"
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN. Leave empty to create the provider in this stack."
  type        = string
  default     = ""
}

variable "github_oidc_provider_url" {
  description = "GitHub Actions OIDC issuer URL."
  type        = string
  default     = "https://token.actions.githubusercontent.com"

  validation {
    condition     = startswith(var.github_oidc_provider_url, "https://")
    error_message = "github_oidc_provider_url must be an HTTPS URL."
  }
}

variable "github_oidc_subject" {
  description = "GitHub Actions OIDC subject pattern allowed to assume the publisher role."
  type        = string
  default     = "repo:GilmanLab/platform:ref:refs/tags/github-token-broker-v*"

  validation {
    condition     = startswith(var.github_oidc_subject, "repo:GilmanLab/platform:")
    error_message = "github_oidc_subject must stay scoped to GilmanLab/platform."
  }
}

variable "installation_id_parameter_name" {
  description = "SSM parameter that stores the GitHub App installation ID."
  type        = string
  default     = "/glab/bootstrap/github-app/installation-id"

  validation {
    condition     = startswith(var.installation_id_parameter_name, "/")
    error_message = "installation_id_parameter_name must be an absolute SSM parameter path."
  }
}

variable "log_level" {
  description = "Runtime log level passed to the GitHub token broker Lambda."
  type        = string
  default     = "info"

  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "log_level must be one of debug, info, warn, or error."
  }
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention, in days, for the GitHub token broker Lambda log group."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_in_days)
    error_message = "log_retention_in_days must be a CloudWatch Logs retention value."
  }
}

variable "private_key_kms_key_arn" {
  description = "Optional customer-managed KMS key ARN for the private-key SSM SecureString. Leave empty while the parameter uses alias/aws/ssm."
  type        = string
  default     = ""
}

variable "private_key_parameter_name" {
  description = "SSM SecureString parameter that stores the GitHub App private key."
  type        = string
  default     = "/glab/bootstrap/github-app/private-key-pem"

  validation {
    condition     = startswith(var.private_key_parameter_name, "/")
    error_message = "private_key_parameter_name must be an absolute SSM parameter path."
  }
}

variable "publisher_role_name" {
  description = "IAM role name assumed by the platform release workflow to publish Lambda code."
  type        = string
  default     = "glab-github-token-broker-publisher"
}

variable "tags" {
  description = "Extra tags to merge onto all created resources."
  type        = map(string)
  default     = {}
}
