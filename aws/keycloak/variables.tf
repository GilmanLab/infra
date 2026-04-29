variable "ami_ssm_parameter_name" {
  description = "SSM public parameter that resolves to the latest Amazon Linux 2023 arm64 AMI."
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

variable "aws_region" {
  description = "AWS region in which the Keycloak instance is created."
  type        = string
  default     = "us-west-2"
}

variable "acme_ca_server" {
  description = "ACME directory URL used by Traefik for Let's Encrypt certificate issuance."
  type        = string
  default     = "https://acme-v02.api.letsencrypt.org/directory"

  validation {
    condition     = startswith(var.acme_ca_server, "https://")
    error_message = "acme_ca_server must be an HTTPS URL."
  }
}

variable "acme_email" {
  description = "Email address used by Traefik when registering the Let's Encrypt ACME account."
  type        = string
  default     = "admin@glab.lol"

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+$", var.acme_email))
    error_message = "acme_email must be an email address."
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

variable "compose_version" {
  description = "Docker Compose CLI plugin version installed on the Keycloak host."
  type        = string
  default     = "v2.38.2"

  validation {
    condition     = startswith(var.compose_version, "v")
    error_message = "compose_version must include the leading 'v' used by Docker Compose release tags."
  }
}

variable "database_name" {
  description = "Postgres database name used by Keycloak."
  type        = string
  default     = "keycloak"

  validation {
    condition     = can(regex("^[a-zA-Z_][a-zA-Z0-9_]*$", var.database_name))
    error_message = "database_name must be a valid Postgres identifier."
  }
}

variable "database_username" {
  description = "Postgres user name used by Keycloak."
  type        = string
  default     = "keycloak"

  validation {
    condition     = can(regex("^[a-zA-Z_][a-zA-Z0-9_]*$", var.database_username))
    error_message = "database_username must be a valid Postgres identifier."
  }
}

variable "dns_record_ttl" {
  description = "TTL, in seconds, for the private Route 53 record pointing at the Keycloak instance."
  type        = number
  default     = 60

  validation {
    condition     = var.dns_record_ttl >= 30 && var.dns_record_ttl <= 3600
    error_message = "dns_record_ttl must be between 30 and 3600 seconds."
  }
}

variable "iam_role_name" {
  description = "IAM role name used by the Keycloak instance."
  type        = string
  default     = "glab-aws-keycloak"
}

variable "instance_name" {
  description = "Name tag for the Keycloak EC2 instance."
  type        = string
  default     = "glab-aws-keycloak"
}

variable "instance_type" {
  description = "EC2 instance type for the Keycloak host."
  type        = string
  default     = "t4g.small"
}

variable "github_token_broker_function_name" {
  description = "Name of the GitHub token broker Lambda deployed with the Keycloak stack."
  type        = string
  default     = "glab-github-token-broker"

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,64}$", var.github_token_broker_function_name))
    error_message = "github_token_broker_function_name must be 1-64 characters and contain only letters, numbers, hyphens, and underscores."
  }
}

variable "github_token_broker_log_retention_days" {
  description = "CloudWatch log retention, in days, for the GitHub token broker Lambda log group."
  type        = number
  default     = 30

  validation {
    condition = contains(
      [1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2192, 2557, 2922, 3288, 3653, 0],
      var.github_token_broker_log_retention_days,
    )
    error_message = "github_token_broker_log_retention_days must be one of the values accepted by CloudWatch Logs, or 0 for never expire."
  }
}

variable "github_token_broker_permissions" {
  description = "GitHub App installation token permissions requested by the broker."
  type        = map(string)
  default     = { contents = "read" }

  validation {
    condition = alltrue([
      for k, v in var.github_token_broker_permissions : length(trimspace(k)) > 0 && length(trimspace(v)) > 0
    ])
    error_message = "github_token_broker_permissions entries must have non-empty keys and values."
  }
}

variable "github_token_broker_private_key_kms_key_arn" {
  description = "Optional customer-managed KMS key or alias ARN used by SSM to encrypt the GitHub App private key parameter."
  type        = string
  default     = null

  validation {
    condition = (
      var.github_token_broker_private_key_kms_key_arn == null ||
      can(regex("^arn:aws[a-zA-Z-]*:kms:[a-z0-9-]+:[0-9]{12}:(key/[A-Za-z0-9-]+|alias/[A-Za-z0-9/_-]+)$", var.github_token_broker_private_key_kms_key_arn))
    )
    error_message = "github_token_broker_private_key_kms_key_arn must be a literal KMS key or alias ARN without wildcard characters."
  }
}

variable "github_token_broker_release_repository" {
  description = "OWNER/REPO GitHub repository that publishes the GitHub token broker release asset."
  type        = string
  default     = "meigma/github-token-broker"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_token_broker_release_repository))
    error_message = "github_token_broker_release_repository must be a literal OWNER/REPO value."
  }
}

variable "github_token_broker_release_version" {
  description = "Release tag of meigma/github-token-broker to deploy."
  type        = string
  default     = "v1.1.0"

  validation {
    condition     = can(regex("^v?[0-9]+\\.[0-9]+\\.[0-9]+(-[A-Za-z0-9.-]+)?$", var.github_token_broker_release_version))
    error_message = "github_token_broker_release_version must be a semver tag such as v1.1.0."
  }
}

variable "github_token_broker_ssm_parameter_paths" {
  description = "SSM parameter paths holding the GitHub App credentials used by the broker."
  type = object({
    client_id       = string
    installation_id = string
    private_key     = string
  })
  default = {
    client_id       = "/glab/bootstrap/github-app/client-id"
    installation_id = "/glab/bootstrap/github-app/installation-id"
    private_key     = "/glab/bootstrap/github-app/private-key-pem"
  }

  validation {
    condition = alltrue([
      can(regex("^/[A-Za-z0-9_.\\-/]+$", var.github_token_broker_ssm_parameter_paths.client_id)),
      can(regex("^/[A-Za-z0-9_.\\-/]+$", var.github_token_broker_ssm_parameter_paths.installation_id)),
      can(regex("^/[A-Za-z0-9_.\\-/]+$", var.github_token_broker_ssm_parameter_paths.private_key)),
    ])
    error_message = "github_token_broker_ssm_parameter_paths entries must be absolute literal SSM paths."
  }
}

variable "keycloak_admin_username" {
  description = "Temporary bootstrap admin username passed to Keycloak on first startup."
  type        = string
  default     = "admin"

  validation {
    condition     = length(trimspace(var.keycloak_admin_username)) > 0
    error_message = "keycloak_admin_username must not be empty."
  }
}

variable "keycloak_heap_max" {
  description = "Maximum JVM heap assigned to Keycloak."
  type        = string
  default     = "768m"

  validation {
    condition     = can(regex("^[0-9]+[mMgG]$", var.keycloak_heap_max))
    error_message = "keycloak_heap_max must use a JVM memory suffix such as 768m or 1g."
  }
}

variable "keycloak_heap_min" {
  description = "Initial JVM heap assigned to Keycloak."
  type        = string
  default     = "256m"

  validation {
    condition     = can(regex("^[0-9]+[mMgG]$", var.keycloak_heap_min))
    error_message = "keycloak_heap_min must use a JVM memory suffix such as 256m or 1g."
  }
}

variable "keycloak_image" {
  description = "Pinned Keycloak container image."
  type        = string
  default     = "quay.io/keycloak/keycloak:26.6.1"
}

variable "lab_cidrs" {
  description = "CIDR blocks on the lab side that may reach Keycloak over HTTPS."
  type        = set(string)
  default     = ["10.10.0.0/16"]

  validation {
    condition     = alltrue([for cidr in var.lab_cidrs : can(cidrnetmask(cidr))])
    error_message = "Every entry in lab_cidrs must be a valid IPv4 CIDR block."
  }
}

variable "operator_tailscale_cidrs" {
  description = "Named operator Tailscale IPv4 CIDRs that may reach Keycloak directly over HTTPS."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for cidr in values(var.operator_tailscale_cidrs) : can(cidrnetmask(cidr))])
    error_message = "Every entry in operator_tailscale_cidrs must be a valid IPv4 CIDR block."
  }
}

variable "postgres_image" {
  description = "Pinned Postgres container image."
  type        = string
  default     = "postgres:18.3-trixie"
}

variable "postgres_state_dir" {
  description = "Host path mounted into the Postgres container for durable database state."
  type        = string
  default     = "/var/lib/keycloak/postgres"

  validation {
    condition     = startswith(var.postgres_state_dir, "/")
    error_message = "postgres_state_dir must be an absolute path."
  }
}

variable "private_hostname" {
  description = "Private DNS hostname for the Keycloak service."
  type        = string
  default     = "id.glab.lol"

  validation {
    condition     = length(trimspace(var.private_hostname)) > 0
    error_message = "private_hostname must not be empty."
  }
}

variable "private_zone_name" {
  description = "Private Route 53 zone that holds the Keycloak service record."
  type        = string
  default     = "glab.lol"

  validation {
    condition     = length(trimspace(var.private_zone_name)) > 0
    error_message = "private_zone_name must not be empty."
  }
}

variable "public_subnet_name" {
  description = "Name tag used to discover the lab foundation public subnet."
  type        = string
  default     = "glab-lab-public"
}

variable "public_route_table_name" {
  description = "Name tag used to discover the lab foundation public route table."
  type        = string
  default     = "glab-lab-public"
}

variable "root_volume_size" {
  description = "Size, in GiB, of the encrypted gp3 root volume attached to the Keycloak instance."
  type        = number
  default     = 16

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 100
    error_message = "root_volume_size must be between 8 and 100 GiB."
  }
}

variable "runtime_dir" {
  description = "Host path that stores the Keycloak Compose stack and generated TLS material."
  type        = string
  default     = "/opt/keycloak"

  validation {
    condition     = startswith(var.runtime_dir, "/")
    error_message = "runtime_dir must be an absolute path."
  }
}

variable "security_group_name" {
  description = "Name for the security group attached to the Keycloak instance."
  type        = string
  default     = "glab-aws-keycloak"
}

variable "ssm_parameter_prefix" {
  description = "SSM Parameter Store path prefix where the host stores generated bootstrap credentials."
  type        = string
  default     = "/glab/keycloak"

  validation {
    condition     = startswith(var.ssm_parameter_prefix, "/") && !endswith(var.ssm_parameter_prefix, "/")
    error_message = "ssm_parameter_prefix must start with '/' and must not end with '/'."
  }
}

variable "subnet_router_instance_name" {
  description = "Name tag used to discover the AWS subnet router instance for operator Tailscale return routes."
  type        = string
  default     = "glab-aws-subnet-router"
}

variable "tags" {
  description = "Extra tags to merge onto all created resources."
  type        = map(string)
  default     = {}
}

variable "traefik_image" {
  description = "Pinned Traefik container image."
  type        = string
  default     = "traefik:v3.6.13"
}

variable "traefik_dns_challenge_resolvers" {
  description = "Comma-separated public recursive resolvers Traefik uses while checking DNS-01 propagation."
  type        = string
  default     = "1.1.1.1:53,8.8.8.8:53"
}

variable "vpc_name" {
  description = "Name tag used to discover the lab foundation VPC."
  type        = string
  default     = "glab-lab-vpc"
}
