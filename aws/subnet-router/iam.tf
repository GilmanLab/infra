resource "aws_iam_role" "subnet_router" {
  assume_role_policy = data.aws_iam_policy_document.subnet_router_assume_role.json
  name               = var.iam_role_name

  tags = merge(local.common_tags, {
    Name = var.iam_role_name
  })
}

resource "aws_iam_role_policy" "subnet_router_tailscale_outbound_federation" {
  name   = "${var.iam_role_name}-tailscale-outbound-federation"
  policy = data.aws_iam_policy_document.subnet_router_tailscale_outbound_federation.json
  role   = aws_iam_role.subnet_router.id
}

resource "aws_iam_role_policy" "subnet_router_dns_mirror_route53" {
  name   = "${var.iam_role_name}-dns-mirror-route53"
  policy = data.aws_iam_policy_document.subnet_router_dns_mirror_route53.json
  role   = aws_iam_role.subnet_router.id
}

resource "aws_iam_role_policy_attachment" "subnet_router_ssm_managed_instance_core" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.subnet_router.name
}

resource "aws_iam_instance_profile" "subnet_router" {
  name = var.iam_role_name
  role = aws_iam_role.subnet_router.name
}
