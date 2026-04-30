locals {
  common_tags = merge(var.tags, {
    "glab:project" = "glab"
    "glab:domain"  = "aws"
    "glab:purpose" = "keycloak-flatcar-spike"
  })

  flatcar_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  github_token_broker_invoke_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "lambda:InvokeFunction",
        ]
        Effect = "Allow"
        Resource = [
          data.aws_lambda_function.github_token_broker.arn,
        ]
        Sid = "AllowInvokeGitHubTokenBroker"
      },
    ]
  })

  sops_keycloak_decrypt_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Decrypt",
        ]
        Condition = {
          StringEquals = {
            "kms:EncryptionContext:Repo"  = var.sops_kms_context_repo
            "kms:EncryptionContext:Scope" = var.sops_kms_context_scope
          }
        }
        Effect = "Allow"
        Resource = [
          var.sops_kms_key_arn,
        ]
        Sid = "AllowDecryptKeycloakSopsSecrets"
      },
    ]
  })

  bootstrap_unit_name = "glab-keycloak-bootstrap.service"

  bootstrap_unit = <<-UNIT
    [Unit]
    Description=Fetch Keycloak bootstrap secrets with labctl
    Wants=network-online.target
    After=network-online.target docker.service
    Requires=docker.service

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStartPre=/usr/bin/mkdir -p ${var.bootstrap_runtime_dir}
    ExecStartPre=/usr/bin/chmod 0700 ${var.bootstrap_runtime_dir}
    ExecStartPre=/usr/bin/rm -f ${var.bootstrap_output_path}
    ExecStart=/usr/bin/docker run --rm --network host --user 0:0 -v ${var.bootstrap_runtime_dir}:${var.bootstrap_runtime_dir} ${var.labctl_image} secrets get ${var.bootstrap_secret_path} --source github --field ${var.bootstrap_field} --output ${var.bootstrap_output_path} --aws-region ${var.aws_region} --broker-function ${var.github_token_broker_function_name}

    [Install]
    WantedBy=multi-user.target
  UNIT

  ignition_config = jsonencode({
    ignition = {
      version = "3.3.0"
    }
    systemd = {
      units = [
        {
          enabled = true
          name    = "amazon-ssm-agent.service"
        },
        {
          contents = local.bootstrap_unit
          enabled  = true
          name     = local.bootstrap_unit_name
        },
      ]
    }
  })
}
