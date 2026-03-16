#!/bin/bash
# ============================================
# TechShop - Script de push vers le registry
# ============================================
# Prérequis : être authentifié avec le registry
#
# Pour GitHub Container Registry (ghcr.io) :
#   echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
#
# Pour Docker Hub :
#   docker login -u USERNAME
#
# Usage :
#   ./scripts/push.sh              → Push toutes les images
#   ./scripts/push.sh api-gateway  → Push un service spécifique
# ============================================

set -euo pipefail

REGISTRY="${REGISTRY:-ghcr.io}"
NAMESPACE="${NAMESPACE:-techshop}"
VERSION="${VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo 'dev')}"

SERVICES=("api-gateway" "frontend" "user-service" "product-service" "order-service")

# Couleurs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Vérifier l'authentification au registry
check_auth() {
    echo -e "${BLUE}Vérification de l'authentification au registry ${REGISTRY}...${NC}"
    if ! docker info 2>/dev/null | grep -q "Username"; then
        echo -e "${RED}ATTENTION : Vous ne semblez pas authentifié à un registry Docker.${NC}"
        echo "Pour vous authentifier :"
        echo "  - ghcr.io : echo \$GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin"
        echo "  - Docker Hub : docker login -u USERNAME"
        echo ""
        read -p "Continuer quand même ? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

push_service() {
    local service=$1
    local image="${REGISTRY}/${NAMESPACE}/${service}:${VERSION}"
    local latest="${REGISTRY}/${NAMESPACE}/${service}:latest"

    echo -e "${BLUE}=== Push de ${image} ===${NC}"

    # Vérifier que l'image existe localement
    if ! docker image inspect "${image}" > /dev/null 2>&1; then
        echo -e "${RED}Image ${image} non trouvée localement.${NC}"
        echo "Exécutez d'abord : ./scripts/build.sh ${service}"
        return 1
    fi

    docker push "${image}"
    docker push "${latest}"
    echo -e "${GREEN}=== ${service} poussé avec succès ===${NC}"
    echo ""
}

# Exécution
check_auth

if [ $# -gt 0 ]; then
    push_service "$1"
else
    echo "=== Push de toutes les images TechShop ==="
    echo "Registry : ${REGISTRY}/${NAMESPACE}"
    echo "Version  : ${VERSION}"
    echo ""

    for service in "${SERVICES[@]}"; do
        push_service "${service}"
    done
fi

echo -e "${GREEN}=== Toutes les images ont été poussées vers ${REGISTRY}/${NAMESPACE}/ ===${NC}"
