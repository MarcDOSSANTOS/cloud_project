# =============================================================================
# Variables du module EKS
# =============================================================================

variable "cluster_name" {
  description = "Nom du cluster EKS. Doit être unique dans la région AWS."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.cluster_name))
    error_message = "Le nom du cluster doit commencer par une lettre et ne contenir que des lettres, chiffres et tirets."
  }
}

variable "cluster_version" {
  description = "Version de Kubernetes pour le cluster EKS. Consulter la documentation AWS pour les versions supportées."
  type        = string
  default     = "1.28"

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.cluster_version))
    error_message = "La version du cluster doit être au format '1.XX' (ex: 1.28)."
  }
}

variable "vpc_id" {
  description = "Identifiant du VPC dans lequel déployer le cluster EKS."
  type        = string
}

variable "subnet_ids" {
  description = "Liste des identifiants de sous-réseaux pour les nœuds EKS. Utiliser les sous-réseaux privés pour la sécurité."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Au moins 2 sous-réseaux sont requis pour EKS (haute disponibilité)."
  }
}

variable "node_instance_types" {
  description = "Types d'instances EC2 pour les nœuds workers. Exemples : t3.medium (dev), t3.large (staging), m5.xlarge (prod)."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Nombre souhaité de nœuds dans le groupe de nœuds managé."
  type        = number
  default     = 2

  validation {
    condition     = var.node_desired_size >= 1
    error_message = "Le nombre souhaité de noeuds doit être au moins 1."
  }
}

variable "node_min_size" {
  description = "Nombre minimum de nœuds (auto-scaling). Ne descend jamais en dessous de cette valeur."
  type        = number
  default     = 1

  validation {
    condition     = var.node_min_size >= 1
    error_message = "Le nombre minimum de noeuds doit être au moins 1."
  }
}

variable "node_max_size" {
  description = "Nombre maximum de nœuds (auto-scaling). Limite les coûts en cas de montée en charge."
  type        = number
  default     = 4

  validation {
    condition     = var.node_max_size >= 1
    error_message = "Le nombre maximum de noeuds doit être au moins 1."
  }
}

variable "environment" {
  description = "Environnement de déploiement (dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être 'dev', 'staging' ou 'prod'."
  }
}

variable "tags" {
  description = "Tags additionnels à appliquer à toutes les ressources du module EKS."
  type        = map(string)
  default     = {}
}
