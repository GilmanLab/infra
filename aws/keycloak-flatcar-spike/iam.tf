resource "aws_iam_role" "flatcar" {
  assume_role_policy = local.flatcar_assume_role_policy
  name               = var.iam_role_name

  tags = merge(local.common_tags, {
    Name = var.iam_role_name
  })
}

resource "aws_iam_role_policy" "github_token_broker_invoke" {
  name   = "${var.iam_role_name}-github-token-broker-invoke"
  policy = local.github_token_broker_invoke_policy
  role   = aws_iam_role.flatcar.id
}

resource "aws_iam_role_policy" "sops_keycloak_decrypt" {
  name   = "${var.iam_role_name}-sops-keycloak-decrypt"
  policy = local.sops_keycloak_decrypt_policy
  role   = aws_iam_role.flatcar.id
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.flatcar.name
}

resource "aws_iam_instance_profile" "flatcar" {
  name = var.iam_role_name
  role = aws_iam_role.flatcar.name
}
