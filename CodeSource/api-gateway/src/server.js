/**
 * TechShop API Gateway
 * Point d'entrée centralisé pour tous les microservices
 * 
 * Responsabilités :
 * - Routage des requêtes vers les services appropriés
 * - Authentification JWT
 * - Rate limiting
 * - Logging centralisé
 * - Health checks agrégés
 * - Métriques Prometheus
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const { collectDefaultMetrics, register } = require('prom-client');

const userRoutes = require('./routes/users');
const productRoutes = require('./routes/products');
const orderRoutes = require('./routes/orders');
const healthRoutes = require('./routes/health');
const { authMiddleware } = require('./middleware/auth');

const app = express();
const PORT = process.env.PORT || 3000;

// ============================================
// Configuration des services backend
// ============================================
const SERVICES = {
  USER_SERVICE: process.env.USER_SERVICE_URL || 'http://user-service:8001',
  PRODUCT_SERVICE: process.env.PRODUCT_SERVICE_URL || 'http://product-service:8002',
  ORDER_SERVICE: process.env.ORDER_SERVICE_URL || 'http://order-service:8003',
};

// Rendre les URLs des services accessibles aux routes
app.set('services', SERVICES);

// ============================================
// Métriques Prometheus
// ============================================
collectDefaultMetrics({ prefix: 'techshop_gateway_' });

// ============================================
// Middlewares globaux
// ============================================
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));
app.use(express.json({ limit: '10mb' }));
app.use(morgan('combined'));

// Rate limiting global
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limite par IP
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: 'Trop de requêtes, veuillez réessayer plus tard.',
  },
});
app.use('/api/', limiter);

// ============================================
// Routes
// ============================================

// Health check global et métriques
app.use('/api/health', healthRoutes);
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err.message);
  }
});

// Routes publiques
app.use('/api/users', userRoutes);
app.use('/api/products', productRoutes);

// Routes protégées (nécessitent authentification)
app.use('/api/orders', authMiddleware, orderRoutes);

// ============================================
// Route racine
// ============================================
app.get('/api', (req, res) => {
  res.json({
    service: 'TechShop API Gateway',
    version: '1.0.0',
    endpoints: {
      health: '/api/health',
      users: '/api/users',
      products: '/api/products',
      orders: '/api/orders (auth required)',
      metrics: '/metrics',
    },
  });
});

// ============================================
// Gestion des erreurs
// ============================================
app.use((req, res) => {
  res.status(404).json({
    error: 'Route non trouvée',
    path: req.originalUrl,
  });
});

app.use((err, req, res, next) => {
  console.error(`[ERROR] ${err.message}`, err.stack);
  res.status(err.status || 500).json({
    error: err.message || 'Erreur interne du serveur',
  });
});

// ============================================
// Démarrage du serveur
// ============================================
app.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔══════════════════════════════════════════════╗
║   TechShop API Gateway                       ║
║   Port: ${PORT}                                  ║
║   Environment: ${process.env.NODE_ENV || 'development'}               ║
╚══════════════════════════════════════════════╝
  `);
  console.log('Services configurés :');
  Object.entries(SERVICES).forEach(([key, url]) => {
    console.log(`  → ${key}: ${url}`);
  });
});

module.exports = app;
