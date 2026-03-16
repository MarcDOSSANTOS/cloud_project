# =============================================================================
# Sorties du module EKS
# =============================================================================
# Ces sorties sont utilisées pour configurer kubectl, le provider Kubernetes
# dans Terraform, et les autres modules qui interagissent avec le cluster.

output "cluster_id" {
  description = "Identifiant unique du cluster EKS. Utilisé pour référencer le cluster dans d'autres ressources AWS."
  value       = aws_eks_cluster.main.id
}

output "cluster_endpoint" {
  description = "URL de l'API server Kubernetes. Utilisé par kubectl et le provider Kubernetes Terraform."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Certificat CA du cluster encodé en base64. Nécessaire pour l'authentification TLS avec l'API server."
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Identifiant du groupe de sécurité du cluster. Utilisé pour autoriser le trafic depuis d'autres ressources (ex: RDS)."
  value       = aws_security_group.eks_cluster.id
}

output "node_group_arn" {
  description = "ARN du groupe de nœuds managé. Utile pour le monitoring et les politiques IAM."
  value       = aws_eks_node_group.main.arn
}

output "oidc_provider_arn" {
  description = "ARN du fournisseur OIDC. Nécessaire pour configurer IRSA (IAM Roles for Service Accounts)."
  value       = aws_iam_openid_connect_provider.eks.arn
}
