variable "aws_region" {
  description = "AWS region in which the Flatcar Keycloak spike instance is created."
  type        = string
  default     = "us-west-2"
}

variable "bootstrap_field" {
  description = "RFC 6901 field path extracted from the SOPS file by labctl."
  type        = string
  default     = "/stack_env"

  validation {
    condition     = startswith(var.bootstrap_field, "/")
    error_message = "bootstrap_field must be an RFC 6901 pointer beginning with '/'."
  }
}

variable "bootstrap_output_path" {
  description = "Path where labctl writes the decrypted dotenv payload on the Flatcar host."
  type        = string
  default     = "/run/glab/keycloak/stack.env"

  validation {
    condition     = startswith(var.bootstrap_output_path, "/run/")
    error_message = "bootstrap_output_path must stay under /run for this spike."
  }
}

variable "bootstrap_runtime_dir" {
  description = "Ephemeral host directory mounted into the labctl container."
  type        = string
  default     = "/run/glab/keycloak"

  validation {
    condition     = startswith(var.bootstrap_runtime_dir, "/run/") && !endswith(var.bootstrap_runtime_dir, "/")
    error_message = "bootstrap_runtime_dir must stay under /run and must not end with '/'."
  }
}

variable "bootstrap_secret_path" {
  description = "Path to the SOPS-encrypted Keycloak bootstrap secret in GilmanLab/secrets."
  type        = string
  default     = "services/keycloak/bootstrap.sops.yaml"

  validation {
    condition     = can(regex("^services/keycloak/[^[:space:]]+\\.sops\\.yaml$", var.bootstrap_secret_path))
    error_message = "bootstrap_secret_path must point at a services/keycloak/*.sops.yaml file."
  }
}

variable "flatcar_ami_id" {
  description = "Flatcar stable arm64 AMI ID for us-west-2. Recheck the official Flatcar AWS EC2 table before live apply."
  type        = string
  default     = "ami-0ce605082061bbb10"

  validation {
    condition     = can(regex("^ami-[0-9a-f]{17}$", var.flatcar_ami_id))
    error_message = "flatcar_ami_id must be a literal EC2 AMI ID."
  }
}

variable "github_token_broker_function_name" {
  description = "Name of the GitHub token broker Lambda used to mint short-lived GitHub Contents credentials."
  type        = string
  default     = "glab-github-token-broker"

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,64}$", var.github_token_broker_function_name))
    error_message = "github_token_broker_function_name must be 1-64 characters and contain only letters, numbers, hyphens, and underscores."
  }
}

variable "iam_role_name" {
  description = "IAM role and instance profile name used by the spike instance."
  type        = string
  default     = "glab-aws-keycloak-flatcar-spike"
}

variable "instance_name" {
  description = "Name tag for the temporary Flatcar Keycloak spike instance."
  type        = string
  default     = "glab-aws-keycloak-flatcar-spike"
}

variable "instance_type" {
  description = "EC2 instance type for the Flatcar spike host."
  type        = string
  default     = "t4g.small"
}

variable "labctl_image" {
  description = "Pinned labctl container image used for the bootstrap secret fetch."
  type        = string
  default     = "ghcr.io/gilmanlab/platform/labctl@sha256:4638b36a168df88d4206d5ff23aed62a6d8459ba7a2481c0b7c65c696445c1ec"

  validation {
    condition     = startswith(var.labctl_image, "ghcr.io/gilmanlab/platform/labctl@sha256:")
    error_message = "labctl_image must be pinned by digest."
  }
}

variable "public_subnet_name" {
  description = "Name tag used to discover the lab foundation public subnet."
  type        = string
  default     = "glab-lab-public"
}

variable "root_volume_size" {
  description = "Size, in GiB, of the encrypted gp3 root volume attached to the spike instance."
  type        = number
  default     = 16

  validation {
    condition     = var.root_volume_size >= 13 && var.root_volume_size <= 100
    error_message = "root_volume_size must be between 13 and 100 GiB for the current Flatcar AMI snapshot."
  }
}

variable "security_group_name" {
  description = "Name for the outbound-only security group attached to the spike instance."
  type        = string
  default     = "glab-aws-keycloak-flatcar-spike"
}

variable "sops_kms_context_repo" {
  description = "KMS encryption context Repo value allowed for Keycloak SOPS decrypts."
  type        = string
  default     = "GilmanLab/secrets"
}

variable "sops_kms_context_scope" {
  description = "KMS encryption context Scope value allowed for Keycloak SOPS decrypts."
  type        = string
  default     = "keycloak"
}

variable "sops_kms_key_arn" {
  description = "Customer-managed KMS key used by the secrets repository SOPS rules."
  type        = string
  default     = "arn:aws:kms:us-west-2:186067932323:key/2aba1d94-6eaf-4d80-8d26-2077f32fd7c5"

  validation {
    condition     = can(regex("^arn:aws[a-zA-Z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/[A-Za-z0-9-]+$", var.sops_kms_key_arn))
    error_message = "sops_kms_key_arn must be a literal KMS key ARN."
  }
}

variable "tags" {
  description = "Extra tags to merge onto all created resources."
  type        = map(string)
  default     = {}
}

variable "vpc_name" {
  description = "Name tag used to discover the lab foundation VPC."
  type        = string
  default     = "glab-lab-vpc"
}
