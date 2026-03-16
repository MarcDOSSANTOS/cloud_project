package com.techshop.product.config;

import com.techshop.product.model.Product;
import com.techshop.product.repository.ProductRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.List;

/**
 * Initialisation des données de démonstration au démarrage
 * Insère des produits si la base est vide
 */
@Component
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements CommandLineRunner {

    private final ProductRepository productRepository;

    @Override
    public void run(String... args) {
        if (productRepository.count() > 0) {
            log.info("Base de données déjà initialisée ({} produits)", productRepository.count());
            return;
        }

        log.info("Initialisation des données de démonstration...");

        List<Product> products = List.of(
            Product.builder()
                .name("MacBook Pro 16\"")
                .description("Ordinateur portable Apple avec puce M3 Pro, 18 Go RAM, 512 Go SSD")
                .price(new BigDecimal("2799.99"))
                .category("Ordinateurs")
                .stock(25)
                .imageUrl("https://via.placeholder.com/300x200?text=MacBook+Pro")
                .active(true)
                .build(),
            Product.builder()
                .name("Dell XPS 15")
                .description("Laptop Dell avec Intel Core i7, 16 Go RAM, écran OLED 3.5K")
                .price(new BigDecimal("1899.99"))
                .category("Ordinateurs")
                .stock(30)
                .imageUrl("https://via.placeholder.com/300x200?text=Dell+XPS")
                .active(true)
                .build(),
            Product.builder()
                .name("iPhone 15 Pro")
                .description("Smartphone Apple avec puce A17 Pro, 256 Go, Titane")
                .price(new BigDecimal("1229.00"))
                .category("Smartphones")
                .stock(50)
                .imageUrl("https://via.placeholder.com/300x200?text=iPhone+15+Pro")
                .active(true)
                .build(),
            Product.builder()
                .name("Samsung Galaxy S24 Ultra")
                .description("Smartphone Samsung avec Galaxy AI, S Pen intégré, 256 Go")
                .price(new BigDecimal("1419.00"))
                .category("Smartphones")
                .stock(40)
                .imageUrl("https://via.placeholder.com/300x200?text=Galaxy+S24")
                .active(true)
                .build(),
            Product.builder()
                .name("Sony WH-1000XM5")
                .description("Casque audio sans fil à réduction de bruit active premium")
                .price(new BigDecimal("349.99"))
                .category("Audio")
                .stock(60)
                .imageUrl("https://via.placeholder.com/300x200?text=Sony+WH1000XM5")
                .active(true)
                .build(),
            Product.builder()
                .name("AirPods Pro 2")
                .description("Écouteurs Apple avec réduction de bruit adaptative et USB-C")
                .price(new BigDecimal("279.00"))
                .category("Audio")
                .stock(80)
                .imageUrl("https://via.placeholder.com/300x200?text=AirPods+Pro")
                .active(true)
                .build(),
            Product.builder()
                .name("LG UltraGear 27\" 4K")
                .description("Moniteur gaming 27 pouces, 4K UHD, 144Hz, 1ms, HDR600")
                .price(new BigDecimal("599.99"))
                .category("Écrans")
                .stock(20)
                .imageUrl("https://via.placeholder.com/300x200?text=LG+UltraGear")
                .active(true)
                .build(),
            Product.builder()
                .name("Logitech MX Master 3S")
                .description("Souris ergonomique sans fil, capteur 8000 DPI, USB-C")
                .price(new BigDecimal("109.99"))
                .category("Accessoires")
                .stock(100)
                .imageUrl("https://via.placeholder.com/300x200?text=MX+Master+3S")
                .active(true)
                .build(),
            Product.builder()
                .name("Clavier Keychron K3 Pro")
                .description("Clavier mécanique sans fil, profil bas, RGB, hot-swappable")
                .price(new BigDecimal("119.00"))
                .category("Accessoires")
                .stock(45)
                .imageUrl("https://via.placeholder.com/300x200?text=Keychron+K3")
                .active(true)
                .build(),
            Product.builder()
                .name("iPad Air M2")
                .description("Tablette Apple avec puce M2, écran Liquid Retina 11\", 256 Go")
                .price(new BigDecimal("699.00"))
                .category("Tablettes")
                .stock(35)
                .imageUrl("https://via.placeholder.com/300x200?text=iPad+Air+M2")
                .active(true)
                .build(),
            Product.builder()
                .name("NVIDIA RTX 4070 Ti")
                .description("Carte graphique gaming, 12 Go GDDR6X, Ray Tracing, DLSS 3")
                .price(new BigDecimal("849.99"))
                .category("Composants")
                .stock(15)
                .imageUrl("https://via.placeholder.com/300x200?text=RTX+4070+Ti")
                .active(true)
                .build(),
            Product.builder()
                .name("Samsung 990 Pro 2TB")
                .description("SSD NVMe M.2, lecture 7450 Mo/s, écriture 6900 Mo/s")
                .price(new BigDecimal("179.99"))
                .category("Composants")
                .stock(70)
                .imageUrl("https://via.placeholder.com/300x200?text=Samsung+990+Pro")
                .active(true)
                .build()
        );

        productRepository.saveAll(products);
        log.info("✅ {} produits de démonstration insérés", products.size());
    }
}
