resource "aws_iam_role" "keycloak" {
  assume_role_policy = data.aws_iam_policy_document.keycloak_assume_role.json
  name               = var.iam_role_name

  tags = merge(local.common_tags, {
    Name = var.iam_role_name
  })
}

resource "aws_iam_role_policy" "keycloak_acme_route53" {
  name   = "${var.iam_role_name}-acme-route53"
  policy = data.aws_iam_policy_document.keycloak_acme_route53.json
  role   = aws_iam_role.keycloak.id
}

resource "aws_iam_role_policy" "keycloak_sops_decrypt" {
  name   = "${var.iam_role_name}-sops-keycloak-decrypt"
  policy = data.aws_iam_policy_document.keycloak_sops_decrypt.json
  role   = aws_iam_role.keycloak.id
}

resource "aws_iam_role_policy_attachment" "keycloak_ssm_managed_instance_core" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.keycloak.name
}

resource "aws_iam_instance_profile" "keycloak" {
  name = var.iam_role_name
  role = aws_iam_role.keycloak.name
}
