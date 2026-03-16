# ============================================
# TechShop Order Service - Dockerfile optimisé
# ============================================
# Multi-stage build en 2 étapes :
#   1. Compilation du binaire Go (statiquement lié)
#   2. Image runtime minimale Alpine
#
# Go produit un binaire statique unique quand CGO_ENABLED=0.
# Le binaire n'a besoin d'AUCUNE bibliothèque système pour s'exécuter.
# On pourrait utiliser 'scratch' (image vide, ~0MB) mais Alpine (~7MB)
# permet le debugging et fournit wget pour les health checks.
# ============================================

# ==============================================
# Étape 1 : Compilation du binaire Go
# ==============================================
FROM golang:1.21-alpine AS build

WORKDIR /app

# Optimisation du cache Docker pour Go :
# 1. Copier go.mod et go.sum (si existant)
# 2. Télécharger les dépendances (layer mise en cache)
# 3. Copier le code source et compiler
COPY go.mod go.sum* ./

# go mod download : télécharge les dépendances listées dans go.mod
# go mod tidy : génère/met à jour go.sum si nécessaire
RUN go mod download && go mod tidy

# Copier tout le code source
COPY . .

# Compiler le binaire Go :
# CGO_ENABLED=0 : désactiver les appels C → binaire 100% statique
# GOOS=linux    : compiler pour Linux (même si on build sur Mac/Windows)
# -ldflags="-s -w" : supprimer les symboles de debug
#   -s : supprime la table des symboles (~10% plus petit)
#   -w : supprime les infos DWARF (~15% plus petit)
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o order-service ./cmd/server

# ==============================================
# Étape 2 : Image de production minimale
# ==============================================
FROM alpine:3.19 AS production

# Labels OCI (Open Container Initiative) pour les métadonnées
ARG BUILD_DATE
ARG VERSION=1.0.0
ARG VCS_REF
LABEL org.opencontainers.image.title="techshop-order-service" \
      org.opencontainers.image.description="Service Commandes - Gestion des commandes et communication RabbitMQ" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/techshop/techshop" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="EFREI M1-CSAI" \
      org.opencontainers.image.licenses="MIT"

# ca-certificates : certificats TLS pour connexions HTTPS sortantes
# tzdata : gestion correcte des fuseaux horaires
RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app

# Sécurité : création d'un utilisateur non-root
# Par défaut Docker exécute en root → risque de sécurité
RUN addgroup --system --gid 1001 goapp && \
    adduser --system --uid 1001 --ingroup goapp appuser

# Copier le binaire compilé depuis l'étape de build
COPY --from=build /app/order-service .

RUN chown appuser:goapp /app/order-service

# Basculer vers l'utilisateur non-root
USER appuser

EXPOSE 8003

# Health check intégré (wget est inclus dans Alpine via BusyBox)
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8003/health || exit 1

# Forme exec (JSON) : le processus reçoit directement les signaux Unix
CMD ["./order-service"]
