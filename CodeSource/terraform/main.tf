# =============================================================================
# Configuration principale - TechShop E-commerce
# =============================================================================
# Ce fichier orchestre tous les modules Terraform pour créer l'infrastructure
# complète du projet TechShop sur AWS :
# - Réseau (VPC, sous-réseaux, routage)
# - Orchestration de conteneurs (EKS)
# - Base de données (RDS PostgreSQL)
# - Registre d'images Docker (ECR)
# =============================================================================

# --- Variables locales ---

locals {
  # Nom du cluster : utilise la variable cluster_name si définie,
  # sinon construit un nom à partir du projet et de l'environnement
  cluster_name = var.cluster_name != "" ? var.cluster_name : "${var.project_name}-${var.environment}"

  # Configuration des nœuds EKS selon l'environnement
  # dev     : petites instances, peu de nœuds (économie de coûts)
  # staging : instances moyennes, capacité modérée
  # prod    : grandes instances, haute disponibilité
  node_config = {
    dev = {
      instance_types = ["t3.medium"]
      desired_size   = 2
      min_size       = 1
      max_size       = 3
    }
    staging = {
      instance_types = ["t3.large"]
      desired_size   = 2
      min_size       = 2
      max_size       = 4
    }
    prod = {
      instance_types = ["m5.xlarge"]
      desired_size   = 3
      min_size       = 3
      max_size       = 10
    }
  }

  # Configuration RDS selon l'environnement
  rds_config = {
    dev = {
      instance_class          = "db.t3.micro"
      allocated_storage       = 20
      multi_az                = false
      backup_retention_period = 1
      skip_final_snapshot     = true
    }
    staging = {
      instance_class          = "db.t3.small"
      allocated_storage       = 50
      multi_az                = false
      backup_retention_period = 7
      skip_final_snapshot     = true
    }
    prod = {
      instance_class          = "db.r5.large"
      allocated_storage       = 100
      multi_az                = true
      backup_retention_period = 30
      skip_final_snapshot     = false
    }
  }

  # Tags communs à toutes les ressources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# Module VPC
# =============================================================================
# Crée le réseau virtuel avec sous-réseaux publics et privés,
# passerelles Internet et NAT, et tables de routage

module "vpc" {
  source = "./modules/vpc"

  vpc_cidr     = "10.0.0.0/16"
  cluster_name = local.cluster_name
  environment  = var.environment

  # En dev et staging : un seul NAT Gateway (économie ~$32/mois par NAT supprimé)
  # En prod : un NAT Gateway par AZ pour la haute disponibilité
  single_nat_gateway = var.environment != "prod"

  tags = local.common_tags
}

# =============================================================================
# Module EKS
# =============================================================================
# Crée le cluster Kubernetes managé avec les nœuds workers,
# les rôles IAM et les addons essentiels

module "eks" {
  source = "./modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = "1.28"
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  environment     = var.environment

  # Configuration des nœuds selon l'environnement
  node_instance_types = local.node_config[var.environment].instance_types
  node_desired_size   = local.node_config[var.environment].desired_size
  node_min_size       = local.node_config[var.environment].min_size
  node_max_size       = local.node_config[var.environment].max_size

  tags = local.common_tags
}

# =============================================================================
# Module RDS
# =============================================================================
# Crée l'instance PostgreSQL avec accès restreint depuis le cluster EKS

module "rds" {
  source = "./modules/rds"

  identifier  = "${var.project_name}-${var.environment}-db"
  db_name     = "techshop"
  db_username = "techshop_admin"
  db_password = var.db_password

  # Configuration selon l'environnement
  instance_class          = local.rds_config[var.environment].instance_class
  allocated_storage       = local.rds_config[var.environment].allocated_storage
  multi_az                = local.rds_config[var.environment].multi_az
  backup_retention_period = local.rds_config[var.environment].backup_retention_period
  skip_final_snapshot     = local.rds_config[var.environment].skip_final_snapshot

  # Réseau : sous-réseaux privés et accès restreint depuis EKS uniquement
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  allowed_security_groups = [module.eks.cluster_security_group_id]

  environment = var.environment
  tags        = local.common_tags
}

# =============================================================================
# Module ECR
# =============================================================================
# Crée les dépôts d'images Docker pour chaque microservice

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name

  # Liste des 5 microservices du projet TechShop
  services = [
    "api-gateway",
    "frontend",
    "user-service",
    "product-service",
    "order-service"
  ]

  tags = local.common_tags
}
