resource "aws_instance" "keycloak" {
  ami                         = var.flatcar_ami_id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.keycloak.name
  instance_type               = var.instance_type
  subnet_id                   = data.aws_subnet.public.id
  user_data                   = local.ignition_config
  user_data_replace_on_change = true
  vpc_security_group_ids      = [aws_security_group.keycloak.id]

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  root_block_device {
    delete_on_termination = true
    encrypted             = true
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
  }

  tags = merge(local.common_tags, {
    Name = var.instance_name
  })
}

resource "aws_ebs_volume" "keycloak_data" {
  availability_zone = data.aws_subnet.public.availability_zone
  encrypted         = true
  size              = var.data_volume_size
  type              = "gp3"

  tags = merge(local.common_tags, {
    Name = "${var.instance_name}-data"
  })
}

resource "aws_volume_attachment" "keycloak_data" {
  device_name = var.data_volume_device_name
  instance_id = aws_instance.keycloak.id
  volume_id   = aws_ebs_volume.keycloak_data.id
}
