data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  selected_availability_zone = var.availability_zone != "" ? var.availability_zone : data.aws_availability_zones.available.names[0]

  common_tags = merge(var.tags, {
    "glab:project" = "glab"
    "glab:domain"  = "aws"
    "glab:purpose" = "lab-foundation"
  })
}
