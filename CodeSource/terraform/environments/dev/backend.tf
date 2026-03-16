# ============================================
# Backend Terraform - Environnement Dev
# ============================================
# Décommenter après avoir créé le bucket S3 et la table DynamoDB
# avec la commande : terraform apply -target=module.terraform_state
# ============================================

terraform {
  backend "s3" {
    bucket         = "techshop-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "techshop-terraform-locks"
    encrypt        = true
  }
}
