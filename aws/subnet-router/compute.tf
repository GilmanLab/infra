resource "aws_instance" "subnet_router" {
  ami                  = data.aws_ssm_parameter.al2023_arm64.value
  iam_instance_profile = aws_iam_instance_profile.subnet_router.name
  instance_type        = var.instance_type
  source_dest_check    = false
  subnet_id            = data.aws_subnet.public.id
  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    tailscale_advertise_routes_csv  = local.tailscale_advertise_routes_csv
    tailscale_audience              = var.tailscale_audience
    tailscale_client_id_with_params = local.tailscale_client_id_with_params
    tailscale_hostname              = var.instance_name
    tailscale_tag                   = var.tailscale_tag
  })
  user_data_replace_on_change = true
  vpc_security_group_ids      = [aws_security_group.subnet_router.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_size           = 8
    volume_type           = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = var.instance_name
  })
}

resource "aws_eip" "subnet_router" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = var.instance_name
  })
}

resource "aws_eip_association" "subnet_router" {
  allocation_id        = aws_eip.subnet_router.id
  network_interface_id = aws_instance.subnet_router.primary_network_interface_id
}

resource "aws_route" "lab" {
  for_each = var.lab_cidrs

  destination_cidr_block = each.value
  network_interface_id   = aws_instance.subnet_router.primary_network_interface_id
  route_table_id         = data.aws_route_table.public.id
}
