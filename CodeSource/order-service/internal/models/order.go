package models

import "time"

// Order représente une commande
type Order struct {
	ID          string      `json:"id"`
	UserID      int         `json:"user_id"`
	Status      string      `json:"status"`
	TotalAmount float64     `json:"total_amount"`
	Items       []OrderItem `json:"items,omitempty"`
	CreatedAt   time.Time   `json:"created_at"`
	UpdatedAt   time.Time   `json:"updated_at"`
}

// OrderItem représente un article dans une commande
type OrderItem struct {
	ID          int     `json:"id,omitempty"`
	OrderID     string  `json:"order_id"`
	ProductID   int     `json:"product_id"`
	ProductName string  `json:"product_name,omitempty"`
	Quantity    int     `json:"quantity"`
	Price       float64 `json:"price"`
}

// CreateOrderRequest est le payload de création d'une commande
type CreateOrderRequest struct {
	UserID      int         `json:"user_id" binding:"required"`
	Items       []OrderItem `json:"items" binding:"required,min=1"`
	TotalAmount float64     `json:"total_amount"`
}

// OrderStatusUpdate est le payload de mise à jour du statut
type OrderStatusUpdate struct {
	Status string `json:"status" binding:"required,oneof=pending confirmed shipped delivered cancelled"`
}

// Statuts possibles d'une commande
const (
	StatusPending   = "pending"
	StatusConfirmed = "confirmed"
	StatusShipped   = "shipped"
	StatusDelivered = "delivered"
	StatusCancelled = "cancelled"
)
