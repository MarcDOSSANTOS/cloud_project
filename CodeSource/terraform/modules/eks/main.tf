# =============================================================================
# Module EKS - TechShop E-commerce
# =============================================================================
# Ce module crée un cluster EKS complet avec :
# - Cluster EKS avec les rôles IAM nécessaires
# - Groupe de nœuds managé (Managed Node Group)
# - Groupes de sécurité pour le plan de contrôle
# - Fournisseur OIDC pour IRSA (IAM Roles for Service Accounts)
# - Addons essentiels : vpc-cni, coredns, kube-proxy
# =============================================================================

# --- Sources de données ---

# Récupération des informations TLS pour la configuration OIDC
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# --- Variables locales ---

locals {
  # Tags communs appliqués à toutes les ressources du module
  common_tags = merge(var.tags, {
    Module      = "eks"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# =============================================================================
# Rôle IAM pour le cluster EKS (plan de contrôle)
# =============================================================================
# Ce rôle permet au service EKS de gérer les ressources AWS nécessaires

resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"

  # Politique de confiance : seul le service EKS peut assumer ce rôle
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-cluster-role"
  })
}

# Attachement de la politique AmazonEKSClusterPolicy au rôle du cluster
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# =============================================================================
# Groupe de sécurité du cluster EKS
# =============================================================================
# Contrôle le trafic réseau vers et depuis le plan de contrôle EKS

resource "aws_security_group" "eks_cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Groupe de securite pour le plan de controle EKS ${var.cluster_name}"
  vpc_id      = var.vpc_id

  # Règle entrante : autoriser le trafic HTTPS (443) depuis le VPC
  # Nécessaire pour la communication entre les nœuds et l'API server
  ingress {
    description = "Trafic HTTPS depuis le VPC vers l API server EKS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  # Règle sortante : autoriser tout le trafic sortant
  # Nécessaire pour que le plan de contrôle communique avec les nœuds et AWS
  egress {
    description = "Autoriser tout le trafic sortant"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-cluster-sg"
  })
}

# Récupération des informations du VPC pour le CIDR
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# =============================================================================
# Cluster EKS
# =============================================================================

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  # Configuration réseau du cluster
  vpc_config {
    subnet_ids              = var.subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # Activation des logs du plan de contrôle pour le débogage
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = merge(local.common_tags, {
    Name = var.cluster_name
  })

  # S'assurer que les politiques IAM sont attachées avant de créer le cluster
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# =============================================================================
# Addons EKS
# =============================================================================
# Composants réseau et DNS essentiels au fonctionnement du cluster

# VPC CNI : gestion du réseau des pods (attribution des IP depuis le VPC)
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags
}

# CoreDNS : résolution DNS interne au cluster
resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags

  # CoreDNS nécessite des nœuds pour fonctionner
  depends_on = [aws_eks_node_group.main]
}

# kube-proxy : gestion des règles réseau (iptables) sur chaque nœud
resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = local.common_tags
}

# =============================================================================
# Rôle IAM pour les nœuds workers
# =============================================================================
# Ce rôle permet aux instances EC2 des nœuds de communiquer avec les services AWS

resource "aws_iam_role" "eks_nodes" {
  name = "${var.cluster_name}-node-role"

  # Politique de confiance : les instances EC2 peuvent assumer ce rôle
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-node-role"
  })
}

# Politique pour la gestion des nœuds EKS
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

# Politique pour le plugin CNI (gestion réseau des pods)
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

# Politique pour accéder aux images ECR (pull des conteneurs)
resource "aws_iam_role_policy_attachment" "eks_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# =============================================================================
# Groupe de nœuds managé (Managed Node Group)
# =============================================================================
# AWS gère automatiquement le cycle de vie des instances EC2

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.node_instance_types

  # Configuration de l'auto-scaling
  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  # Configuration de la mise à jour progressive des nœuds
  update_config {
    # Nombre maximum de nœuds indisponibles pendant une mise à jour
    max_unavailable = 1
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-node-group"
  })

  # S'assurer que les politiques IAM sont attachées avant de créer le node group
  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_policy,
  ]
}

# =============================================================================
# Fournisseur OIDC pour IRSA (IAM Roles for Service Accounts)
# =============================================================================
# Permet aux pods Kubernetes d'assumer des rôles IAM spécifiques
# via les Service Accounts, sans utiliser les credentials des nœuds

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-oidc-provider"
  })
}
