resource "aws_ssm_association" "keycloak" {
  name = "AWS-RunShellScript"

  parameters = {
    commands = local.bootstrap_script
  }

  targets {
    key = "InstanceIds"
    values = [
      aws_instance.keycloak.id,
    ]
  }

  wait_for_success_timeout_seconds = 1200

  depends_on = [
    aws_iam_role_policy.keycloak_acme_route53,
    aws_iam_role_policy.keycloak_bootstrap_parameters,
    aws_iam_role_policy_attachment.keycloak_ssm_managed_instance_core,
  ]
}
