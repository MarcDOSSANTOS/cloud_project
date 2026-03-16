# =============================================================================
# Backend Terraform - TechShop E-commerce
# =============================================================================
# Configuration du backend S3 pour stocker l'état Terraform de manière
# centralisée et sécurisée. Utilise DynamoDB pour le verrouillage d'état
# afin d'éviter les modifications concurrentes.
#
# INSTRUCTIONS DE BOOTSTRAP :
# 1. Commencer avec le backend local (laisser le bloc commenté ci-dessous)
# 2. Exécuter 'terraform apply' pour créer le bucket S3 et la table DynamoDB
# 3. Décommenter le bloc backend "s3" ci-dessous
# 4. Exécuter 'terraform init -migrate-state' pour migrer l'état vers S3
# =============================================================================

# --- Backend S3 (à décommenter après le bootstrap initial) ---

# terraform {
#   backend "s3" {
#     bucket         = "techshop-terraform-state"
#     key            = "terraform.tfstate"
#     region         = "eu-west-1"
#     dynamodb_table = "techshop-terraform-locks"
#     encrypt        = true
#   }
# }

# =============================================================================
# Ressources de bootstrap pour le backend
# =============================================================================
# Ces ressources créent le bucket S3 et la table DynamoDB nécessaires
# pour le backend distant. Elles ne sont créées que lors du bootstrap initial.

# Variable pour contrôler la création des ressources de bootstrap
variable "create_backend_resources" {
  description = "Créer les ressources S3 et DynamoDB pour le backend Terraform. Mettre à true uniquement lors du bootstrap initial."
  type        = bool
  default     = false
}

# --- Bucket S3 pour l'état Terraform ---

resource "aws_s3_bucket" "terraform_state" {
  count  = var.create_backend_resources ? 1 : 0
  bucket = "${var.project_name}-terraform-state"

  # Empêcher la suppression accidentelle du bucket contenant l'état
  force_destroy = false

  tags = {
    Name        = "${var.project_name}-terraform-state"
    Project     = var.project_name
    Environment = "shared"
    ManagedBy   = "terraform"
    Purpose     = "Stockage de l etat Terraform"
  }
}

# Activer le versionnement pour pouvoir restaurer un état précédent
resource "aws_s3_bucket_versioning" "terraform_state" {
  count  = var.create_backend_resources ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

# Chiffrement côté serveur par défaut (AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count  = var.create_backend_resources ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bloquer tout accès public au bucket d'état
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  count  = var.create_backend_resources ? 1 : 0
  bucket = aws_s3_bucket.terraform_state[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Table DynamoDB pour le verrouillage d'état ---

resource "aws_dynamodb_table" "terraform_locks" {
  count = var.create_backend_resources ? 1 : 0

  name         = "${var.project_name}-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-terraform-locks"
    Project     = var.project_name
    Environment = "shared"
    ManagedBy   = "terraform"
    Purpose     = "Verrouillage de l etat Terraform"
  }
}
