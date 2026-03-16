import React from 'react';
import { Link } from 'react-router-dom';

function HomePage() {
  return (
    <div className="container">
      <div className="hero">
        <h1><i className="fas fa-microchip"></i> Bienvenue sur TechShop</h1>
        <p>Votre boutique en ligne pour les meilleurs produits tech</p>
        <br />
        <Link to="/products" className="btn btn-primary">
          Découvrir nos produits
        </Link>
      </div>

      <div className="products-grid">
        <div className="product-card">
          <div style={{ padding: '2rem', textAlign: 'center', background: '#e8f4f8' }}>
            <i className="fas fa-shipping-fast" style={{ fontSize: '3rem', color: '#0f3460' }}></i>
          </div>
          <div className="product-info">
            <h3>Livraison Rapide</h3>
            <p>Expédition sous 24h pour toutes vos commandes</p>
          </div>
        </div>

        <div className="product-card">
          <div style={{ padding: '2rem', textAlign: 'center', background: '#fde8e8' }}>
            <i className="fas fa-shield-alt" style={{ fontSize: '3rem', color: '#e94560' }}></i>
          </div>
          <div className="product-info">
            <h3>Paiement Sécurisé</h3>
            <p>Transactions protégées et données chiffrées</p>
          </div>
        </div>

        <div className="product-card">
          <div style={{ padding: '2rem', textAlign: 'center', background: '#e8f8e8' }}>
            <i className="fas fa-headset" style={{ fontSize: '3rem', color: '#27ae60' }}></i>
          </div>
          <div className="product-info">
            <h3>Support 24/7</h3>
            <p>Une équipe dédiée pour vous accompagner</p>
          </div>
        </div>
      </div>
    </div>
  );
}

export default HomePage;
