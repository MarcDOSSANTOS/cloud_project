/*
TechShop Order Service
Service de gestion des commandes
Technologie : Go / Gin
Port : 8003

Responsabilités :
- Création et suivi des commandes
- Communication asynchrone via RabbitMQ
- Cache des commandes récentes via Redis
*/

package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
	"github.com/techshop/order-service/internal/handlers"
	"github.com/techshop/order-service/internal/middleware"
	"github.com/techshop/order-service/internal/services"
)

func main() {
	// ============================================
	// Configuration
	// ============================================
	port := getEnv("PORT", "8003")
	dbHost := getEnv("DB_HOST", "database")
	dbPort := getEnv("DB_PORT", "5432")
	dbUser := getEnv("DB_USERNAME", "techshop")
	dbPass := getEnv("DB_PASSWORD", "techshop_password")
	dbName := getEnv("DB_NAME", "techshop")
	rabbitURL := getEnv("RABBITMQ_URL", "amqp://guest:guest@message-queue:5672/")

	// ============================================
	// Connexion à PostgreSQL
	// ============================================
	dsn := fmt.Sprintf("host=%s port=%s user=%s password=%s dbname=%s sslmode=disable",
		dbHost, dbPort, dbUser, dbPass, dbName)

	var db *sql.DB
	var err error

	// Retry logic pour attendre que la BDD soit prête
	for i := 0; i < 30; i++ {
		db, err = sql.Open("postgres", dsn)
		if err == nil {
			err = db.Ping()
			if err == nil {
				break
			}
		}
		log.Printf("⏳ En attente de PostgreSQL... tentative %d/30", i+1)
		time.Sleep(2 * time.Second)
	}
	if err != nil {
		log.Fatalf("❌ Impossible de se connecter à PostgreSQL: %v", err)
	}
	defer db.Close()

	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	log.Println("✅ Connecté à PostgreSQL")

	// ============================================
	// Initialisation de la base de données
	// ============================================
	if err := initDB(db); err != nil {
		log.Fatalf("❌ Erreur d'initialisation de la BDD: %v", err)
	}

	// ============================================
	// Service de commandes
	// ============================================
	orderService := services.NewOrderService(db, rabbitURL)

	// ============================================
	// Configuration du routeur Gin
	// ============================================
	if os.Getenv("GIN_MODE") == "" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()
	router.Use(gin.Recovery())
	router.Use(middleware.Logger())
	router.Use(middleware.CORS())

	// ============================================
	// Routes
	// ============================================
	handler := handlers.NewOrderHandler(orderService)

	// Health check
	router.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status":  "up",
			"service": "order-service",
			"version": "1.0.0",
		})
	})

	// API routes
	api := router.Group("/api/orders")
	{
		api.POST("", handler.CreateOrder)
		api.GET("", handler.GetUserOrders)
		api.GET("/:id", handler.GetOrder)
		api.PATCH("/:id/status", handler.UpdateOrderStatus)
	}

	// Métriques
	router.GET("/metrics", handler.Metrics)

	// ============================================
	// Démarrage
	// ============================================
	log.Printf(`
╔══════════════════════════════════════════════╗
║   TechShop Order Service                     ║
║   Port: %s                                   ║
╚══════════════════════════════════════════════╝
`, port)

	if err := router.Run(":" + port); err != nil {
		log.Fatalf("❌ Erreur de démarrage du serveur: %v", err)
	}
}

// initDB crée les tables nécessaires
func initDB(db *sql.DB) error {
	query := `
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
		order_id VARCHAR(36) NOT NULL REFERENCES orders(id),
		product_id INTEGER NOT NULL,
		product_name VARCHAR(200),
		quantity INTEGER NOT NULL DEFAULT 1,
		price DECIMAL(10, 2) NOT NULL,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);

	CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
	CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
	CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
	`

	_, err := db.Exec(query)
	if err != nil {
		return fmt.Errorf("erreur de création des tables: %w", err)
	}
	log.Println("✅ Tables 'orders' et 'order_items' prêtes")
	return nil
}

func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
