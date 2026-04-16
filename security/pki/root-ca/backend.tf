terraform {
  backend "s3" {
    bucket       = "gilmanlab-tfstate"
    key          = "security/pki/root-ca.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
