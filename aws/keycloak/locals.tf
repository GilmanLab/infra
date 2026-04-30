locals {
  common_tags = merge(var.tags, {
    "glab:project" = "glab"
    "glab:domain"  = "aws"
    "glab:purpose" = "keycloak"
  })

  private_hostname_relative     = trimsuffix(var.private_hostname, ".${var.private_zone_name}")
  acme_challenge_record_name    = "_acme-challenge.${local.private_hostname_relative}.${var.acme_zone_name}"
  traefik_certificate_resolver  = "letsencrypt"
  traefik_acme_storage_file     = "/etc/traefik/acme/acme.json"
  traefik_acme_storage_host_dir = "${var.data_dir}/acme"
  postgres_state_dir            = "${var.data_dir}/postgres"
  keycloak_env_path             = "${var.bootstrap_runtime_dir}/keycloak.env"
  helper_script_dir             = "${var.runtime_dir}/bin"
  keycloak_config_dir           = "${var.data_dir}/config"
  keycloak_config_marker_path   = "${local.keycloak_config_dir}/lab-realm-imported"
  keycloak_realm_config_path    = "${var.bootstrap_runtime_dir}/lab-realm.json"
  data_volume_device_path       = "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${replace(aws_ebs_volume.keycloak_data.id, "-", "")}"

  traefik_dynamic_config = templatefile("${path.module}/templates/traefik_dynamic.yml.tftpl", {
    private_hostname             = var.private_hostname
    traefik_certificate_resolver = local.traefik_certificate_resolver
  })

  lab_realm_config = templatefile("${path.module}/templates/keycloak/lab-realm.json.tftpl", {
    private_hostname = var.private_hostname
  })

  bootstrap_unit_name               = "glab-keycloak-bootstrap.service"
  config_unit_name                  = "glab-keycloak-config.service"
  data_unit_name                    = "glab-keycloak-data.service"
  disable_bootstrap_admin_unit_name = "glab-keycloak-disable-bootstrap-admin.service"
  network_unit_name                 = "glab-keycloak-network.service"
  postgres_unit_name                = "glab-keycloak-postgres.service"
  keycloak_unit_name                = "glab-keycloak.service"
  traefik_unit_name                 = "glab-keycloak-traefik.service"

  runtime_template_vars = {
    acme_ca_server                    = var.acme_ca_server
    acme_email                        = var.acme_email
    aws_region                        = var.aws_region
    bootstrap_field                   = var.bootstrap_field
    bootstrap_output_path             = var.bootstrap_output_path
    bootstrap_runtime_dir             = var.bootstrap_runtime_dir
    bootstrap_secret_path             = var.bootstrap_secret_path
    bootstrap_unit_name               = local.bootstrap_unit_name
    config_field                      = var.config_field
    config_output_path                = var.config_output_path
    config_secret_path                = var.config_secret_path
    config_unit_name                  = local.config_unit_name
    data_dir                          = var.data_dir
    data_unit_name                    = local.data_unit_name
    data_volume_device_path           = local.data_volume_device_path
    data_volume_label                 = var.data_volume_label
    disable_bootstrap_admin_unit_name = local.disable_bootstrap_admin_unit_name
    github_token_broker_function_name = var.github_token_broker_function_name
    helper_script_dir                 = local.helper_script_dir
    keycloak_config_cli_image         = var.keycloak_config_cli_image
    keycloak_config_dir               = local.keycloak_config_dir
    keycloak_config_marker_path       = local.keycloak_config_marker_path
    keycloak_env_path                 = local.keycloak_env_path
    keycloak_image                    = var.keycloak_image
    keycloak_realm_config_path        = local.keycloak_realm_config_path
    lab_realm_config_gzip_base64      = base64gzip(local.lab_realm_config)
    keycloak_unit_name                = local.keycloak_unit_name
    labctl_image                      = var.labctl_image
    network_unit_name                 = local.network_unit_name
    postgres_image                    = var.postgres_image
    postgres_state_dir                = local.postgres_state_dir
    postgres_unit_name                = local.postgres_unit_name
    runtime_dir                       = var.runtime_dir
    traefik_acme_storage_file         = local.traefik_acme_storage_file
    traefik_acme_storage_host_dir     = local.traefik_acme_storage_host_dir
    traefik_certificate_resolver      = local.traefik_certificate_resolver
    traefik_dns_challenge_resolvers   = var.traefik_dns_challenge_resolvers
    traefik_image                     = var.traefik_image
    traefik_unit_name                 = local.traefik_unit_name
    traefik_zone_id                   = data.aws_route53_zone.acme.zone_id
  }

  prepare_data_script   = templatefile("${path.module}/templates/scripts/prepare-data.sh.tftpl", local.runtime_template_vars)
  create_network_script = templatefile("${path.module}/templates/scripts/create-network.sh.tftpl", local.runtime_template_vars)
  run_postgres_script   = templatefile("${path.module}/templates/scripts/run-postgres.sh.tftpl", local.runtime_template_vars)
  wait_postgres_script  = templatefile("${path.module}/templates/scripts/wait-postgres.sh.tftpl", local.runtime_template_vars)
  run_keycloak_script   = templatefile("${path.module}/templates/scripts/run-keycloak.sh.tftpl", local.runtime_template_vars)
  run_traefik_script    = templatefile("${path.module}/templates/scripts/run-traefik.sh.tftpl", local.runtime_template_vars)
  run_config_script     = templatefile("${path.module}/templates/scripts/run-keycloak-config.sh.tftpl", local.runtime_template_vars)
  disable_admin_script  = templatefile("${path.module}/templates/scripts/disable-bootstrap-admin.sh.tftpl", local.runtime_template_vars)

  data_unit      = templatefile("${path.module}/templates/systemd/${local.data_unit_name}.tftpl", local.runtime_template_vars)
  network_unit   = templatefile("${path.module}/templates/systemd/${local.network_unit_name}.tftpl", local.runtime_template_vars)
  bootstrap_unit = templatefile("${path.module}/templates/systemd/${local.bootstrap_unit_name}.tftpl", local.runtime_template_vars)
  postgres_unit  = templatefile("${path.module}/templates/systemd/${local.postgres_unit_name}.tftpl", local.runtime_template_vars)
  keycloak_unit  = templatefile("${path.module}/templates/systemd/${local.keycloak_unit_name}.tftpl", local.runtime_template_vars)
  traefik_unit   = templatefile("${path.module}/templates/systemd/${local.traefik_unit_name}.tftpl", local.runtime_template_vars)
  config_unit    = templatefile("${path.module}/templates/systemd/${local.config_unit_name}.tftpl", local.runtime_template_vars)
  disable_admin_unit = templatefile(
    "${path.module}/templates/systemd/${local.disable_bootstrap_admin_unit_name}.tftpl",
    local.runtime_template_vars,
  )

  ignition_files = [
    {
      path = "${var.runtime_dir}/traefik_dynamic.yml"
      mode = 420
      contents = {
        source = "data:text/plain;charset=utf-8;base64,${base64encode(local.traefik_dynamic_config)}"
      }
    },
    {
      path = "${local.helper_script_dir}/prepare-data.sh"
      mode = 493
      contents = {
        source = "data:text/plain;charset=utf-8;base64,${base64encode(local.prepare_data_script)}"
      }
    },
    {
      path = "${local.helper_script_dir}/create-network.sh"
      mode = 493
      contents = {
        source = "data:text/plain;charset=utf-8;base64,${base64encode(local.create_network_script)}"
      }
    },
    {
      path = "${local.helper_script_dir}/run-postgres.sh"
      mode = 493
      contents = {
        source = "data:text/plain;charset=utf-8;base64,${base64encode(local.run_postgres_script)}"
      }
    },
    {
      path = "${local.helper_script_dir}/wait-postgres.sh"
      mode = 493
      contents = {
        source = "data:text/plain;charset=utf-8;base64,${base64encode(local.wait_postgres_script)}"
      }
    },
    {
      path = "${local.helper_script_dir}/run-keycloak.sh"
      mode = 493
      contents = {
        source = "data:text/plain;charset=utf-8;base64,${base64encode(local.run_keycloak_script)}"
      }
    },
    {
      path = "${local.helper_script_dir}/run-traefik.sh"
      mode = 493
      contents = {
        source = "data:text/plain;charset=utf-8;base64,${base64encode(local.run_traefik_script)}"
      }
    },
    {
      path = "${local.helper_script_dir}/run-keycloak-config.sh"
      mode = 493
      contents = {
        source = "data:text/plain;charset=utf-8;base64,${base64encode(local.run_config_script)}"
      }
    },
    {
      path = "${local.helper_script_dir}/disable-bootstrap-admin.sh"
      mode = 493
      contents = {
        source = "data:text/plain;charset=utf-8;base64,${base64encode(local.disable_admin_script)}"
      }
    },
  ]

  ignition_payload_config = jsonencode({
    ignition = {
      version = "3.3.0"
    }
    storage = {
      directories = [
        {
          path = "/etc/glab"
          mode = 493
        },
        {
          path = var.runtime_dir
          mode = 493
        },
        {
          path = local.helper_script_dir
          mode = 493
        },
      ]
      files = local.ignition_files
    }
    systemd = {
      units = [
        {
          enabled = true
          name    = "amazon-ssm-agent.service"
        },
        {
          contents = local.data_unit
          enabled  = true
          name     = local.data_unit_name
        },
        {
          contents = local.network_unit
          enabled  = true
          name     = local.network_unit_name
        },
        {
          contents = local.bootstrap_unit
          enabled  = true
          name     = local.bootstrap_unit_name
        },
        {
          contents = local.postgres_unit
          enabled  = true
          name     = local.postgres_unit_name
        },
        {
          contents = local.keycloak_unit
          enabled  = true
          name     = local.keycloak_unit_name
        },
        {
          contents = local.config_unit
          enabled  = true
          name     = local.config_unit_name
        },
        {
          contents = local.traefik_unit
          enabled  = true
          name     = local.traefik_unit_name
        },
        {
          contents = local.disable_admin_unit
          name     = local.disable_bootstrap_admin_unit_name
        },
      ]
    }
  })

  ignition_config = jsonencode({
    ignition = {
      version = "3.3.0"
      config = {
        replace = {
          source      = "data:application/vnd.coreos.ignition+json;base64,${base64gzip(local.ignition_payload_config)}"
          compression = "gzip"
        }
      }
    }
  })
}
