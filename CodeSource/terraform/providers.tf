# =============================================================================
# Providers Terraform - TechShop E-commerce
# =============================================================================
# Configuration des fournisseurs (providers) nécessaires pour gérer
# l'infrastructure AWS et les ressources Kubernetes.
# =============================================================================

terraform {
  # Version minimale de Terraform requise
  required_version = ">= 1.5.0"

  required_providers {
    # Provider AWS pour gérer toutes les ressources cloud
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    # Provider Kubernetes pour interagir avec le cluster EKS
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }

    # Provider TLS pour la gestion des certificats (OIDC)
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# =============================================================================
# Provider AWS
# =============================================================================
# Configuration principale du provider AWS avec la région de déploiement
# et les tags par défaut appliqués à toutes les ressources

provider "aws" {
  region = var.aws_region

  # Tags par défaut appliqués automatiquement à toutes les ressources AWS
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# =============================================================================
# Provider Kubernetes
# =============================================================================
# Configuré dynamiquement à partir des sorties du module EKS
# Permet de déployer des ressources Kubernetes directement depuis Terraform

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  # Authentification via le CLI AWS (recommandé par AWS)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
  }
}
