# ============================================
# TechShop User Service - Dockerfile optimisé
# ============================================
# Multi-stage build en 2 étapes :
#   1. Installation et compilation des dépendances Python
#   2. Image de production minimale avec seulement le runtime
#
# Python nécessite parfois des compilateurs C pour certains packages
# (psycopg2, bcrypt). Le multi-stage exclut ces outils de l'image finale.
#
# Note : on utilise python:3.12-slim (Debian) et non Alpine car Python
# sur Alpine nécessite musl au lieu de glibc, causant des problèmes
# de compilation avec psycopg2 et bcrypt.
# ============================================

# ==============================================
# Étape 1 : Installation des dépendances
# ==============================================
FROM python:3.12-slim AS builder

WORKDIR /app

# gcc et libpq-dev : nécessaires pour compiler psycopg2
# Ces paquets ne seront PAS dans l'image finale
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq-dev && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# --prefix=/install : isole les dépendances pour les copier proprement
# --no-cache-dir : évite de stocker le cache pip dans l'image
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ==============================================
# Étape 2 : Image de production
# ==============================================
FROM python:3.12-slim AS production

# Labels OCI
ARG BUILD_DATE
ARG VERSION=1.0.0
ARG VCS_REF
LABEL org.opencontainers.image.title="techshop-user-service" \
      org.opencontainers.image.description="Service Utilisateurs - Gestion des comptes et authentification JWT" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/techshop/techshop" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="EFREI M1-CSAI" \
      org.opencontainers.image.licenses="MIT"

# libpq5 : bibliothèque runtime PostgreSQL (pas les headers de dev)
# curl : nécessaire pour les health checks (Debian slim n'a pas wget)
RUN apt-get update && \
    apt-get install -y --no-install-recommends libpq5 curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copier les dépendances Python compilées depuis le builder
COPY --from=builder /install /usr/local

# Sécurité : utilisateur non-root
RUN groupadd --system --gid 1001 appgroup && \
    useradd --system --uid 1001 --gid appgroup --create-home appuser

COPY app/ ./app/

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8001

# Health check : FastAPI expose /health → {"status": "up"}
# start-period=20s car le service crée les tables DB au démarrage
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -f http://localhost:8001/health || exit 1

# Démarrer uvicorn (serveur ASGI pour FastAPI)
# --host 0.0.0.0 : écouter sur toutes les interfaces (obligatoire dans Docker)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8001"]
