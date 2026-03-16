/**
 * Routes Products - Proxy vers le Product Service (Java/Spring Boot)
 */

const express = require('express');
const axios = require('axios');
const router = express.Router();

// GET /api/products - Liste des produits
router.get('/', async (req, res) => {
  try {
    const serviceUrl = req.app.get('services').PRODUCT_SERVICE;
    const response = await axios.get(`${serviceUrl}/api/products`, {
      params: req.query,
    });
    res.json(response.data);
  } catch (err) {
    const status = err.response?.status || 500;
    const data = err.response?.data || { error: 'Product Service indisponible' };
    res.status(status).json(data);
  }
});

// GET /api/products/:id - Détail d'un produit
router.get('/:id', async (req, res) => {
  try {
    const serviceUrl = req.app.get('services').PRODUCT_SERVICE;
    const response = await axios.get(`${serviceUrl}/api/products/${req.params.id}`);
    res.json(response.data);
  } catch (err) {
    const status = err.response?.status || 500;
    const data = err.response?.data || { error: 'Product Service indisponible' };
    res.status(status).json(data);
  }
});

// GET /api/products/category/:category - Produits par catégorie
router.get('/category/:category', async (req, res) => {
  try {
    const serviceUrl = req.app.get('services').PRODUCT_SERVICE;
    const response = await axios.get(`${serviceUrl}/api/products/category/${req.params.category}`);
    res.json(response.data);
  } catch (err) {
    const status = err.response?.status || 500;
    const data = err.response?.data || { error: 'Product Service indisponible' };
    res.status(status).json(data);
  }
});

module.exports = router;
