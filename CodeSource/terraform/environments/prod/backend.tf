terraform {
  backend "s3" {
    bucket         = "techshop-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "techshop-terraform-locks"
    encrypt        = true
  }
}
