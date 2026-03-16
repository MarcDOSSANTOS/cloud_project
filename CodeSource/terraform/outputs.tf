# =============================================================================
# Sorties racine - TechShop E-commerce
# =============================================================================
# Sorties principales de l'infrastructure, affichées après chaque 'terraform apply'.
# Ces valeurs sont nécessaires pour configurer les pipelines CI/CD et les
# outils de développement.
# =============================================================================

output "vpc_id" {
  description = "Identifiant du VPC principal. Utile pour le débogage réseau et la configuration d'outils tiers."
  value       = module.vpc.vpc_id
}

output "eks_cluster_endpoint" {
  description = "URL de l'API server EKS. Utilisé pour configurer kubectl : aws eks update-kubeconfig --name <cluster_name> --region <region>"
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_urls" {
  description = "URLs des dépôts ECR par service. Utilisés dans les pipelines CI/CD pour pousser les images Docker."
  value       = module.ecr.repository_urls
}

output "rds_endpoint" {
  description = "Point de terminaison RDS (host:port). Utilisé pour configurer les chaînes de connexion des microservices."
  value       = module.rds.db_endpoint
}

# --- Sorties additionnelles utiles pour le développement ---

output "eks_cluster_name" {
  description = "Nom du cluster EKS. Utilisé avec la commande : aws eks update-kubeconfig --name <valeur>"
  value       = local.cluster_name
}

output "eks_oidc_provider_arn" {
  description = "ARN du fournisseur OIDC. Nécessaire pour configurer IRSA sur les Service Accounts Kubernetes."
  value       = module.eks.oidc_provider_arn
}
