# =============================================================================
# Sorties du module ECR
# =============================================================================
# Ces sorties fournissent les URLs et ARNs des dépôts, nécessaires pour :
# - Configurer les pipelines CI/CD (push des images)
# - Référencer les images dans les manifestes Kubernetes (pull des images)

output "repository_urls" {
  description = "Map des URLs des dépôts ECR indexée par nom de service. Format : <account_id>.dkr.ecr.<region>.amazonaws.com/<project>/<service>"
  value       = { for name, repo in aws_ecr_repository.services : name => repo.repository_url }
}

output "repository_arns" {
  description = "Map des ARNs des dépôts ECR indexée par nom de service. Utile pour les politiques IAM d'accès aux dépôts."
  value       = { for name, repo in aws_ecr_repository.services : name => repo.arn }
}
