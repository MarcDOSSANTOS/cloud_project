# =============================================================================
# Module ECR - TechShop E-commerce
# =============================================================================
# Ce module crée les dépôts ECR (Elastic Container Registry) pour stocker
# les images Docker de chaque microservice :
# - Un dépôt par service avec des tags immuables
# - Scan de sécurité automatique à chaque push
# - Politique de cycle de vie pour limiter l'espace de stockage
# =============================================================================

# --- Variables locales ---

locals {
  # Tags communs appliqués à toutes les ressources du module
  common_tags = merge(var.tags, {
    Module    = "ecr"
    ManagedBy = "terraform"
  })
}

# =============================================================================
# Dépôts ECR
# =============================================================================
# Un dépôt est créé pour chaque service défini dans la variable 'services'

resource "aws_ecr_repository" "services" {
  for_each = toset(var.services)

  name = "${var.project_name}/${each.value}"

  # Tags immuables : une fois poussée, une image avec un tag donné ne peut
  # pas être écrasée. Cela garantit la traçabilité des déploiements.
  image_tag_mutability = "IMMUTABLE"

  # Scan de sécurité automatique à chaque push d'image
  # Détecte les vulnérabilités connues (CVE) dans les couches de l'image
  image_scanning_configuration {
    scan_on_push = true
  }

  # Protection contre la suppression accidentelle
  # Mettre à true en production pour éviter la perte d'images
  force_delete = false

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}/${each.value}"
    Service = each.value
  })
}

# =============================================================================
# Politique de cycle de vie des images
# =============================================================================
# Gestion automatique du nettoyage des images pour maîtriser les coûts :
# - Conservation des 10 dernières images taguées
# - Suppression des images non taguées après 7 jours

resource "aws_ecr_lifecycle_policy" "services" {
  for_each = aws_ecr_repository.services

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        # Règle 1 : Supprimer les images non taguées après 7 jours
        # Les images non taguées sont généralement des artefacts de build intermédiaires
        rulePriority = 1
        description  = "Supprimer les images non taguees apres 7 jours"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = {
          type = "expire"
        }
      },
      {
        # Règle 2 : Conserver uniquement les 10 dernières images taguées
        # Cela permet de faire un rollback sur les 10 dernières versions
        rulePriority = 2
        description  = "Conserver les 10 dernieres images taguees"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "latest", "release", "build"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
