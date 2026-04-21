terraform {
  backend "s3" {
    key          = "security/pki/root-ca.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
