terraform {
  backend "s3" {
    key          = "aws/keycloak-flatcar-spike.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
