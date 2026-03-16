# =============================================================================
# Sorties du module RDS
# =============================================================================
# Ces sorties sont utilisées pour configurer les services applicatifs
# (chaînes de connexion) et pour le monitoring.

output "db_endpoint" {
  description = "Point de terminaison de l'instance RDS (host:port). Utilisé dans les chaînes de connexion des microservices."
  value       = aws_db_instance.main.endpoint
}

output "db_port" {
  description = "Port de l'instance RDS (5432 par défaut pour PostgreSQL)."
  value       = aws_db_instance.main.port
}

output "db_name" {
  description = "Nom de la base de données créée. Utilisé dans les variables d'environnement des microservices."
  value       = aws_db_instance.main.db_name
}

output "db_instance_id" {
  description = "Identifiant de l'instance RDS. Utile pour les alarmes CloudWatch et le monitoring."
  value       = aws_db_instance.main.id
}
