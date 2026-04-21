resource "aws_ssm_association" "dns_mirror" {
  name = "AWS-RunShellScript"

  parameters = {
    commands = local.dns_mirror_bootstrap_script
  }

  targets {
    key = "InstanceIds"
    values = [
      aws_instance.subnet_router.id,
    ]
  }

  wait_for_success_timeout_seconds = 600
}
