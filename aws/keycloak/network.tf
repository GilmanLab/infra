resource "aws_security_group" "keycloak" {
  description = "Security group for the AWS Keycloak instance."
  name        = var.security_group_name
  vpc_id      = data.aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = var.security_group_name
  })
}

resource "aws_vpc_security_group_egress_rule" "keycloak_ipv4" {
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  security_group_id = aws_security_group.keycloak.id
}

resource "aws_vpc_security_group_egress_rule" "keycloak_ipv6" {
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
  security_group_id = aws_security_group.keycloak.id
}

resource "aws_vpc_security_group_ingress_rule" "keycloak_https" {
  for_each = var.lab_cidrs

  cidr_ipv4         = each.value
  description       = "Allow lab-side HTTPS traffic from ${each.value}."
  from_port         = 443
  ip_protocol       = "tcp"
  security_group_id = aws_security_group.keycloak.id
  to_port           = 443
}

resource "aws_route53_record" "private" {
  name    = var.private_hostname
  records = [aws_instance.keycloak.private_ip]
  ttl     = var.dns_record_ttl
  type    = "A"
  zone_id = data.aws_route53_zone.private.zone_id
}
