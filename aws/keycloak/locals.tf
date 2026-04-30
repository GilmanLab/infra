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
  data_volume_device_path       = "/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_${replace(aws_ebs_volume.keycloak_data.id, "-", "")}"

  prepare_data_script = <<-SCRIPT
    #!/bin/sh
    set -eu

    dev='${local.data_volume_device_path}'
    i=0
    while [ ! -e "$dev" ] && [ "$i" -lt 90 ]; do
      i=$((i + 1))
      sleep 2
    done

    if [ ! -e "$dev" ]; then
      echo "data volume $dev did not appear" >&2
      exit 1
    fi

    if ! blkid "$dev" >/dev/null 2>&1; then
      mkfs.ext4 -F -L '${var.data_volume_label}' "$dev"
    fi

    mkdir -p '${var.data_dir}'
    if ! findmnt -rn '${var.data_dir}' >/dev/null 2>&1; then
      mount "$dev" '${var.data_dir}'
    fi

    mkdir -p '${local.postgres_state_dir}' '${local.traefik_acme_storage_host_dir}'
    chown 999:999 '${local.postgres_state_dir}'
    chmod 0750 '${var.data_dir}'
    chmod 0700 '${local.postgres_state_dir}'
    chmod 0700 '${local.traefik_acme_storage_host_dir}'
    touch '${local.traefik_acme_storage_host_dir}/acme.json'
    chmod 0600 '${local.traefik_acme_storage_host_dir}/acme.json'
  SCRIPT

  create_network_script = <<-SCRIPT
    #!/bin/sh
    set -eu

    if ! /usr/bin/docker network inspect keycloak >/dev/null 2>&1; then
      /usr/bin/docker network create keycloak >/dev/null
    fi
  SCRIPT

  run_postgres_script = <<-SCRIPT
    #!/bin/sh
    set -eu

    /usr/bin/docker rm -f keycloak-postgres >/dev/null 2>&1 || true
    exec /usr/bin/docker run \
      --name keycloak-postgres \
      --network keycloak \
      --network-alias postgres \
      --env-file '${var.bootstrap_output_path}' \
      --env PGDATA=/var/lib/postgresql/data \
      --volume '${local.postgres_state_dir}:/var/lib/postgresql' \
      --health-cmd 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' \
      --health-interval 10s \
      --health-timeout 5s \
      --health-retries 12 \
      --pull always \
      '${var.postgres_image}'
  SCRIPT

  wait_postgres_script = <<-SCRIPT
    #!/bin/sh
    set -eu

    i=0
    while [ "$i" -lt 90 ]; do
      if /usr/bin/docker exec keycloak-postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" >/dev/null 2>&1; then
        exit 0
      fi
      i=$((i + 1))
      sleep 2
    done

    echo "postgres did not become ready" >&2
    exit 1
  SCRIPT

  run_keycloak_script = <<-SCRIPT
    #!/bin/sh
    set -eu

    . '${var.bootstrap_output_path}'
    umask 077
    {
      printf 'POSTGRES_DB=%s\n' "$POSTGRES_DB"
      printf 'POSTGRES_USER=%s\n' "$POSTGRES_USER"
      printf 'POSTGRES_PASSWORD=%s\n' "$POSTGRES_PASSWORD"
      printf 'KC_BOOTSTRAP_ADMIN_USERNAME=%s\n' "$KC_BOOTSTRAP_ADMIN_USERNAME"
      printf 'KC_BOOTSTRAP_ADMIN_PASSWORD=%s\n' "$KC_BOOTSTRAP_ADMIN_PASSWORD"
      printf 'KC_HEAP_MIN=%s\n' "$KC_HEAP_MIN"
      printf 'KC_HEAP_MAX=%s\n' "$KC_HEAP_MAX"
      printf 'KC_DB=postgres\n'
      printf 'KC_DB_URL=jdbc:postgresql://postgres:5432/%s\n' "$POSTGRES_DB"
      printf 'KC_DB_USERNAME=%s\n' "$POSTGRES_USER"
      printf 'KC_DB_PASSWORD=%s\n' "$POSTGRES_PASSWORD"
      printf 'KC_HEALTH_ENABLED=true\n'
      printf 'KC_HOSTNAME=https://%s\n' "$KC_HOSTNAME"
      printf 'KC_HTTP_ENABLED=true\n'
      printf 'KC_PROXY_HEADERS=xforwarded\n'
      printf 'JAVA_OPTS_KC_HEAP=-Xms%s -Xmx%s\n' "$KC_HEAP_MIN" "$KC_HEAP_MAX"
    } >'${local.keycloak_env_path}'
    chmod 0600 '${local.keycloak_env_path}'

    /usr/bin/docker rm -f keycloak >/dev/null 2>&1 || true
    exec /usr/bin/docker run \
      --name keycloak \
      --network keycloak \
      --network-alias keycloak \
      --env-file '${local.keycloak_env_path}' \
      --publish 127.0.0.1:9000:9000 \
      --pull always \
      '${var.keycloak_image}' \
      start
  SCRIPT

  run_traefik_script = <<-SCRIPT
    #!/bin/sh
    set -eu

    /usr/bin/docker rm -f keycloak-traefik >/dev/null 2>&1 || true
    exec /usr/bin/docker run \
      --name keycloak-traefik \
      --network keycloak \
      --env AWS_REGION='${var.aws_region}' \
      --env AWS_HOSTED_ZONE_ID='${data.aws_route53_zone.acme.zone_id}' \
      --publish 443:443 \
      --volume '${local.traefik_acme_storage_host_dir}:/etc/traefik/acme' \
      --volume '${var.runtime_dir}/traefik_dynamic.yml:/etc/traefik/dynamic.yml:ro' \
      --pull always \
      '${var.traefik_image}' \
      --entrypoints.websecure.address=:443 \
      --certificatesresolvers.${local.traefik_certificate_resolver}.acme.email='${var.acme_email}' \
      --certificatesresolvers.${local.traefik_certificate_resolver}.acme.storage='${local.traefik_acme_storage_file}' \
      --certificatesresolvers.${local.traefik_certificate_resolver}.acme.caserver='${var.acme_ca_server}' \
      --certificatesresolvers.${local.traefik_certificate_resolver}.acme.dnschallenge.provider=route53 \
      --certificatesresolvers.${local.traefik_certificate_resolver}.acme.dnschallenge.resolvers='${var.traefik_dns_challenge_resolvers}' \
      --providers.file.filename=/etc/traefik/dynamic.yml \
      --providers.file.watch=true \
      --api.dashboard=false \
      --log.level=INFO
  SCRIPT

  traefik_dynamic_config = templatefile("${path.module}/templates/traefik_dynamic.yml.tftpl", {
    private_hostname             = var.private_hostname
    traefik_certificate_resolver = local.traefik_certificate_resolver
  })

  bootstrap_unit_name = "glab-keycloak-bootstrap.service"
  data_unit_name      = "glab-keycloak-data.service"
  network_unit_name   = "glab-keycloak-network.service"
  postgres_unit_name  = "glab-keycloak-postgres.service"
  keycloak_unit_name  = "glab-keycloak.service"
  traefik_unit_name   = "glab-keycloak-traefik.service"

  data_unit = <<-UNIT
    [Unit]
    Description=Prepare Keycloak data volume
    Before=${local.bootstrap_unit_name} ${local.postgres_unit_name} ${local.traefik_unit_name}

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=${local.helper_script_dir}/prepare-data.sh

    [Install]
    WantedBy=multi-user.target
  UNIT

  network_unit = <<-UNIT
    [Unit]
    Description=Create Keycloak Docker network
    Requires=docker.service
    After=docker.service
    Before=${local.postgres_unit_name} ${local.keycloak_unit_name} ${local.traefik_unit_name}

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=${local.helper_script_dir}/create-network.sh

    [Install]
    WantedBy=multi-user.target
  UNIT

  bootstrap_unit = <<-UNIT
    [Unit]
    Description=Fetch Keycloak bootstrap secrets with labctl
    Wants=network-online.target
    Requires=docker.service ${local.data_unit_name}
    After=network-online.target docker.service ${local.data_unit_name}
    Before=${local.postgres_unit_name} ${local.keycloak_unit_name} ${local.traefik_unit_name}

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStartPre=/usr/bin/mkdir -p ${var.bootstrap_runtime_dir}
    ExecStartPre=/usr/bin/chmod 0700 ${var.bootstrap_runtime_dir}
    ExecStartPre=/usr/bin/rm -f ${var.bootstrap_output_path} ${local.keycloak_env_path}
    ExecStart=/usr/bin/docker run --rm --network host --user 0:0 -v ${var.bootstrap_runtime_dir}:${var.bootstrap_runtime_dir} ${var.labctl_image} secrets get ${var.bootstrap_secret_path} --source github --field ${var.bootstrap_field} --output ${var.bootstrap_output_path} --aws-region ${var.aws_region} --broker-function ${var.github_token_broker_function_name}

    [Install]
    WantedBy=multi-user.target
  UNIT

  postgres_unit = <<-UNIT
    [Unit]
    Description=Keycloak Postgres container
    Requires=docker.service ${local.data_unit_name} ${local.network_unit_name} ${local.bootstrap_unit_name}
    After=docker.service ${local.data_unit_name} ${local.network_unit_name} ${local.bootstrap_unit_name}

    [Service]
    Restart=always
    RestartSec=10
    EnvironmentFile=${var.bootstrap_output_path}
    ExecStart=${local.helper_script_dir}/run-postgres.sh
    ExecStop=-/usr/bin/docker stop keycloak-postgres
    ExecStopPost=-/usr/bin/docker rm -f keycloak-postgres
    TimeoutStartSec=0

    [Install]
    WantedBy=multi-user.target
  UNIT

  keycloak_unit = <<-UNIT
    [Unit]
    Description=Keycloak container
    Requires=docker.service ${local.network_unit_name} ${local.bootstrap_unit_name} ${local.postgres_unit_name}
    After=docker.service ${local.network_unit_name} ${local.bootstrap_unit_name} ${local.postgres_unit_name}

    [Service]
    Restart=always
    RestartSec=10
    EnvironmentFile=${var.bootstrap_output_path}
    ExecStartPre=${local.helper_script_dir}/wait-postgres.sh
    ExecStart=${local.helper_script_dir}/run-keycloak.sh
    ExecStop=-/usr/bin/docker stop keycloak
    ExecStopPost=-/usr/bin/docker rm -f keycloak
    TimeoutStartSec=0

    [Install]
    WantedBy=multi-user.target
  UNIT

  traefik_unit = <<-UNIT
    [Unit]
    Description=Keycloak Traefik container
    Requires=docker.service ${local.network_unit_name} ${local.data_unit_name} ${local.keycloak_unit_name}
    After=docker.service ${local.network_unit_name} ${local.data_unit_name} ${local.keycloak_unit_name}

    [Service]
    Restart=always
    RestartSec=10
    ExecStart=${local.helper_script_dir}/run-traefik.sh
    ExecStop=-/usr/bin/docker stop keycloak-traefik
    ExecStopPost=-/usr/bin/docker rm -f keycloak-traefik
    TimeoutStartSec=0

    [Install]
    WantedBy=multi-user.target
  UNIT

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
  ]

  ignition_config = jsonencode({
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
          contents = local.traefik_unit
          enabled  = true
          name     = local.traefik_unit_name
        },
      ]
    }
  })
}
