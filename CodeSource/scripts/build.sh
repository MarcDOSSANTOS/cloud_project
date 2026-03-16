#!/bin/bash
# ============================================
# TechShop - Script de build des images Docker
# ============================================
# Usage :
#   ./scripts/build.sh              → Build toutes les images
#   ./scripts/build.sh api-gateway  → Build un service spécifique
#
# Variables d'environnement optionnelles :
#   REGISTRY   → Registry Docker (défaut: ghcr.io)
#   NAMESPACE  → Namespace du registry (défaut: techshop)
#   VERSION    → Tag de version (défaut: git describe ou 'dev')
# ============================================

set -euo pipefail

# Configuration
REGISTRY="${REGISTRY:-ghcr.io}"
NAMESPACE="${NAMESPACE:-techshop}"
VERSION="${VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo 'dev')}"
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
VCS_REF=$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')

# Liste des services à construire
SERVICES=("api-gateway" "frontend" "user-service" "product-service" "order-service")

# Couleurs pour l'affichage
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

build_service() {
    local service=$1
    local image="${REGISTRY}/${NAMESPACE}/${service}:${VERSION}"
    local latest="${REGISTRY}/${NAMESPACE}/${service}:latest"

    echo -e "${BLUE}=== Construction de ${image} ===${NC}"

    docker build \
        --build-arg BUILD_DATE="${BUILD_DATE}" \
        --build-arg VERSION="${VERSION}" \
        --build-arg VCS_REF="${VCS_REF}" \
        -t "${image}" \
        -t "${latest}" \
        "./${service}"

    echo -e "${GREEN}=== ${service} construit avec succès ===${NC}"
    docker images "${image}"
    echo ""
}

# Build un service spécifique ou tous
if [ $# -gt 0 ]; then
    build_service "$1"
else
    echo "=== Build de toutes les images TechShop ==="
    echo "Registry : ${REGISTRY}/${NAMESPACE}"
    echo "Version  : ${VERSION}"
    echo "Date     : ${BUILD_DATE}"
    echo "Commit   : ${VCS_REF}"
    echo ""

    for service in "${SERVICES[@]}"; do
        build_service "${service}"
    done
fi

echo ""
echo -e "${GREEN}=== Résumé des images construites ===${NC}"
docker images "${REGISTRY}/${NAMESPACE}/*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
