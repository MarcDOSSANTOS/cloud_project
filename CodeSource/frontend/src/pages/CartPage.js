import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api';

function CartPage({ cart, updateQuantity, removeFromCart, token }) {
  const [orderStatus, setOrderStatus] = useState(null);
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const total = cart.reduce((sum, item) => sum + item.price * item.quantity, 0);

  const handleCheckout = async () => {
    if (!token) {
      navigate('/login');
      return;
    }

    try {
      setLoading(true);
      const orderData = {
        items: cart.map((item) => ({
          product_id: item.id,
          quantity: item.quantity,
          price: item.price,
        })),
        total_amount: total,
      };

      const response = await api.post('/orders', orderData);
      setOrderStatus({
        type: 'success',
        message: `Commande #${response.data.order_id} créée avec succès !`,
      });
      // Vider le panier après la commande
      cart.forEach((item) => removeFromCart(item.id));
    } catch (err) {
      setOrderStatus({
        type: 'error',
        message: 'Erreur lors de la création de la commande. Veuillez réessayer.',
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="container">
      <h2><i className="fas fa-shopping-cart"></i> Mon Panier</h2>

      {orderStatus && (
        <div className={`alert alert-${orderStatus.type === 'success' ? 'success' : 'error'}`}>
          {orderStatus.message}
        </div>
      )}

      {cart.length === 0 ? (
        <div className="alert alert-info">
          Votre panier est vide. <a href="/products">Découvrez nos produits</a>
        </div>
      ) : (
        <>
          {cart.map((item) => (
            <div key={item.id} className="cart-item">
              <div>
                <h3>{item.name}</h3>
                <p style={{ color: '#666' }}>{item.price?.toFixed(2)} € / unité</p>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '1rem' }}>
                <button
                  className="btn btn-secondary"
                  onClick={() => updateQuantity(item.id, item.quantity - 1)}
                  style={{ padding: '0.5rem 0.75rem' }}
                >
                  -
                </button>
                <span style={{ fontSize: '1.1rem', fontWeight: 'bold' }}>{item.quantity}</span>
                <button
                  className="btn btn-secondary"
                  onClick={() => updateQuantity(item.id, item.quantity + 1)}
                  style={{ padding: '0.5rem 0.75rem' }}
                >
                  +
                </button>
                <span style={{ minWidth: '80px', textAlign: 'right', fontWeight: 'bold' }}>
                  {(item.price * item.quantity).toFixed(2)} €
                </span>
                <button
                  className="btn btn-primary"
                  onClick={() => removeFromCart(item.id)}
                  style={{ padding: '0.5rem 0.75rem' }}
                >
                  <i className="fas fa-trash"></i>
                </button>
              </div>
            </div>
          ))}

          <div className="cart-total">
            Total : {total.toFixed(2)} €
          </div>

          <div style={{ textAlign: 'right' }}>
            <button
              className="btn btn-primary"
              onClick={handleCheckout}
              disabled={loading}
              style={{ fontSize: '1.1rem', padding: '1rem 2rem' }}
            >
              {loading ? 'Traitement...' : 'Valider la commande'}
            </button>
          </div>
        </>
      )}
    </div>
  );
}

export default CartPage;
