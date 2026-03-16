# Phase 4 : CI/CD et Observabilité - Documentation Technique

## 1. Vue d'ensemble du pipeline CI/CD

### Architecture du pipeline

```
 ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
 │   Push    │───▶│   Lint   │───▶│  Tests   │───▶│  Build   │───▶│  Scan    │
 │  GitHub   │    │  Code    │    │ unitaires│    │  Docker  │    │  Trivy   │
 └──────────┘    └──────────┘    └──────────┘    └──────────┘    └────┬─────┘
                                                                      │
                                                              ┌───────▼──────┐
                                                              │  Push GHCR   │
                                                              │  (tag: sha)  │
                                                              └───────┬──────┘
                                                                      │
           ┌──────────┐    ┌──────────┐    ┌──────────┐              │
           │  Notify  │◄───│ Rollout  │◄───│  Deploy  │◄─────────────┘
           │  Slack   │    │  Status  │    │   K8s    │   (merge main uniquement)
           └──────────┘    └──────────┘    └──────────┘
```

### Fichiers de configuration

```
.github/
  workflows/
    ci.yml              # Pipeline CI : lint → test → build → scan → push
    cd.yml              # Pipeline CD : deploy vers K8s (déclenché après CI)
monitoring/
  namespace.yaml        # Namespace monitoring
  servicemonitor.yaml   # Config scraping Prometheus pour TechShop
  alerts.yaml           # Règles d'alerte PrometheusRule
  grafana-dashboard.json # Dashboard Grafana importable
  loki-values.yaml      # Valeurs Helm pour Loki + Promtail
docs/
  cicd-observability.md # Ce document
```

---

## 2. Pipeline CI — Intégration Continue

### Fichier : `.github/workflows/ci.yml`

### Déclenchement

| Événement | Branches | Comportement |
|-----------|----------|-------------|
| `push` | `main`, `develop` | Build + test + scan + push images |
| `pull_request` | `main` | Build + test + scan (pas de push) |

### Jobs et étapes

#### Job 1 : Tests unitaires (en parallèle, par service)

| Service | Runtime | Commande de test | Framework |
|---------|---------|------------------|-----------|
| api-gateway | Node.js 20 | `npm ci && npm test` | Jest |
| frontend | Node.js 20 | `npm ci && CI=true npm run build` | React Scripts |
| user-service | Python 3.12 | `pip install -r requirements.txt && pytest` | pytest |
| product-service | Java 17 | `mvn test -B` | JUnit 5 (Spring Boot Test) |
| order-service | Go 1.21 | `go test ./...` | Go testing |

**Optimisation** : chaque service est testé dans un job séparé. Les 5 jobs s'exécutent en parallèle grâce à la `strategy.matrix` de GitHub Actions.

#### Job 2 : Build des images Docker

- **Dépendance** : attend que tous les jobs de test passent (`needs: [test-*]`)
- **Stratégie** : `matrix` sur les 5 services pour paralléliser les builds
- **Cache** : utilise `docker/build-push-action` avec le cache GitHub Actions
- **Tags** :
  - `ghcr.io/<owner>/<service>:<sha-du-commit>` (immutable, traçable)
  - `ghcr.io/<owner>/<service>:latest` (rolling, pour le développement)

#### Job 3 : Scan de sécurité (Trivy)

- **Outil** : [Trivy](https://github.com/aquasecurity/trivy) (scanner open-source d'Aqua Security)
- **Cibles** : chaque image Docker buildée
- **Sévérités bloquantes** : `CRITICAL` et `HIGH`
- **Comportement** :
  - Si vulnérabilité CRITICAL → le pipeline **échoue** (`exit-code: 1`)
  - Si vulnérabilité HIGH → **warning** dans les logs
  - Les résultats sont uploadés au format SARIF dans l'onglet GitHub Security

#### Job 4 : Push vers le registry (uniquement sur `main`)

- **Condition** : `if: github.ref == 'refs/heads/main' && github.event_name == 'push'`
- **Registry** : GitHub Container Registry (ghcr.io)
- **Authentification** : `GITHUB_TOKEN` (automatique dans GitHub Actions)

### Secrets GitHub requis

| Secret | Description | Où le configurer |
|--------|-------------|------------------|
| `GITHUB_TOKEN` | Automatique — push vers GHCR | Fourni par GitHub |
| `AWS_ACCESS_KEY_ID` | Accès AWS pour le déploiement | Settings → Secrets → Actions |
| `AWS_SECRET_ACCESS_KEY` | Clé secrète AWS | Settings → Secrets → Actions |
| `KUBE_CONFIG` | kubeconfig base64 pour `kubectl` | Settings → Secrets → Actions |
| `SLACK_WEBHOOK_URL` | Notification Slack (optionnel) | Settings → Secrets → Actions |

---

## 3. Pipeline CD — Déploiement Continu

### Fichier : `.github/workflows/cd.yml`

### Déclenchement

- Automatique après succès du pipeline CI sur `main`
- Déclenchement manuel possible via `workflow_dispatch` (bouton GitHub)

### Stratégie de déploiement : Rolling Update

```
                    Temps ───────────────────────────────▶

Pod v1.0  ████████████████████░░░░░░░░░░░░  (terminé progressivement)
Pod v1.0  ████████████████████████████░░░░  (terminé après le premier)
Pod v1.1  ░░░░░░░░░░░░████████████████████  (démarré pendant l'arrêt)
Pod v1.1  ░░░░░░░░░░░░░░░░████████████████  (démarré en dernier)

            ▲ Toujours au moins 1 pod disponible = zéro downtime
```

Configuration dans les Deployments Kubernetes :

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0     # Jamais de pod indisponible
      maxSurge: 1           # 1 pod supplémentaire pendant le rollout
```

### Étapes du déploiement

| Étape | Commande | Description |
|-------|----------|-------------|
| 1. Configure AWS | `aws eks update-kubeconfig` | Connecter kubectl au cluster EKS |
| 2. Update image | `kubectl set image deployment/<svc>` | Déclencher le rolling update |
| 3. Wait rollout | `kubectl rollout status` | Attendre que tous les pods soient ready |
| 4. Smoke test | `curl /health` via le LoadBalancer | Vérifier que l'app répond |
| 5. Notify | Slack webhook | Notifier l'équipe du résultat |

### Rollback automatique

Si `kubectl rollout status` échoue (timeout de 5 minutes) :

```bash
# Rollback automatique vers la version précédente
kubectl rollout undo deployment/<service> -n techshop
```

### Rollback manuel

```bash
# Voir l'historique des déploiements
kubectl -n techshop rollout history deployment/api-gateway

# Revenir à la version précédente
kubectl -n techshop rollout undo deployment/api-gateway

# Revenir à une révision spécifique
kubectl -n techshop rollout undo deployment/api-gateway --to-revision=3
```

---

## 4. Stack de monitoring : Prometheus + Grafana

### Architecture

```
┌──────────────────────────────────────────────────────┐
│                   Cluster Kubernetes                  │
│                                                       │
│  ┌─────────────┐    scrape /metrics    ┌───────────┐ │
│  │ api-gateway  │ ◄──────────────────  │           │ │
│  │ (prom-client)│                      │           │ │
│  ├─────────────┤                      │           │ │
│  │ user-service │ ◄──────────────────  │Prometheus │ │
│  │ (prometheus- │                      │           │ │
│  │  client)     │                      │  Stockage │ │
│  ├─────────────┤                      │  TSDB     │ │
│  │ product-svc  │ ◄──────────────────  │  15 jours │ │
│  │ (micrometer) │                      │           │ │
│  ├─────────────┤                      │           │ │
│  │ order-svc    │ ◄──────────────────  │           │ │
│  │ (prom client)│                      └─────┬─────┘ │
│  └─────────────┘                            │       │
│                                              │ query │
│  ┌─────────────┐    push alerts    ┌────────▼──────┐│
│  │AlertManager  │ ◄────────────── │   Grafana      ││
│  │              │                  │   Dashboards   ││
│  │  → Slack     │                  │   + Alertes    ││
│  │  → Email     │                  │   + Explore    ││
│  └─────────────┘                  └────────────────┘│
└──────────────────────────────────────────────────────┘
```

### Installation via Helm

```bash
# Ajouter les repos Helm nécessaires
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Installer kube-prometheus-stack (Prometheus + Grafana + AlertManager + Node Exporter)
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin123 \
  --set prometheus.prometheusSpec.retention=15d \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.service.type=LoadBalancer
```

Ce Helm chart installe automatiquement :

| Composant | Rôle | Port |
|-----------|------|------|
| **Prometheus** | Collecte et stocke les métriques (TSDB) | 9090 |
| **Grafana** | Visualisation (dashboards, graphiques) | 3000 |
| **AlertManager** | Routage et envoi des alertes | 9093 |
| **Node Exporter** | Métriques des nœuds (CPU, RAM, disque) | 9100 |
| **kube-state-metrics** | Métriques des objets K8s (pods, deployments) | 8080 |

### Endpoints `/metrics` existants dans TechShop

| Service | Bibliothèque | Endpoint | Métriques exposées |
|---------|-------------|----------|-------------------|
| api-gateway | `prom-client` (Node.js) | `GET /metrics` | `http_requests_total`, `http_request_duration_seconds`, `nodejs_heap_size_bytes` |
| user-service | `prometheus-client` (Python) | `GET /metrics` | `http_requests_total`, `http_request_duration_seconds`, `python_gc_collections_total` |
| product-service | Micrometer (Spring Boot) | `GET /actuator/prometheus` | `http_server_requests_seconds`, `jvm_memory_used_bytes`, `hikaricp_connections_active` |
| order-service | `client_golang` (Go) | `GET /metrics` | Endpoint placeholder (à enrichir) |

### ServiceMonitor — Dire à Prometheus quoi scraper

```yaml
# monitoring/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: techshop-services
  namespace: techshop
  labels:
    release: monitoring       # IMPORTANT : doit matcher le label du Helm release
spec:
  selector:
    matchLabels:
      app.kubernetes.io/part-of: techshop
  namespaceSelector:
    matchNames:
      - techshop
  endpoints:
    # Endpoint standard pour api-gateway, user-service, order-service
    - port: http
      path: /metrics
      interval: 30s
---
# ServiceMonitor séparé pour product-service (endpoint différent)
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: techshop-product-service
  namespace: techshop
  labels:
    release: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: product-service
  namespaceSelector:
    matchNames:
      - techshop
  endpoints:
    - port: http
      path: /actuator/prometheus
      interval: 30s
```

### Dashboard Grafana — Métriques clés

Le dashboard est organisé en 4 lignes :

#### Ligne 1 : Vue d'ensemble (4 panels)

| Panel | Requête PromQL | Type |
|-------|---------------|------|
| Requêtes/sec (total) | `sum(rate(http_requests_total{namespace="techshop"}[5m]))` | Stat |
| Latence P95 (global) | `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace="techshop"}[5m])) by (le))` | Stat |
| Taux d'erreur | `sum(rate(http_requests_total{namespace="techshop",status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="techshop"}[5m])) * 100` | Gauge (rouge > 5%) |
| Pods healthy | `sum(kube_deployment_status_replicas_ready{namespace="techshop"}) / sum(kube_deployment_status_replicas{namespace="techshop"}) * 100` | Gauge |

#### Ligne 2 : Par service (5 panels time-series)

| Panel | Requête PromQL |
|-------|---------------|
| Requêtes/sec par service | `sum by (service) (rate(http_requests_total{namespace="techshop"}[5m]))` |
| Latence P50/P95/P99 | `histogram_quantile(0.50\|0.95\|0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))` |
| Erreurs par service | `sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))` |

#### Ligne 3 : Ressources (4 panels)

| Panel | Requête PromQL |
|-------|---------------|
| CPU par pod | `sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="techshop"}[5m]))` |
| Mémoire par pod | `sum by (pod) (container_memory_working_set_bytes{namespace="techshop"})` |
| JVM Heap (product-service) | `jvm_memory_used_bytes{area="heap", namespace="techshop"}` |
| HPA réplicas | `kube_horizontalpodautoscaler_status_current_replicas{namespace="techshop"}` |

#### Ligne 4 : Infrastructure (4 panels)

| Panel | Requête PromQL |
|-------|---------------|
| PostgreSQL connexions | `pg_stat_activity_count` (si postgres-exporter installé) |
| Redis mémoire | `redis_memory_used_bytes` (si redis-exporter installé) |
| RabbitMQ messages en file | `rabbitmq_queue_messages_ready` (si rabbitmq-exporter) |
| Espace disque PVC | `kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes * 100` |

### Accéder à Grafana

```bash
# Option 1 : Port-forward (développement)
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# Option 2 : LoadBalancer (si configuré)
kubectl -n monitoring get svc monitoring-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Identifiants par défaut
# Utilisateur : admin
# Mot de passe : admin123 (défini dans le Helm values)
```

---

## 5. Règles d'alerte

### Fichier : `monitoring/alerts.yaml`

Les alertes sont organisées par sévérité :

### Alertes critiques (action immédiate requise)

| Alerte | Condition | Durée | Description |
|--------|-----------|-------|-------------|
| **HighErrorRate** | Taux d'erreur 5xx > 10% | 5 min | Un service retourne trop d'erreurs |
| **ServiceDown** | 0 pods ready | 2 min | Un service est complètement down |
| **DatabaseDown** | PostgreSQL unreachable | 1 min | La base de données ne répond plus |

### Alertes warning (investigation nécessaire)

| Alerte | Condition | Durée | Description |
|--------|-----------|-------|-------------|
| **PodCrashLooping** | Redémarrages > 0 en 15 min | 5 min | Un pod redémarre en boucle |
| **HighMemoryUsage** | Mémoire > 85% de la limite | 5 min | Risque d'OOM kill |
| **HighCPUUsage** | CPU > 80% pendant 10 min | 10 min | Service potentiellement saturé |
| **PVCAlmostFull** | Disque PVC > 80% | 15 min | Espace disque bientôt épuisé |
| **HighLatency** | P95 > 2 secondes | 5 min | Temps de réponse dégradé |
| **HPAMaxedOut** | Réplicas = max | 15 min | Le HPA ne peut plus scaler |

### Configuration de la notification (AlertManager)

```yaml
# Dans le Helm values ou via ConfigMap
alertmanager:
  config:
    route:
      receiver: 'slack-notifications'
      group_by: ['alertname', 'namespace']
      group_wait: 30s            # Attendre 30s pour grouper les alertes
      group_interval: 5m         # Intervalle entre les groupes
      repeat_interval: 4h        # Re-notifier toutes les 4h si non résolu
      routes:
        - match:
            severity: critical
          receiver: 'slack-critical'
          repeat_interval: 1h    # Plus fréquent pour les critiques
    receivers:
      - name: 'slack-notifications'
        slack_configs:
          - api_url: '<SLACK_WEBHOOK_URL>'
            channel: '#techshop-alerts'
            title: '{{ .GroupLabels.alertname }}'
            text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
      - name: 'slack-critical'
        slack_configs:
          - api_url: '<SLACK_WEBHOOK_URL>'
            channel: '#techshop-critical'
            title: '🔴 CRITICAL: {{ .GroupLabels.alertname }}'
            text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
```

---

## 6. Centralisation des logs : Loki + Promtail

### Architecture

```
┌──────────────────────────────────────────────────┐
│              Cluster Kubernetes                    │
│                                                    │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐           │
│  │  Pod A   │  │  Pod B   │  │  Pod C   │          │
│  │ stdout →─┤  │ stdout →─┤  │ stdout →─┤          │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘          │
│       │              │              │                │
│       ▼              ▼              ▼                │
│  ┌──────────────────────────────────────┐           │
│  │           Promtail (DaemonSet)        │          │
│  │  - 1 instance par nœud               │          │
│  │  - Collecte stdout/stderr de TOUS     │          │
│  │    les conteneurs via /var/log/pods   │          │
│  │  - Ajoute les labels K8s (namespace,  │          │
│  │    pod, container) automatiquement    │          │
│  └──────────────────┬───────────────────┘           │
│                     │ push                          │
│                     ▼                               │
│  ┌──────────────────────────────┐                   │
│  │           Loki                │                  │
│  │  - Stockage indexé par labels │                  │
│  │  - Ne stocke PAS le contenu   │                  │
│  │    en full-text (économique)  │                  │
│  │  - Rétention configurable     │                  │
│  └──────────────┬───────────────┘                   │
│                 │ query (LogQL)                     │
│                 ▼                                   │
│  ┌──────────────────────────┐                       │
│  │        Grafana            │                      │
│  │   Data Source: Loki       │                      │
│  │   Explore → logs en       │                      │
│  │   temps réel              │                      │
│  └──────────────────────────┘                       │
└──────────────────────────────────────────────────────┘
```

### Pourquoi Loki plutôt qu'ELK (Elasticsearch + Logstash + Kibana) ?

| Critère | Loki + Promtail | ELK Stack |
|---------|----------------|-----------|
| **Mémoire requise** | ~128-256Mi | ~2-4Gi (Elasticsearch seul) |
| **Stockage** | Index par labels uniquement | Full-text indexing (10x plus lourd) |
| **Intégration Grafana** | Native (même outil que Prometheus) | Kibana séparé ou plugin |
| **Installation** | 1 Helm chart | 3 composants indépendants |
| **Complexité opérationnelle** | Faible | Élevée (tuning JVM, sharding, etc.) |
| **Adapté à K8s** | Conçu pour | Adapté après coup |

### Installation via Helm

```bash
# Ajouter le repo Grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Installer Loki + Promtail
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi \
  --set loki.config.limits_config.retention_period=168h   # 7 jours
```

### Configurer Grafana comme interface

1. Aller dans Grafana → **Configuration** → **Data Sources**
2. Ajouter → **Loki**
3. URL : `http://loki:3100`
4. Save & Test

### Requêtes LogQL (le "PromQL des logs")

| Cas d'usage | Requête LogQL | Description |
|-------------|--------------|-------------|
| Tous les logs d'un service | `{namespace="techshop", app="api-gateway"}` | Filtrage par label |
| Erreurs uniquement | `{namespace="techshop"} \|= "error"` | Recherche de texte |
| Erreurs 500 | `{namespace="techshop", app="api-gateway"} \|= "500"` | Filtrage + texte |
| Logs JSON parsés | `{app="user-service"} \| json \| level="ERROR"` | Parse JSON natif |
| Logs avec regex | `{app="order-service"} \|~ "order_id=[0-9]+"` | Filtrage regex |
| Compteur d'erreurs | `count_over_time({namespace="techshop"} \|= "error" [5m])` | Métrique dérivée |
| Débit de logs | `rate({namespace="techshop"}[1m])` | Logs/seconde |

### Labels automatiques ajoutés par Promtail

Chaque ligne de log reçoit automatiquement ces labels Kubernetes :

| Label | Exemple | Source |
|-------|---------|--------|
| `namespace` | `techshop` | Metadata du pod |
| `pod` | `api-gateway-7f8d9c4b5-x2k9l` | Nom du pod |
| `container` | `api-gateway` | Nom du conteneur |
| `node_name` | `ip-10-0-1-42.eu-west-1.compute.internal` | Nœud K8s |
| `stream` | `stdout` ou `stderr` | Flux de sortie |

---

## 7. Procédures d'incident

### Procédure 1 : Service en erreur (taux 5xx élevé)

```
1. IDENTIFIER ─── Alerte Grafana "HighErrorRate" reçue sur #techshop-alerts
     │
2. DIAGNOSTIQUER
     ├── Grafana : vérifier quel service est concerné (dashboard TechShop)
     ├── Logs : Grafana → Explore → Loki
     │     {namespace="techshop", app="<service>"} |= "error"
     └── Pods : kubectl -n techshop get pods (CrashLoopBackOff ?)
     │
3. AGIR
     ├── Si crash loop → kubectl -n techshop logs <pod> --previous
     ├── Si OOM kill → augmenter resources.limits.memory
     ├── Si erreur applicative → rollback
     │     kubectl -n techshop rollout undo deployment/<service>
     └── Si problème DB → vérifier la connexion PostgreSQL/Redis
     │
4. VÉRIFIER ─── Confirmer le retour à la normale sur le dashboard
     │
5. POST-MORTEM ─── Documenter la cause racine et les actions correctives
```

### Procédure 2 : Déploiement échoué

```
1. Le pipeline CD détecte un échec de rollout (timeout 5 minutes)
     │
2. ROLLBACK AUTOMATIQUE
     kubectl -n techshop rollout undo deployment/<service>
     │
3. VÉRIFICATION
     ├── kubectl -n techshop rollout status deployment/<service>
     └── Vérifier les logs du pod qui a échoué :
           kubectl -n techshop logs deployment/<service> --previous
     │
4. CORRECTION
     ├── Corriger le code ou la configuration
     ├── Pousser un nouveau commit
     └── Le pipeline CI/CD se relance automatiquement
```

### Procédure 3 : Base de données indisponible

```
1. ALERTE "DatabaseDown" reçue
     │
2. DIAGNOSTIQUER
     ├── kubectl -n techshop get pods -l app=database
     ├── kubectl -n techshop logs statefulset/database
     └── Vérifier le PVC : kubectl -n techshop get pvc
     │
3. AGIR
     ├── Si pod down → kubectl -n techshop delete pod database-0
     │   (le StatefulSet le recrée automatiquement avec le même PVC)
     ├── Si PVC full → étendre le PVC
     │     kubectl -n techshop edit pvc postgres-data-database-0
     └── Si RDS (prod) → vérifier via la console AWS ou CLI
           aws rds describe-db-instances --db-instance-identifier techshop-prod
     │
4. VÉRIFIER ─── Les services applicatifs se reconnectent automatiquement
```

---

## 8. Commandes utiles

### CI/CD

```bash
# Voir les dernières exécutions du pipeline
gh run list --workflow=ci.yml

# Voir les détails d'une exécution
gh run view <run-id>

# Relancer un pipeline échoué
gh run rewatch <run-id>

# Déclencher manuellement le déploiement
gh workflow run cd.yml
```

### Monitoring

```bash
# Accéder à Grafana (port-forward)
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80

# Accéder à Prometheus (port-forward)
kubectl port-forward -n monitoring svc/monitoring-prometheus 9090:9090

# Accéder à AlertManager
kubectl port-forward -n monitoring svc/monitoring-alertmanager 9093:9093

# Vérifier que Prometheus scrape bien les services
kubectl port-forward -n monitoring svc/monitoring-prometheus 9090:9090
# Puis ouvrir http://localhost:9090/targets

# Voir les alertes actives
kubectl -n monitoring exec -it deploy/monitoring-prometheus -- \
  promtool query instant http://localhost:9090 'ALERTS{alertstate="firing"}'
```

### Logs

```bash
# Voir les logs en temps réel d'un service
kubectl -n techshop logs -f deployment/api-gateway

# Voir les logs de tous les pods d'un service
kubectl -n techshop logs -l app.kubernetes.io/name=api-gateway --all-containers

# Voir les logs du pod précédent (après un crash)
kubectl -n techshop logs <pod-name> --previous

# Accéder à Loki via Grafana Explore
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# Puis Grafana → Explore → Data Source: Loki
```

---

## 9. Résumé de l'architecture d'observabilité

```
┌─────────────────── MÉTRIQUES ───────────────────┐
│                                                   │
│  Services TechShop  →  Prometheus  →  Grafana     │
│  (/metrics)            (scrape)       (dashboard)  │
│                           ↓                        │
│                     AlertManager  →  Slack/Email   │
│                                                   │
├─────────────────────── LOGS ────────────────────┤
│                                                   │
│  Pods stdout/stderr  →  Promtail  →  Loki         │
│                         (collect)    (stockage)    │
│                                          ↓         │
│                                      Grafana       │
│                                      (Explore)     │
│                                                   │
├──────────────────── HEALTH ─────────────────────┤
│                                                   │
│  Liveness Probes    →  Kubernetes  →  Auto-restart │
│  Readiness Probes   →  Kubernetes  →  Traffic mgmt │
│  HPA metrics        →  Kubernetes  →  Auto-scale   │
│                                                   │
└───────────────────────────────────────────────────┘
```
