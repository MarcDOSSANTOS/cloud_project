import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';

function OrdersPage({ token }) {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const navigate = useNavigate();

  useEffect(() => {
    if (!token) {
      navigate('/login');
      return;
    }
    fetchOrders();
  }, [token, navigate]);

  const fetchOrders = async () => {
    try {
      setLoading(true);
      const response = await api.get('/orders');
      setOrders(response.data.orders || response.data);
    } catch (err) {
      setError('Impossible de charger les commandes.');
    } finally {
      setLoading(false);
    }
  };

  const getStatusColor = (status) => {
    const colors = {
      pending: '#f39c12',
      confirmed: '#3498db',
      shipped: '#9b59b6',
      delivered: '#27ae60',
      cancelled: '#e74c3c',
    };
    return colors[status] || '#666';
  };

  if (loading) {
    return (
      <div className="loading">
        <div className="spinner"></div>
      </div>
    );
  }

  return (
    <div className="container">
      <h2><i className="fas fa-box"></i> Mes Commandes</h2>

      {error && <div className="alert alert-error">{error}</div>}

      {orders.length === 0 ? (
        <div className="alert alert-info">
          Aucune commande trouvée. <a href="/products">Commencez vos achats</a>
        </div>
      ) : (
        orders.map((order) => (
          <div
            key={order.id}
            className="product-card"
            style={{ margin: '1rem 0', cursor: 'default' }}
          >
            <div className="product-info">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <h3>Commande #{order.id}</h3>
                <span
                  style={{
                    padding: '0.25rem 0.75rem',
                    borderRadius: '20px',
                    backgroundColor: getStatusColor(order.status),
                    color: 'white',
                    fontSize: '0.85rem',
                  }}
                >
                  {order.status}
                </span>
              </div>
              <p style={{ color: '#666', margin: '0.5rem 0' }}>
                Date : {new Date(order.created_at).toLocaleDateString('fr-FR')}
              </p>
              {order.items && (
                <ul style={{ listStyle: 'none', padding: 0 }}>
                  {order.items.map((item, idx) => (
                    <li key={idx} style={{ padding: '0.25rem 0' }}>
                      {item.product_name || `Produit #${item.product_id}`} × {item.quantity} — {(item.price * item.quantity).toFixed(2)} €
                    </li>
                  ))}
                </ul>
              )}
              <p className="product-price" style={{ textAlign: 'right' }}>
                Total : {order.total_amount?.toFixed(2)} €
              </p>
            </div>
          </div>
        ))
      )}
    </div>
  );
}

export default OrdersPage;
