# =============================================================================
# Sorties du module VPC
# =============================================================================
# Ces sorties sont utilisées par les autres modules (EKS, RDS) pour
# référencer les ressources réseau créées par ce module.

output "vpc_id" {
  description = "Identifiant du VPC créé. Utilisé par les modules EKS et RDS."
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Liste des identifiants des sous-réseaux privés. Utilisés pour les nœuds EKS et les instances RDS."
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "public_subnet_ids" {
  description = "Liste des identifiants des sous-réseaux publics. Utilisés pour les load balancers et les NAT Gateways."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "nat_gateway_ids" {
  description = "Liste des identifiants des NAT Gateways. Utile pour le monitoring et le débogage réseau."
  value       = aws_nat_gateway.main[*].id
}
