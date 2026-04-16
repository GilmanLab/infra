terraform {
  backend "s3" {
    bucket       = "gilmanlab-tfstate"
    key          = "network/tailscale.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
