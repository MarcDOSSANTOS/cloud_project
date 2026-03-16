# ============================================
# TechShop Frontend - Dockerfile optimisé
# ============================================
# Multi-stage build en 2 étapes :
#   1. Compilation de l'application React (Node.js)
#   2. Serveur web de production (Nginx)
#
# Le résultat final ne contient QUE les fichiers statiques HTML/JS/CSS
# et Nginx — ni Node.js ni les sources React.
# ============================================

# ==============================================
# Étape 1 : Build de l'application React
# ==============================================
FROM node:20-alpine AS build

WORKDIR /app

# Optimisation du cache : dépendances d'abord, code source ensuite
COPY package*.json ./
RUN npm ci

# Copier explicitement les répertoires source (plus sûr que COPY . .)
COPY public/ ./public/
COPY src/ ./src/

# CI=true : mode non-interactif, traite les warnings comme des erreurs
RUN CI=true npm run build

# ==============================================
# Étape 2 : Serveur Nginx de production
# ==============================================
# nginx:1.25-alpine : image très légère (~40MB) pour servir les fichiers statiques
# Version fixée pour la reproductibilité (éviter latest qui est flottant)
FROM nginx:1.25-alpine AS production

# Labels OCI
ARG BUILD_DATE
ARG VERSION=1.0.0
ARG VCS_REF
LABEL org.opencontainers.image.title="techshop-frontend" \
      org.opencontainers.image.description="Frontend React - Interface utilisateur TechShop" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/techshop/techshop" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="EFREI M1-CSAI" \
      org.opencontainers.image.licenses="MIT"

# Copier les fichiers statiques compilés depuis l'étape build
COPY --from=build /app/build /usr/share/nginx/html

# Copier la configuration Nginx personnalisée (proxy API, gzip, SPA fallback)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Sécurité : configurer Nginx pour s'exécuter en non-root
# L'utilisateur 'nginx' existe déjà dans l'image officielle
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

USER nginx

EXPOSE 80

# Health check sur l'endpoint /health défini dans nginx.conf
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:80/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
