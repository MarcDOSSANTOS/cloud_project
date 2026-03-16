/**
 * Routes Orders - Proxy vers le Order Service (Go)
 * Toutes les routes nécessitent une authentification (middleware appliqué dans server.js)
 */

const express = require('express');
const axios = require('axios');
const router = express.Router();

// POST /api/orders - Créer une commande
router.post('/', async (req, res) => {
  try {
    const serviceUrl = req.app.get('services').ORDER_SERVICE;
    const orderData = {
      ...req.body,
      user_id: req.user.id,
    };
    const response = await axios.post(`${serviceUrl}/api/orders`, orderData);
    res.status(201).json(response.data);
  } catch (err) {
    const status = err.response?.status || 500;
    const data = err.response?.data || { error: 'Order Service indisponible' };
    res.status(status).json(data);
  }
});

// GET /api/orders - Liste des commandes de l'utilisateur
router.get('/', async (req, res) => {
  try {
    const serviceUrl = req.app.get('services').ORDER_SERVICE;
    const response = await axios.get(`${serviceUrl}/api/orders`, {
      params: { user_id: req.user.id },
    });
    res.json(response.data);
  } catch (err) {
    const status = err.response?.status || 500;
    const data = err.response?.data || { error: 'Order Service indisponible' };
    res.status(status).json(data);
  }
});

// GET /api/orders/:id - Détail d'une commande
router.get('/:id', async (req, res) => {
  try {
    const serviceUrl = req.app.get('services').ORDER_SERVICE;
    const response = await axios.get(`${serviceUrl}/api/orders/${req.params.id}`);
    
    // Vérifier que la commande appartient à l'utilisateur
    if (response.data.user_id !== req.user.id) {
      return res.status(403).json({ error: 'Accès non autorisé à cette commande' });
    }
    
    res.json(response.data);
  } catch (err) {
    const status = err.response?.status || 500;
    const data = err.response?.data || { error: 'Order Service indisponible' };
    res.status(status).json(data);
  }
});

module.exports = router;
