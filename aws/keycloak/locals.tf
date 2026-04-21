locals {
  common_tags = merge(var.tags, {
    "glab:project" = "glab"
    "glab:domain"  = "aws"
    "glab:purpose" = "keycloak"
  })

  ssm_parameter_names = {
    keycloak_admin_password = "${var.ssm_parameter_prefix}/keycloak-admin-password"
    postgres_password       = "${var.ssm_parameter_prefix}/postgres-password"
  }

  private_hostname_relative     = trimsuffix(var.private_hostname, ".${var.private_zone_name}")
  acme_challenge_record_name    = "_acme-challenge.${local.private_hostname_relative}.${var.acme_zone_name}"
  traefik_certificate_resolver  = "letsencrypt"
  traefik_acme_storage_file     = "/etc/traefik/acme/acme.json"
  traefik_acme_storage_host_dir = "${var.runtime_dir}/acme"

  bootstrap_script = templatefile("${path.module}/templates/bootstrap.sh.tftpl", {
    acme_storage_host_dir             = local.traefik_acme_storage_host_dir
    aws_region                        = var.aws_region
    compose_version                   = var.compose_version
    database_name                     = var.database_name
    database_username                 = var.database_username
    keycloak_admin_password_parameter = local.ssm_parameter_names.keycloak_admin_password
    keycloak_admin_username           = var.keycloak_admin_username
    keycloak_heap_max                 = var.keycloak_heap_max
    keycloak_heap_min                 = var.keycloak_heap_min
    keycloak_runtime_dir              = var.runtime_dir
    postgres_password_parameter       = local.ssm_parameter_names.postgres_password
    postgres_state_dir                = var.postgres_state_dir
    service_unit                      = local.service_unit
    stack_env                         = local.stack_env
    traefik_dynamic_config            = local.traefik_dynamic_config
    compose                           = local.compose
  })
  compose = templatefile("${path.module}/templates/compose.yml.tftpl", {
    acme_ca_server                  = var.acme_ca_server
    acme_email                      = var.acme_email
    acme_zone_id                    = data.aws_route53_zone.acme.zone_id
    aws_region                      = var.aws_region
    keycloak_image                  = var.keycloak_image
    postgres_image                  = var.postgres_image
    traefik_acme_storage_file       = local.traefik_acme_storage_file
    traefik_certificate_resolver    = local.traefik_certificate_resolver
    traefik_dns_challenge_resolvers = var.traefik_dns_challenge_resolvers
    traefik_image                   = var.traefik_image
  })
  service_unit = templatefile("${path.module}/templates/keycloak.service.tftpl", {
    keycloak_runtime_dir = var.runtime_dir
  })
  stack_env = templatefile("${path.module}/templates/stack.env.tftpl", {
    database_name           = var.database_name
    database_username       = var.database_username
    keycloak_admin_username = var.keycloak_admin_username
    keycloak_heap_max       = var.keycloak_heap_max
    keycloak_heap_min       = var.keycloak_heap_min
    private_hostname        = var.private_hostname
    postgres_state_dir      = var.postgres_state_dir
  })
  traefik_dynamic_config = templatefile("${path.module}/templates/traefik_dynamic.yml.tftpl", {
    private_hostname             = var.private_hostname
    traefik_certificate_resolver = local.traefik_certificate_resolver
  })
  ssm_parameter_path_arn = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_parameter_prefix}/*"
}
