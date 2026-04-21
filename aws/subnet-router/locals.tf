locals {
  common_tags = {
    "glab:project" = "glab"
    "glab:domain"  = "aws"
    "glab:purpose" = "subnet-router"
  }

  dns_mirror_compose = templatefile("${path.module}/templates/dns_mirror_compose.yml.tftpl", {
    aws_region                = var.aws_region
    dns_mirror_hosted_zone_id = var.dns_mirror_hosted_zone_id
    dns_mirror_image          = var.dns_mirror_image
    dns_mirror_listen_addr    = var.dns_mirror_listen_addr
    dns_mirror_output_path    = var.dns_mirror_output_path
    dns_mirror_state_dir      = var.dns_mirror_state_dir
    dns_mirror_sync_interval  = var.dns_mirror_sync_interval
  })
  dns_mirror_service_unit = templatefile("${path.module}/templates/dns_mirror.service.tftpl", {
    dns_mirror_runtime_dir = var.dns_mirror_runtime_dir
  })
  dns_mirror_bootstrap_script = templatefile("${path.module}/templates/dns_mirror_bootstrap.sh.tftpl", {
    dns_mirror_compose      = local.dns_mirror_compose
    dns_mirror_runtime_dir  = var.dns_mirror_runtime_dir
    dns_mirror_service_unit = local.dns_mirror_service_unit
    dns_mirror_state_dir    = var.dns_mirror_state_dir
  })
  tailscale_advertise_routes_csv  = join(",", sort(tolist(var.tailscale_advertise_routes)))
  tailscale_client_id_with_params = "${var.tailscale_client_id}?ephemeral=false&preauthorized=true"
}
