package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/techshop/order-service/internal/models"
	"github.com/techshop/order-service/internal/services"
)

// OrderHandler gère les requêtes HTTP pour les commandes
type OrderHandler struct {
	service *services.OrderService
}

// NewOrderHandler crée une nouvelle instance du handler
func NewOrderHandler(service *services.OrderService) *OrderHandler {
	return &OrderHandler{service: service}
}

// CreateOrder gère POST /api/orders
func (h *OrderHandler) CreateOrder(c *gin.Context) {
	var req models.CreateOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":  "Données de commande invalides",
			"detail": err.Error(),
		})
		return
	}

	order, err := h.service.CreateOrder(req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Erreur lors de la création de la commande",
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"order_id": order.ID,
		"order":    order,
		"message":  "Commande créée avec succès",
	})
}

// GetOrder gère GET /api/orders/:id
func (h *OrderHandler) GetOrder(c *gin.Context) {
	orderID := c.Param("id")

	order, err := h.service.GetOrder(orderID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Commande non trouvée",
		})
		return
	}

	c.JSON(http.StatusOK, order)
}

// GetUserOrders gère GET /api/orders?user_id=X
func (h *OrderHandler) GetUserOrders(c *gin.Context) {
	userIDStr := c.Query("user_id")
	if userIDStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Le paramètre user_id est requis",
		})
		return
	}

	userID, err := strconv.Atoi(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "user_id invalide",
		})
		return
	}

	orders, err := h.service.GetUserOrders(userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Erreur lors de la récupération des commandes",
		})
		return
	}

	if orders == nil {
		orders = []models.Order{}
	}

	c.JSON(http.StatusOK, gin.H{
		"orders": orders,
		"total":  len(orders),
	})
}

// UpdateOrderStatus gère PATCH /api/orders/:id/status
func (h *OrderHandler) UpdateOrderStatus(c *gin.Context) {
	orderID := c.Param("id")

	var req models.OrderStatusUpdate
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":  "Statut invalide",
			"detail": "Statuts acceptés : pending, confirmed, shipped, delivered, cancelled",
		})
		return
	}

	order, err := h.service.UpdateOrderStatus(orderID, req.Status)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Commande non trouvée",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"order":   order,
		"message": "Statut mis à jour",
	})
}

// Metrics gère GET /metrics (placeholder pour Prometheus)
func (h *OrderHandler) Metrics(c *gin.Context) {
	c.String(http.StatusOK, "# HELP order_service_requests_total Total requests\n# TYPE order_service_requests_total counter\n")
}
