# ============================================
# TechShop Product Service - Dockerfile optimisé
# ============================================
# Multi-stage build en 3 étapes :
#   1. Build Maven : compilation du code Java → fat JAR
#   2. Extraction des layers Spring Boot pour le cache Docker
#   3. Runtime JRE minimal avec les layers optimisées
#
# Spring Boot 3.2 supporte le "layered JAR" qui sépare :
#   - les dépendances (rarement modifiées → layer en cache)
#   - le spring-boot-loader (presque jamais modifié)
#   - les dépendances snapshot (parfois modifiées)
#   - le code applicatif (souvent modifié)
# ============================================

# ==============================================
# Étape 1 : Build avec Maven
# ==============================================
# maven:3.9-eclipse-temurin-17 : Maven + JDK Temurin (OpenJDK recommandé)
FROM maven:3.9-eclipse-temurin-17 AS build

WORKDIR /app

# Optimisation du cache : d'abord pom.xml → téléchargement des dépendances
# Cette layer est en cache tant que pom.xml ne change pas
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copier le code source et compiler
COPY src/ ./src/
RUN mvn package -DskipTests -B

# ==============================================
# Étape 2 : Extraction des layers Spring Boot
# ==============================================
FROM eclipse-temurin:17-jre-alpine AS layers

WORKDIR /app
COPY --from=build /app/target/*.jar app.jar

# layertools extrait le JAR en 4 répertoires pour un meilleur cache Docker
RUN java -Djarmode=layertools -jar app.jar extract

# ==============================================
# Étape 3 : Image de production
# ==============================================
FROM eclipse-temurin:17-jre-alpine AS production

# Labels OCI
ARG BUILD_DATE
ARG VERSION=1.0.0
ARG VCS_REF
LABEL org.opencontainers.image.title="techshop-product-service" \
      org.opencontainers.image.description="Service Produits - Catalogue et gestion des produits TechShop" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.source="https://github.com/techshop/techshop" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.vendor="EFREI M1-CSAI" \
      org.opencontainers.image.licenses="MIT"

WORKDIR /app

# Sécurité : utilisateur non-root (adduser car Alpine n'a pas useradd)
RUN addgroup --system --gid 1001 spring && \
    adduser --system --uid 1001 --ingroup spring appuser

# Copier les layers dans l'ordre de fréquence de modification croissante :
# 1. dependencies     → JARs tiers (change rarement)
# 2. spring-boot-loader → chargeur Spring Boot (change quasi jamais)
# 3. snapshot-dependencies → dépendances SNAPSHOT (change parfois)
# 4. application      → code métier (change souvent)
COPY --from=layers /app/dependencies/ ./
COPY --from=layers /app/spring-boot-loader/ ./
COPY --from=layers /app/snapshot-dependencies/ ./
COPY --from=layers /app/application/ ./

RUN chown -R appuser:spring /app

USER appuser

EXPOSE 8002

# Health check via Spring Boot Actuator
# start-period=40s : Spring Boot + JPA + connexion DB → démarrage lent
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8002/actuator/health || exit 1

# JVM dans un conteneur :
# -XX:MaxRAMPercentage=75.0 : limiter la heap à 75% de la RAM du conteneur
# Évite les OOM kills quand Java utilise trop de mémoire
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75.0", "org.springframework.boot.loader.launch.JarLauncher"]
