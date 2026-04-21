terraform {
  backend "s3" {
    key          = "aws/lab-foundation.tfstate"
    region       = "us-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
