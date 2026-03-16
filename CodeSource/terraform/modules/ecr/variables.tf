# =============================================================================
# Variables du module ECR
# =============================================================================

variable "project_name" {
  description = "Nom du projet. Utilisé comme préfixe pour les noms de dépôts ECR (ex: techshop/api-gateway)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.project_name))
    error_message = "Le nom du projet doit commencer par une lettre minuscule et ne contenir que des lettres minuscules, chiffres et tirets."
  }
}

variable "services" {
  description = "Liste des noms de microservices pour lesquels créer un dépôt ECR. Un dépôt sera créé par service."
  type        = list(string)
  default = [
    "api-gateway",
    "frontend",
    "user-service",
    "product-service",
    "order-service"
  ]

  validation {
    condition     = length(var.services) > 0
    error_message = "La liste des services ne peut pas être vide."
  }
}

variable "tags" {
  description = "Tags additionnels à appliquer à toutes les ressources du module ECR."
  type        = map(string)
  default     = {}
}
