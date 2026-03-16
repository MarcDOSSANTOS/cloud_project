/**
 * Routes Health - Agrégation des health checks de tous les services
 * Utilisé pour le monitoring et la page de statut du frontend
 */

const express = require('express');
const axios = require('axios');
const router = express.Router();

// GET /api/health - Health check agrégé
router.get('/', async (req, res) => {
  const services = req.app.get('services');
  
  const checks = [
    { name: 'API Gateway', url: null, status: 'up', response_time: 0 },
    { name: 'User Service', url: `${services.USER_SERVICE}/health` },
    { name: 'Product Service', url: `${services.PRODUCT_SERVICE}/actuator/health` },
    { name: 'Order Service', url: `${services.ORDER_SERVICE}/health` },
  ];

  const results = await Promise.all(
    checks.map(async (check) => {
      if (!check.url) {
        return check; // API Gateway est toujours up si on arrive ici
      }

      const start = Date.now();
      try {
        const response = await axios.get(check.url, { timeout: 5000 });
        return {
          name: check.name,
          status: 'up',
          response_time: Date.now() - start,
          details: response.data,
        };
      } catch (err) {
        return {
          name: check.name,
          status: 'down',
          response_time: Date.now() - start,
          error: err.message,
        };
      }
    })
  );

  const allUp = results.every((r) => r.status === 'up');

  res.status(allUp ? 200 : 503).json({
    status: allUp ? 'healthy' : 'degraded',
    timestamp: new Date().toISOString(),
    services: results,
  });
});

module.exports = router;
