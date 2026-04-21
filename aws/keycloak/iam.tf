resource "aws_iam_role" "keycloak" {
  assume_role_policy = data.aws_iam_policy_document.keycloak_assume_role.json
  name               = var.iam_role_name

  tags = merge(local.common_tags, {
    Name = var.iam_role_name
  })
}

resource "aws_iam_role_policy" "keycloak_bootstrap_parameters" {
  name   = "${var.iam_role_name}-bootstrap-parameters"
  policy = data.aws_iam_policy_document.keycloak_bootstrap_parameters.json
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
