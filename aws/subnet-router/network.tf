resource "aws_security_group" "subnet_router" {
  description = "Security group for the AWS Tailscale subnet router."
  name        = var.security_group_name
  vpc_id      = data.aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = var.security_group_name
  })
}

resource "aws_vpc_security_group_egress_rule" "subnet_router_ipv4" {
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  security_group_id = aws_security_group.subnet_router.id
}

resource "aws_vpc_security_group_egress_rule" "subnet_router_ipv6" {
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
  security_group_id = aws_security_group.subnet_router.id
}

resource "aws_vpc_security_group_ingress_rule" "subnet_router_tailscale_udp" {
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow direct Tailscale WireGuard traffic."
  from_port         = 41641
  ip_protocol       = "udp"
  security_group_id = aws_security_group.subnet_router.id
  to_port           = 41641
}

resource "aws_vpc_security_group_ingress_rule" "subnet_router_lab" {
  for_each = var.lab_cidrs

  cidr_ipv4         = each.value
  description       = "Allow lab-side traffic from ${each.value}."
  from_port         = -1
  ip_protocol       = "-1"
  security_group_id = aws_security_group.subnet_router.id
  to_port           = -1
}
