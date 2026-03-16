# =============================================================================
# Variables racine - TechShop E-commerce
# =============================================================================
# Variables globales utilisées par tous les modules de l'infrastructure.
# Les valeurs par défaut sont configurées pour l'environnement de développement.
# =============================================================================

variable "aws_region" {
  description = "Région AWS de déploiement. eu-west-1 (Irlande) est recommandé pour les projets européens (conformité RGPD)."
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environnement de déploiement. Détermine la taille des ressources, la haute disponibilité et les politiques de sécurité."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être 'dev', 'staging' ou 'prod'."
  }
}

variable "project_name" {
  description = "Nom du projet. Utilisé comme préfixe pour toutes les ressources et dans les tags."
  type        = string
  default     = "techshop"
}

variable "cluster_name" {
  description = "Nom du cluster EKS. Si non spécifié, sera construit à partir du nom du projet et de l'environnement."
  type        = string
  default     = ""
}

variable "db_password" {
  description = "Mot de passe de la base de données PostgreSQL. IMPORTANT : ne jamais stocker en clair dans le code. Utiliser une variable d'environnement TF_VAR_db_password ou un fichier .tfvars ignoré par Git."
  type        = string
  sensitive   = true
}
