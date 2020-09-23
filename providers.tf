# AWS Provider
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_akey
  secret_key = var.aws_skey
}

