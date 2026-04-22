data "aws_caller_identity" "current" {}

data "archive_file" "placeholder" {
  output_path = "${path.module}/.terraform/github-token-broker-placeholder.zip"
  type        = "zip"

  source {
    content  = <<-EOT
      #!/bin/sh
      echo "github-token-broker placeholder"
    EOT
    filename = "bootstrap"
  }
}
