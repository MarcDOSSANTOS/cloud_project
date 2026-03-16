import React, { useState, useEffect } from 'react';
import api from '../services/api';

function ProductsPage({ addToCart }) {
  const [products, setProducts] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [filter, setFilter] = useState('all');

  useEffect(() => {
    fetchProducts();
  }, []);

  const fetchProducts = async () => {
    try {
      setLoading(true);
      const response = await api.get('/products');
      setProducts(response.data.products || response.data);
      setError(null);
    } catch (err) {
      setError('Impossible de charger les produits. Vérifiez la connexion au serveur.');
      console.error('Erreur lors du chargement des produits:', err);
    } finally {
      setLoading(false);
    }
  };

  const categories = ['all', ...new Set(products.map((p) => p.category))];
  const filteredProducts =
    filter === 'all' ? products : products.filter((p) => p.category === filter);

  if (loading) {
    return (
      <div className="loading">
        <div className="spinner"></div>
      </div>
    );
  }

  return (
    <div className="container">
      <h2>Nos Produits</h2>

      {error && <div className="alert alert-error">{error}</div>}

      {/* Filtres par catégorie */}
      <div style={{ margin: '1rem 0', display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
        {categories.map((cat) => (
          <button
            key={cat}
            className={`btn ${filter === cat ? 'btn-primary' : 'btn-secondary'}`}
            onClick={() => setFilter(cat)}
            style={{ padding: '0.5rem 1rem', fontSize: '0.9rem' }}
          >
            {cat === 'all' ? 'Tous' : cat}
          </button>
        ))}
      </div>

      {/* Grille de produits */}
      <div className="products-grid">
        {filteredProducts.map((product) => (
          <div key={product.id} className="product-card">
            <img
              src={product.image_url || `https://via.placeholder.com/300x200?text=${encodeURIComponent(product.name)}`}
              alt={product.name}
            />
            <div className="product-info">
              <span className="product-category">{product.category}</span>
              <h3>{product.name}</h3>
              <p>{product.description}</p>
              <p className="product-price">{product.price?.toFixed(2)} €</p>
              <p style={{ fontSize: '0.85rem', color: '#666' }}>
                Stock : {product.stock > 0 ? product.stock : 'Rupture'}
              </p>
              <button
                className="btn btn-primary"
                onClick={() => addToCart(product)}
                disabled={product.stock <= 0}
                style={{ width: '100%', marginTop: '0.5rem' }}
              >
                <i className="fas fa-cart-plus"></i> Ajouter au panier
              </button>
            </div>
          </div>
        ))}
      </div>

      {filteredProducts.length === 0 && !error && (
        <div className="alert alert-info">Aucun produit trouvé dans cette catégorie.</div>
      )}
    </div>
  );
}

export default ProductsPage;
