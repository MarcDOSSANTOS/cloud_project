/**
 * Routes Users - Proxy vers le User Service (Python/FastAPI)
 */

const express = require('express');
const axios = require('axios');
const router = express.Router();

// POST /api/users/register
router.post('/register', async (req, res) => {
  try {
    const serviceUrl = req.app.get('services').USER_SERVICE;
    const response = await axios.post(`${serviceUrl}/users/register`, req.body);
    res.status(201).json(response.data);
  } catch (err) {
    const status = err.response?.status || 500;
    const data = err.response?.data || { error: 'User Service indisponible' };
    res.status(status).json(data);
  }
});

// POST /api/users/login
router.post('/login', async (req, res) => {
  try {
    const serviceUrl = req.app.get('services').USER_SERVICE;
    const response = await axios.post(`${serviceUrl}/users/login`, req.body);
    res.json(response.data);
  } catch (err) {
    const status = err.response?.status || 500;
    const data = err.response?.data || { error: 'User Service indisponible' };
    res.status(status).json(data);
  }
});

// GET /api/users/profile (nécessite auth - géré par le middleware du calling code)
router.get('/profile', async (req, res) => {
  try {
    const serviceUrl = req.app.get('services').USER_SERVICE;
    const response = await axios.get(`${serviceUrl}/users/profile`, {
      headers: { Authorization: req.headers.authorization },
    });
    res.json(response.data);
  } catch (err) {
    const status = err.response?.status || 500;
    const data = err.response?.data || { error: 'User Service indisponible' };
    res.status(status).json(data);
  }
});

module.exports = router;
