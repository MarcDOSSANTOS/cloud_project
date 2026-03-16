# =============================================================================
# Module RDS - TechShop E-commerce
# =============================================================================
# Ce module crée une instance PostgreSQL RDS avec :
# - Instance configurée selon l'environnement (dev/staging/prod)
# - Sous-réseau dédié dans les sous-réseaux privés du VPC
# - Groupe de sécurité restrictif (accès uniquement depuis EKS)
# - Options de haute disponibilité et de sauvegarde configurables
# =============================================================================

# --- Variables locales ---

locals {
  # Tags communs appliqués à toutes les ressources du module
  common_tags = merge(var.tags, {
    Module      = "rds"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# =============================================================================
# Groupe de sous-réseaux pour RDS
# =============================================================================
# RDS nécessite un groupe de sous-réseaux couvrant au moins 2 AZ
# On utilise les sous-réseaux privés pour isoler la base de données d'Internet

resource "aws_db_subnet_group" "main" {
  name        = "${var.identifier}-subnet-group"
  description = "Groupe de sous-reseaux pour l instance RDS ${var.identifier}"
  subnet_ids  = var.subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

# =============================================================================
# Groupe de sécurité pour RDS
# =============================================================================
# Accès restreint : seuls les groupes de sécurité autorisés (EKS) peuvent
# atteindre le port PostgreSQL (5432)

resource "aws_security_group" "rds" {
  name        = "${var.identifier}-rds-sg"
  description = "Groupe de securite pour l instance RDS ${var.identifier} - acces restreint depuis EKS"
  vpc_id      = var.vpc_id

  # Règle entrante : autoriser le trafic PostgreSQL uniquement depuis les
  # groupes de sécurité spécifiés (typiquement celui du cluster EKS)
  ingress {
    description     = "Acces PostgreSQL depuis les groupes de securite autorises (EKS)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
  }

  # Règle sortante : autoriser tout le trafic sortant
  # Nécessaire pour les mises à jour et la communication avec les services AWS
  egress {
    description = "Autoriser tout le trafic sortant"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.identifier}-rds-sg"
  })
}

# =============================================================================
# Instance RDS PostgreSQL
# =============================================================================

resource "aws_db_instance" "main" {
  identifier = var.identifier

  # --- Configuration du moteur ---
  engine               = "postgres"
  engine_version       = "16"
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  max_allocated_storage = var.allocated_storage * 2  # Auto-scaling du stockage (double de la taille initiale)
  storage_type         = "gp3"
  storage_encrypted    = true  # Chiffrement au repos activé par défaut

  # --- Configuration de la base de données ---
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  # --- Configuration réseau ---
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false  # Jamais accessible depuis Internet

  # --- Haute disponibilité ---
  multi_az = var.multi_az

  # --- Sauvegardes ---
  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"  # Fenêtre de sauvegarde : 3h-4h UTC
  maintenance_window      = "sun:04:00-sun:05:00"  # Maintenance le dimanche 4h-5h UTC

  # --- Snapshot final ---
  # En dev, on saute le snapshot final pour accélérer la destruction
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final-snapshot"

  # --- Mises à jour ---
  auto_minor_version_upgrade  = true
  allow_major_version_upgrade = false
  apply_immediately           = var.environment == "dev" ? true : false

  # --- Monitoring ---
  performance_insights_enabled = var.environment == "prod" ? true : false

  # --- Protection contre la suppression accidentelle ---
  deletion_protection = var.environment == "prod" ? true : false

  tags = merge(local.common_tags, {
    Name = var.identifier
  })
}
