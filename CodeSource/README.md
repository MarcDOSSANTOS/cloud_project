# 🛒 TechShop - Application E-Commerce Microservices

> Projet de synthèse - Cloud Computing - EFREI M1-CSAI 2025-2026

## 📋 Description

TechShop est une application e-commerce construite selon une architecture microservices. 
Ce projet sert de base pour démontrer vos compétences en déploiement cloud-native.

**⚠️ Votre travail consiste à conteneuriser, orchestrer et déployer cette application, 
et non à la développer.**

## 🏗️ Architecture

```
┌──────────────┐
│   Frontend   │ (React / Nginx - port 80)
│              │
└──────┬───────┘
       │
┌──────▼───────┐
│  API Gateway │ (Node.js / Express - port 3000)
│              │
└──┬───┬───┬───┘
   │   │   │
   │   │   └──────────────────┐
   │   │                      │
┌──▼───┴──┐  ┌────────────┐  ┌▼───────────┐
│  User   │  │  Product   │  │   Order    │
│ Service │  │  Service   │  │  Service   │
│ Python  │  │ Java/Spring│  │    Go      │
│ :8001   │  │   :8002    │  │   :8003    │
└────┬────┘  └─────┬──────┘  └──┬────┬────┘
     │             │            │    │
     └──────┬──────┘            │    │
            │                   │    │
     ┌──────▼──────┐    ┌──────▼┐  ┌▼─────────┐
     │ PostgreSQL  │    │ Redis │  │ RabbitMQ │
     │   :5432     │    │ :6379 │  │  :5672   │
     └─────────────┘    └───────┘  └──────────┘
```

## 🛠️ Services

| Service | Technologie | Port | Description |
|---------|------------|------|-------------|
| Frontend | React / Nginx | 80 | Interface utilisateur |
| API Gateway | Node.js / Express | 3000 | Routage, auth, rate limiting |
| User Service | Python / FastAPI | 8001 | Gestion utilisateurs, JWT |
| Product Service | Java / Spring Boot | 8002 | Catalogue produits, cache Redis |
| Order Service | Go / Gin | 8003 | Gestion commandes, events RabbitMQ |
| Database | PostgreSQL 16 | 5432 | Base de données principale |
| Cache | Redis 7 | 6379 | Cache en mémoire |
| Message Queue | RabbitMQ 3.12 | 5672 | Communication asynchrone |

## 📁 Structure du Projet

```
techshop-source/
├── frontend/                  # Application React
│   ├── public/
│   ├── src/
│   │   ├── pages/            # Composants de pages
│   │   ├── services/         # Client API (axios)
│   │   ├── App.js
│   │   └── index.js
│   ├── nginx.conf            # Config Nginx pour production
│   ├── Dockerfile
│   └── package.json
│
├── api-gateway/               # API Gateway Node.js
│   ├── src/
│   │   ├── routes/           # Proxy routes vers les services
│   │   ├── middleware/       # Auth JWT, rate limiting
│   │   └── server.js
│   ├── Dockerfile
│   └── package.json
│
├── user-service/              # Service Utilisateurs Python
│   ├── app/
│   │   ├── routes/           # Endpoints FastAPI
│   │   ├── models/           # SQLAlchemy + Pydantic
│   │   └── main.py
│   ├── Dockerfile
│   └── requirements.txt
│
├── product-service/           # Service Produits Java
│   ├── src/main/java/com/techshop/product/
│   │   ├── controller/       # REST Controller
│   │   ├── model/            # JPA Entity
│   │   ├── repository/       # Spring Data JPA
│   │   ├── service/          # Logique métier
│   │   └── config/           # DataInitializer
│   ├── src/main/resources/
│   │   └── application.properties
│   ├── Dockerfile
│   └── pom.xml
│
├── order-service/             # Service Commandes Go
│   ├── cmd/server/           # Point d'entrée
│   │   └── main.go
│   ├── internal/
│   │   ├── handlers/         # HTTP Handlers
│   │   ├── models/           # Structures de données
│   │   ├── services/         # Logique métier
│   │   └── middleware/       # CORS, logging
│   ├── Dockerfile
│   └── go.mod
│
├── database/
│   └── init/                 # Scripts SQL d'initialisation
│       └── 01-init.sql
│
├── docker-compose.yml         # Orchestration locale
├── .env.example              # Variables d'environnement
└── README.md                 # Ce fichier
```

## 🚀 Démarrage Rapide (Développement Local)

### Prérequis

- Docker 24+ et Docker Compose v2
- Git

### Lancement

```bash
# 1. Cloner le repository
git clone <url-du-repo>
cd techshop-source

# 2. Copier le fichier d'environnement
cp .env.example .env

# 3. Construire et démarrer tous les services
docker compose up -d --build

# 4. Vérifier le statut
docker compose ps

# 5. Voir les logs
docker compose logs -f
```

### Accès

| Service | URL |
|---------|-----|
| Frontend | http://localhost |
| API Gateway | http://localhost:3000/api |
| User Service | http://localhost:8001 |
| Product Service | http://localhost:8002/api/products |
| Order Service | http://localhost:8003/health |
| RabbitMQ Management | http://localhost:15672 (guest/guest) |

### Comptes de test

| Email | Mot de passe |
|-------|-------------|
| alice@techshop.com | password123 |
| bob@techshop.com | password123 |

## 🔑 API Endpoints

### Users
- `POST /api/users/register` - Inscription
- `POST /api/users/login` - Connexion
- `GET /api/users/profile` - Profil (auth requise)

### Products
- `GET /api/products` - Liste des produits
- `GET /api/products/:id` - Détail produit
- `GET /api/products/category/:cat` - Par catégorie

### Orders (authentification requise)
- `POST /api/orders` - Créer une commande
- `GET /api/orders` - Mes commandes
- `GET /api/orders/:id` - Détail commande

### Health & Monitoring
- `GET /api/health` - Health check agrégé
- `GET /metrics` - Métriques Prometheus

## ⚙️ Variables d'Environnement

Voir `.env.example` pour la liste complète des variables configurables.

## 📝 Notes pour les Étudiants

Les Dockerfiles fournis sont fonctionnels mais **basiques**. Dans le cadre du projet, vous devez :

1. **Optimiser les Dockerfiles** (multi-stage builds, utilisateur non-root, taille d'image)
2. **Écrire les manifestes Kubernetes** (Deployments, Services, ConfigMaps, etc.)
3. **Configurer Terraform** pour provisionner l'infrastructure
4. **Mettre en place CI/CD** avec GitHub Actions ou GitLab CI
5. **Ajouter le monitoring** (Prometheus/Grafana)

---

**EFREI M1-CSAI - Cloud Computing - 2025-2026**
**Stéphane Larcher**
