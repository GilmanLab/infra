resource "aws_security_group" "flatcar" {
  description = "Outbound-only security group for the temporary Flatcar Keycloak spike."
  name        = var.security_group_name
  vpc_id      = data.aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = var.security_group_name
  })
}

resource "aws_vpc_security_group_egress_rule" "flatcar_ipv4" {
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  security_group_id = aws_security_group.flatcar.id
}

resource "aws_vpc_security_group_egress_rule" "flatcar_ipv6" {
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
  security_group_id = aws_security_group.flatcar.id
}
