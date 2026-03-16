terraform {
  backend "s3" {
    bucket         = "techshop-terraform-state"
    key            = "staging/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "techshop-terraform-locks"
    encrypt        = true
  }
}
