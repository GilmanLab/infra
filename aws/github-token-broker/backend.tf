terraform {
  backend "s3" {
    key          = "aws/github-token-broker.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
