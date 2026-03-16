import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import HomePage from './pages/HomePage';
import ProductsPage from './pages/ProductsPage';
import CartPage from './pages/CartPage';
import LoginPage from './pages/LoginPage';
import RegisterPage from './pages/RegisterPage';
import OrdersPage from './pages/OrdersPage';
import HealthPage from './pages/HealthPage';

function App() {
  const [cart, setCart] = React.useState([]);
  const [user, setUser] = React.useState(null);
  const [token, setToken] = React.useState(localStorage.getItem('token'));

  const addToCart = (product) => {
    setCart((prev) => {
      const existing = prev.find((item) => item.id === product.id);
      if (existing) {
        return prev.map((item) =>
          item.id === product.id
            ? { ...item, quantity: item.quantity + 1 }
            : item
        );
      }
      return [...prev, { ...product, quantity: 1 }];
    });
  };

  const removeFromCart = (productId) => {
    setCart((prev) => prev.filter((item) => item.id !== productId));
  };

  const updateQuantity = (productId, quantity) => {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }
    setCart((prev) =>
      prev.map((item) =>
        item.id === productId ? { ...item, quantity } : item
      )
    );
  };

  const handleLogin = (userData, authToken) => {
    setUser(userData);
    setToken(authToken);
    localStorage.setItem('token', authToken);
  };

  const handleLogout = () => {
    setUser(null);
    setToken(null);
    localStorage.removeItem('token');
  };

  const cartItemCount = cart.reduce((sum, item) => sum + item.quantity, 0);

  return (
    <Router>
      <div className="app">
        {/* Navigation */}
        <nav className="navbar">
          <Link to="/" className="navbar-brand">
            <i className="fas fa-microchip"></i> TechShop
          </Link>
          <ul className="navbar-nav">
            <li><Link to="/">Accueil</Link></li>
            <li><Link to="/products">Produits</Link></li>
            <li>
              <Link to="/cart">
                <i className="fas fa-shopping-cart"></i> Panier ({cartItemCount})
              </Link>
            </li>
            {token ? (
              <>
                <li><Link to="/orders">Mes Commandes</Link></li>
                <li>
                  <a href="#" onClick={(e) => { e.preventDefault(); handleLogout(); }}>
                    Déconnexion
                  </a>
                </li>
              </>
            ) : (
              <>
                <li><Link to="/login">Connexion</Link></li>
                <li><Link to="/register">Inscription</Link></li>
              </>
            )}
            <li><Link to="/health">Santé</Link></li>
          </ul>
        </nav>

        {/* Routes */}
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route
            path="/products"
            element={<ProductsPage addToCart={addToCart} />}
          />
          <Route
            path="/cart"
            element={
              <CartPage
                cart={cart}
                updateQuantity={updateQuantity}
                removeFromCart={removeFromCart}
                token={token}
              />
            }
          />
          <Route
            path="/login"
            element={<LoginPage onLogin={handleLogin} />}
          />
          <Route
            path="/register"
            element={<RegisterPage onLogin={handleLogin} />}
          />
          <Route
            path="/orders"
            element={<OrdersPage token={token} />}
          />
          <Route path="/health" element={<HealthPage />} />
        </Routes>

        {/* Footer */}
        <footer className="footer">
          <p>&copy; 2025 TechShop - Projet Cloud Computing EFREI M1-CSAI</p>
        </footer>
      </div>
    </Router>
  );
}

export default App;
