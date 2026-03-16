# =============================================================================
# Module VPC - TechShop E-commerce
# =============================================================================
# Ce module crée un VPC configuré pour héberger un cluster EKS avec :
# - Sous-réseaux publics et privés répartis sur 3 zones de disponibilité
# - Internet Gateway pour l'accès sortant des sous-réseaux publics
# - NAT Gateway(s) pour l'accès sortant des sous-réseaux privés
# - Tables de routage associées
# - Tags requis par EKS pour la découverte automatique des sous-réseaux
# =============================================================================

# --- Sources de données ---

# Récupération des zones de disponibilité de la région courante
data "aws_availability_zones" "available" {
  state = "available"
}

# --- Variables locales ---

locals {
  # Sous-réseaux publics : un par zone de disponibilité
  public_subnets = {
    "public-1" = {
      cidr = "10.0.1.0/24"
      az   = data.aws_availability_zones.available.names[0]
    }
    "public-2" = {
      cidr = "10.0.2.0/24"
      az   = data.aws_availability_zones.available.names[1]
    }
    "public-3" = {
      cidr = "10.0.3.0/24"
      az   = data.aws_availability_zones.available.names[2]
    }
  }

  # Sous-réseaux privés : un par zone de disponibilité
  private_subnets = {
    "private-1" = {
      cidr = "10.0.10.0/24"
      az   = data.aws_availability_zones.available.names[0]
    }
    "private-2" = {
      cidr = "10.0.20.0/24"
      az   = data.aws_availability_zones.available.names[1]
    }
    "private-3" = {
      cidr = "10.0.30.0/24"
      az   = data.aws_availability_zones.available.names[2]
    }
  }

  # Tags communs appliqués à toutes les ressources du module
  common_tags = merge(var.tags, {
    Module      = "vpc"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# =============================================================================
# VPC Principal
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  # Activation du DNS - requis pour EKS et les endpoints VPC
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-vpc"
    # Tag requis pour qu'EKS découvre automatiquement ce VPC
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# =============================================================================
# Sous-réseaux publics
# =============================================================================
# Les sous-réseaux publics hébergent les load balancers et les NAT Gateways.
# Chaque instance reçoit automatiquement une IP publique.

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-${each.key}"
    # Tags requis par EKS pour les load balancers publics (ALB/NLB)
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  })
}

# =============================================================================
# Sous-réseaux privés
# =============================================================================
# Les sous-réseaux privés hébergent les nœuds EKS et les bases de données.
# Pas d'IP publique - accès Internet via NAT Gateway uniquement.

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-${each.key}"
    # Tags requis par EKS pour les load balancers internes
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  })
}

# =============================================================================
# Internet Gateway
# =============================================================================
# Permet aux sous-réseaux publics d'accéder à Internet

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-igw"
  })
}

# =============================================================================
# Elastic IP pour NAT Gateway(s)
# =============================================================================
# En mode single_nat_gateway (dev) : 1 EIP
# En mode multi NAT (prod) : 1 EIP par zone de disponibilité

resource "aws_eip" "nat" {
  # Si single_nat_gateway est activé, on crée 1 seul EIP, sinon 3 (un par AZ)
  count  = var.single_nat_gateway ? 1 : 3
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = var.single_nat_gateway ? "${var.cluster_name}-nat-eip" : "${var.cluster_name}-nat-eip-${count.index + 1}"
  })

  # L'IGW doit exister avant de créer les EIP
  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# NAT Gateway(s)
# =============================================================================
# En dev : un seul NAT Gateway (économie de coûts)
# En prod : un NAT Gateway par AZ (haute disponibilité)

resource "aws_nat_gateway" "main" {
  count = var.single_nat_gateway ? 1 : 3

  allocation_id = aws_eip.nat[count.index].id
  # Placement dans le sous-réseau public correspondant
  subnet_id = values(aws_subnet.public)[count.index].id

  tags = merge(local.common_tags, {
    Name = var.single_nat_gateway ? "${var.cluster_name}-nat" : "${var.cluster_name}-nat-${count.index + 1}"
  })

  # L'IGW doit être fonctionnel avant le NAT Gateway
  depends_on = [aws_internet_gateway.main]
}

# =============================================================================
# Table de routage publique
# =============================================================================
# Route par défaut vers l'Internet Gateway - partagée par tous les sous-réseaux publics

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Route par défaut : tout le trafic non local va vers l'IGW
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-public-rt"
  })
}

# Association de chaque sous-réseau public à la table de routage publique
resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# =============================================================================
# Tables de routage privées
# =============================================================================
# En mode single NAT : une seule table de routage pour tous les sous-réseaux privés
# En mode multi NAT : une table par AZ, chacune pointant vers son NAT Gateway

resource "aws_route_table" "private" {
  count  = var.single_nat_gateway ? 1 : 3
  vpc_id = aws_vpc.main.id

  # Route par défaut : tout le trafic non local va vers le NAT Gateway
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(local.common_tags, {
    Name = var.single_nat_gateway ? "${var.cluster_name}-private-rt" : "${var.cluster_name}-private-rt-${count.index + 1}"
  })
}

# Association de chaque sous-réseau privé à sa table de routage
resource "aws_route_table_association" "private" {
  count = 3

  subnet_id = values(aws_subnet.private)[count.index].id
  # En mode single NAT, tous les sous-réseaux utilisent la même table de routage
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}
