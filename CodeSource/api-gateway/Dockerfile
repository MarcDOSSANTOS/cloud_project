# ============================================
# TechShop API Gateway - Dockerfile optimisé
# ============================================
# Multi-stage build en 2 étapes :
#   1. Installation des dépendances (npm ci)
#   2. Image de production minimale
#
# Même si les 2 étapes utilisent node:alpine, le multi-stage
# élimine le cache npm et les métadonnées de build.
# ============================================

# ==============================================
# Étape 1 : Installation des dépendances
# ==============================================
# node:20-alpine : Node.js LTS sur Alpine Linux (~5MB de base)
FROM node:20-alpine AS dependencies

WORKDIR /app

# Optimisation des layers : copier d'abord UNIQUEMENT package*.json
# Cette layer est en cache tant que les dépendances ne changent pas
COPY package*.json ./

# npm ci : installe les versions EXACTES du lock file
# --only=production : exclut les devDependencies (nodemon, jest)
RUN npm ci --only=production

# ==============================================
# Étape 2 : Image de production
# ==============================================
FROM node:20-alpine AS production

# Labels OCI (métadonnées standard de l'image)
ARG BUILD_DATE
ARG VERSION=1.0.0
ARG VCS_REF
LABEL org.opencontainers.image.title="techshop-api-gateway" \
      org.opencontainers.image.description="API Gateway - Point d'entrée centralisé pour TechShop" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/techshop/techshop" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="EFREI M1-CSAI" \
      org.opencontainers.image.licenses="MIT"

# Mode production : désactive les messages de debug Node.js
ENV NODE_ENV=production

WORKDIR /app

# Sécurité : création d'un utilisateur non-root
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 --ingroup nodejs appuser

# Copier les dépendances depuis l'étape précédente
# --from=dependencies récupère les fichiers sans le cache npm
COPY --from=dependencies /app/node_modules ./node_modules

# Copier le code source
COPY package*.json ./
COPY src/ ./src/

RUN chown -R appuser:nodejs /app

USER appuser

EXPOSE 3000

# Health check (wget est inclus dans Alpine via BusyBox, pas besoin de curl)
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api || exit 1

CMD ["node", "src/server.js"]
