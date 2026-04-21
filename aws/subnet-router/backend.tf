terraform {
  backend "s3" {
    key          = "aws/subnet-router.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
