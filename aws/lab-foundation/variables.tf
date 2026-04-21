variable "aws_region" {
  description = "AWS region in which the lab foundation resources are created."
  type        = string
  default     = "us-west-2"
}

variable "availability_zone" {
  description = "Single AZ for the public subnet. Leave empty to use the first available AZ in the configured region."
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC."
  type        = string
  default     = "172.16.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for the single public subnet in the lab VPC."
  type        = string
  default     = "172.16.0.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "public_subnet_cidr must be a valid IPv4 CIDR block."
  }
}

variable "private_zone_name" {
  description = "Private Route 53 zone that acts as the lab DNS source of record."
  type        = string
  default     = "glab.lol"

  validation {
    condition     = length(trimspace(var.private_zone_name)) > 0
    error_message = "private_zone_name must not be empty."
  }
}

variable "acme_zone_name" {
  description = "Public Route 53 zone delegated from Cloudflare for ACME DNS-01 validation records."
  type        = string
  default     = "acme.glab.lol"

  validation {
    condition     = length(trimspace(var.acme_zone_name)) > 0
    error_message = "acme_zone_name must not be empty."
  }
}

variable "kms_alias" {
  description = "Alias for the customer-managed KMS key used as a SOPS recipient, without the 'alias/' prefix."
  type        = string
  default     = "glab-sops"

  validation {
    condition     = !startswith(var.kms_alias, "alias/")
    error_message = "kms_alias must not include the 'alias/' prefix."
  }
}

variable "kms_deletion_window_in_days" {
  description = "Pending deletion window, in days, when the KMS key is scheduled for deletion."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_in_days >= 7 && var.kms_deletion_window_in_days <= 30
    error_message = "kms_deletion_window_in_days must be between 7 and 30."
  }
}

variable "tags" {
  description = "Extra tags to merge onto all created resources."
  type        = map(string)
  default     = {}
}
