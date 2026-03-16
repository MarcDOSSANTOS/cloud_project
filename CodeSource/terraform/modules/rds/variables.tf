# =============================================================================
# Variables du module RDS
# =============================================================================

variable "identifier" {
  description = "Identifiant unique de l'instance RDS. Utilisé comme nom de la ressource dans AWS."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.identifier))
    error_message = "L'identifiant doit commencer par une lettre minuscule et ne contenir que des lettres minuscules, chiffres et tirets."
  }
}

variable "db_name" {
  description = "Nom de la base de données initiale à créer lors du provisionnement."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "Le nom de la base de données doit commencer par une lettre et ne contenir que des lettres, chiffres et underscores."
  }
}

variable "db_username" {
  description = "Nom d'utilisateur administrateur de la base de données. Ne pas utiliser 'admin' ou 'postgres' en production."
  type        = string

  validation {
    condition     = length(var.db_username) >= 3
    error_message = "Le nom d'utilisateur doit contenir au moins 3 caractères."
  }
}

variable "db_password" {
  description = "Mot de passe de l'utilisateur administrateur. Doit être stocké de manière sécurisée (AWS Secrets Manager recommandé)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Le mot de passe doit contenir au moins 8 caractères."
  }
}

variable "instance_class" {
  description = "Classe d'instance RDS. Exemples : db.t3.micro (dev), db.t3.small (staging), db.r5.large (prod)."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Espace de stockage alloué en Go. Le stockage peut croître automatiquement jusqu'au double de cette valeur."
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "Le stockage minimum pour PostgreSQL est de 20 Go."
  }
}

variable "vpc_id" {
  description = "Identifiant du VPC dans lequel déployer l'instance RDS."
  type        = string
}

variable "subnet_ids" {
  description = "Liste des identifiants de sous-réseaux privés pour le groupe de sous-réseaux RDS. Minimum 2 AZ requises."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Au moins 2 sous-réseaux dans des AZ différentes sont requis pour RDS."
  }
}

variable "allowed_security_groups" {
  description = "Liste des identifiants de groupes de sécurité autorisés à accéder au port PostgreSQL (5432). Typiquement le SG du cluster EKS."
  type        = list(string)
}

variable "multi_az" {
  description = "Activer le déploiement Multi-AZ pour la haute disponibilité. Recommandé pour la production (doublement du coût)."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Nombre de jours de rétention des sauvegardes automatiques. 0 pour désactiver, 35 max."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "La période de rétention doit être entre 0 et 35 jours."
  }
}

variable "skip_final_snapshot" {
  description = "Ignorer le snapshot final lors de la suppression. True pour dev (destruction rapide), false pour prod (sécurité des données)."
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environnement de déploiement (dev, staging, prod). Influence les paramètres de sécurité et de performance."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être 'dev', 'staging' ou 'prod'."
  }
}

variable "tags" {
  description = "Tags additionnels à appliquer à toutes les ressources du module RDS."
  type        = map(string)
  default     = {}
}
