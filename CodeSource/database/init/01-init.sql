-- ============================================
-- TechShop - Script d'initialisation PostgreSQL
-- Ce script est exécuté automatiquement au
-- premier démarrage du conteneur PostgreSQL
-- ============================================

-- Création de la base de données (si nécessaire)
-- Note : la base est déjà créée via POSTGRES_DB env var

-- ============================================
-- Table des utilisateurs (User Service)
-- ============================================
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- ============================================
-- Table des produits (Product Service)
-- ============================================
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    category VARCHAR(100) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    image_url VARCHAR(500),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_active ON products(active);

-- ============================================
-- Table des commandes (Order Service)
-- ============================================
CREATE TABLE IF NOT EXISTS orders (
    id VARCHAR(36) PRIMARY KEY,
    user_id INTEGER NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
    id SERIAL PRIMARY KEY,
    order_id VARCHAR(36) NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL,
    product_name VARCHAR(200),
    quantity INTEGER NOT NULL DEFAULT 1,
    price DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);

-- ============================================
-- Données de démonstration
-- ============================================

-- Utilisateur de test (mot de passe : "password123" hashé en bcrypt)
INSERT INTO users (name, email, password_hash) VALUES
    ('Alice Demo', 'alice@techshop.com', '$2b$12$LJ3m4ys1JG1lFPGB/eCPa.gUah5Ikq0T2PVWNhCLGrFY3D8s3MrDi'),
    ('Bob Test', 'bob@techshop.com', '$2b$12$LJ3m4ys1JG1lFPGB/eCPa.gUah5Ikq0T2PVWNhCLGrFY3D8s3MrDi')
ON CONFLICT (email) DO NOTHING;

-- Les produits sont insérés par le Product Service (DataInitializer.java)

RAISE NOTICE '✅ Base de données TechShop initialisée avec succès';
