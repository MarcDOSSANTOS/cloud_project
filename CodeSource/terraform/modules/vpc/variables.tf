# =============================================================================
# Variables du module VPC
# =============================================================================

variable "vpc_cidr" {
  description = "Bloc CIDR du VPC principal. Doit être suffisamment large pour tous les sous-réseaux."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "Le vpc_cidr doit être un bloc CIDR valide (ex: 10.0.0.0/16)."
  }
}

variable "cluster_name" {
  description = "Nom du cluster EKS. Utilisé pour les tags de découverte automatique des sous-réseaux."
  type        = string

  validation {
    condition     = length(var.cluster_name) > 0
    error_message = "Le nom du cluster ne peut pas être vide."
  }
}

variable "environment" {
  description = "Environnement de déploiement (dev, staging, prod). Influence le nombre de NAT Gateways."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être 'dev', 'staging' ou 'prod'."
  }
}

variable "single_nat_gateway" {
  description = "Utiliser un seul NAT Gateway (true pour dev/staging, false pour prod). Un seul NAT réduit les coûts mais diminue la haute disponibilité."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags additionnels à appliquer à toutes les ressources du module VPC."
  type        = map(string)
  default     = {}
}
