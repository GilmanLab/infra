locals {
  common_tags = merge(var.tags, {
    "glab:project" = "glab"
    "glab:domain"  = "security/pki"
    "glab:purpose" = "root-ca"
  })
}

resource "aws_kms_key" "root_ca" {
  description              = "Root CA signing key for the glab internal PKI. Used only for intermediate issuance and rotation."
  customer_master_key_spec = var.key_spec
  key_usage                = "SIGN_VERIFY"
  deletion_window_in_days  = var.deletion_window_in_days
  multi_region             = false

  tags = local.common_tags
}

resource "aws_kms_alias" "root_ca" {
  name          = "alias/${var.key_alias}"
  target_key_id = aws_kms_key.root_ca.key_id
}
