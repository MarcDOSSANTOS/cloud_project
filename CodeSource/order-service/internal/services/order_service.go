package services

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"

	"github.com/google/uuid"
	"github.com/techshop/order-service/internal/models"
)

// OrderService gère la logique métier des commandes
type OrderService struct {
	db        *sql.DB
	rabbitURL string
}

// NewOrderService crée une nouvelle instance du service
func NewOrderService(db *sql.DB, rabbitURL string) *OrderService {
	return &OrderService{
		db:        db,
		rabbitURL: rabbitURL,
	}
}

// CreateOrder crée une nouvelle commande
func (s *OrderService) CreateOrder(req models.CreateOrderRequest) (*models.Order, error) {
	orderID := uuid.New().String()

	// Calculer le total si non fourni
	totalAmount := req.TotalAmount
	if totalAmount == 0 {
		for _, item := range req.Items {
			totalAmount += item.Price * float64(item.Quantity)
		}
	}

	// Début de la transaction
	tx, err := s.db.Begin()
	if err != nil {
		return nil, fmt.Errorf("erreur de transaction: %w", err)
	}
	defer tx.Rollback()

	// Insérer la commande
	_, err = tx.Exec(
		"INSERT INTO orders (id, user_id, status, total_amount) VALUES ($1, $2, $3, $4)",
		orderID, req.UserID, models.StatusPending, totalAmount,
	)
	if err != nil {
		return nil, fmt.Errorf("erreur d'insertion de la commande: %w", err)
	}

	// Insérer les articles
	for _, item := range req.Items {
		_, err = tx.Exec(
			"INSERT INTO order_items (order_id, product_id, product_name, quantity, price) VALUES ($1, $2, $3, $4, $5)",
			orderID, item.ProductID, item.ProductName, item.Quantity, item.Price,
		)
		if err != nil {
			return nil, fmt.Errorf("erreur d'insertion de l'article: %w", err)
		}
	}

	// Commit
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("erreur de commit: %w", err)
	}

	// Publier un événement sur RabbitMQ (best effort)
	go s.publishOrderEvent(orderID, "order.created")

	// Récupérer la commande complète
	return s.GetOrder(orderID)
}

// GetOrder récupère une commande par son ID
func (s *OrderService) GetOrder(orderID string) (*models.Order, error) {
	order := &models.Order{}

	err := s.db.QueryRow(
		"SELECT id, user_id, status, total_amount, created_at, updated_at FROM orders WHERE id = $1",
		orderID,
	).Scan(&order.ID, &order.UserID, &order.Status, &order.TotalAmount, &order.CreatedAt, &order.UpdatedAt)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("commande non trouvée: %s", orderID)
	}
	if err != nil {
		return nil, fmt.Errorf("erreur de récupération: %w", err)
	}

	// Récupérer les articles
	rows, err := s.db.Query(
		"SELECT id, order_id, product_id, product_name, quantity, price FROM order_items WHERE order_id = $1",
		orderID,
	)
	if err != nil {
		return nil, fmt.Errorf("erreur de récupération des articles: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var item models.OrderItem
		if err := rows.Scan(&item.ID, &item.OrderID, &item.ProductID, &item.ProductName, &item.Quantity, &item.Price); err != nil {
			return nil, fmt.Errorf("erreur de scan d'article: %w", err)
		}
		order.Items = append(order.Items, item)
	}

	return order, nil
}

// GetUserOrders récupère les commandes d'un utilisateur
func (s *OrderService) GetUserOrders(userID int) ([]models.Order, error) {
	rows, err := s.db.Query(
		"SELECT id, user_id, status, total_amount, created_at, updated_at FROM orders WHERE user_id = $1 ORDER BY created_at DESC",
		userID,
	)
	if err != nil {
		return nil, fmt.Errorf("erreur de récupération des commandes: %w", err)
	}
	defer rows.Close()

	var orders []models.Order
	for rows.Next() {
		var order models.Order
		if err := rows.Scan(&order.ID, &order.UserID, &order.Status, &order.TotalAmount, &order.CreatedAt, &order.UpdatedAt); err != nil {
			return nil, fmt.Errorf("erreur de scan: %w", err)
		}
		orders = append(orders, order)
	}

	return orders, nil
}

// UpdateOrderStatus met à jour le statut d'une commande
func (s *OrderService) UpdateOrderStatus(orderID string, status string) (*models.Order, error) {
	result, err := s.db.Exec(
		"UPDATE orders SET status = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2",
		status, orderID,
	)
	if err != nil {
		return nil, fmt.Errorf("erreur de mise à jour: %w", err)
	}

	rowsAffected, _ := result.RowsAffected()
	if rowsAffected == 0 {
		return nil, fmt.Errorf("commande non trouvée: %s", orderID)
	}

	go s.publishOrderEvent(orderID, "order.status.updated")

	return s.GetOrder(orderID)
}

// publishOrderEvent publie un événement sur RabbitMQ
func (s *OrderService) publishOrderEvent(orderID string, eventType string) {
	event := map[string]string{
		"order_id":   orderID,
		"event_type": eventType,
	}
	data, _ := json.Marshal(event)
	log.Printf("📨 Événement publié: %s - %s", eventType, string(data))
	// Note: L'implémentation complète de RabbitMQ est laissée comme exercice
	// Les étudiants devront configurer la connexion AMQP dans leur déploiement
}
