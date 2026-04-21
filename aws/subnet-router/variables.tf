variable "ami_ssm_parameter_name" {
  description = "SSM public parameter that resolves to the latest Amazon Linux 2023 arm64 AMI."
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

variable "aws_region" {
  description = "AWS region in which the subnet router is created."
  type        = string
  default     = "us-west-2"
}

variable "dns_mirror_hosted_zone_id" {
  description = "Route 53 hosted zone ID mirrored by dns-mirror."
  type        = string
  default     = "Z009084217D5KKVQERJY3"
}

variable "dns_mirror_image" {
  description = "Pinned GHCR image reference for the dns-mirror service."
  type        = string
}

variable "dns_mirror_listen_addr" {
  description = "HTTP listen address for the dns-mirror service."
  type        = string
  default     = ":8080"
}

variable "dns_mirror_output_path" {
  description = "On-host path where dns-mirror writes the rendered zonefile."
  type        = string
  default     = "/var/lib/dns-mirror/glab.lol.zone"
}

variable "dns_mirror_runtime_dir" {
  description = "Host path that stores the dns-mirror compose file."
  type        = string
  default     = "/opt/dns-mirror"
}

variable "dns_mirror_state_dir" {
  description = "Host path mounted into the dns-mirror container for persistent snapshots."
  type        = string
  default     = "/var/lib/dns-mirror"
}

variable "dns_mirror_sync_interval" {
  description = "Sync interval passed to the dns-mirror service."
  type        = string
  default     = "1m"
}

variable "instance_name" {
  description = "Name tag for the AWS subnet router instance."
  type        = string
  default     = "glab-aws-subnet-router"
}

variable "instance_type" {
  description = "EC2 instance type for the AWS subnet router."
  type        = string
  default     = "t4g.nano"
}

variable "iam_role_name" {
  description = "IAM role name used by the AWS subnet router instance."
  type        = string
  default     = "glab-aws-subnet-router"
}

variable "lab_cidrs" {
  description = "CIDR blocks on the lab side that should be routed to the AWS subnet router and allowed through its security group."
  type        = set(string)
  default     = ["10.10.0.0/16"]

  validation {
    condition     = alltrue([for cidr in var.lab_cidrs : can(cidrnetmask(cidr))])
    error_message = "Every entry in lab_cidrs must be a valid IPv4 CIDR block."
  }
}

variable "public_route_table_name" {
  description = "Name tag used to discover the lab foundation public route table."
  type        = string
  default     = "glab-lab-public"
}

variable "public_subnet_name" {
  description = "Name tag used to discover the lab foundation public subnet."
  type        = string
  default     = "glab-lab-public"
}

variable "security_group_name" {
  description = "Name for the security group attached to the AWS subnet router."
  type        = string
  default     = "glab-aws-subnet-router"
}

variable "tailscale_advertise_routes" {
  description = "CIDR blocks the AWS subnet router advertises to the tailnet."
  type        = set(string)
  default     = ["172.16.0.0/16"]

  validation {
    condition     = alltrue([for cidr in var.tailscale_advertise_routes : can(cidrnetmask(cidr))])
    error_message = "Every entry in tailscale_advertise_routes must be a valid IPv4 CIDR block."
  }
}

variable "tailscale_audience" {
  description = "Audience configured on the Tailscale federated identity for the AWS subnet router."
  type        = string
}

variable "tailscale_client_id" {
  description = "Client ID configured on the Tailscale federated identity for the AWS subnet router."
  type        = string
}

variable "tailscale_tag" {
  description = "Tailnet tag the AWS subnet router advertises when it joins through workload identity federation."
  type        = string
  default     = "tag:subnet-router"

  validation {
    condition     = startswith(var.tailscale_tag, "tag:")
    error_message = "tailscale_tag must start with 'tag:'."
  }
}

variable "vpc_name" {
  description = "Name tag used to discover the lab foundation VPC."
  type        = string
  default     = "glab-lab-vpc"
}
