package com.techshop.product.service;

import com.techshop.product.model.Product;
import com.techshop.product.repository.ProductRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

/**
 * Service métier pour la gestion des produits
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ProductService {

    private final ProductRepository productRepository;

    @Cacheable(value = "products", unless = "#result.isEmpty()")
    public List<Product> getAllProducts() {
        log.info("Récupération de tous les produits depuis la BDD");
        return productRepository.findByActiveTrue();
    }

    @Cacheable(value = "product", key = "#id")
    public Optional<Product> getProductById(Long id) {
        log.info("Récupération du produit id={}", id);
        return productRepository.findById(id);
    }

    public List<Product> getProductsByCategory(String category) {
        log.info("Récupération des produits de la catégorie '{}'", category);
        return productRepository.findByCategoryAndActiveTrue(category);
    }

    public List<Product> searchProducts(String query) {
        log.info("Recherche de produits : '{}'", query);
        return productRepository.findByNameContainingIgnoreCaseAndActiveTrue(query);
    }

    @CacheEvict(value = {"products", "product"}, allEntries = true)
    public Product createProduct(Product product) {
        log.info("Création d'un nouveau produit : {}", product.getName());
        return productRepository.save(product);
    }

    @CacheEvict(value = {"products", "product"}, allEntries = true)
    public Optional<Product> updateStock(Long id, int quantity) {
        return productRepository.findById(id).map(product -> {
            int newStock = product.getStock() + quantity;
            if (newStock < 0) {
                throw new IllegalArgumentException("Stock insuffisant");
            }
            product.setStock(newStock);
            log.info("Stock mis à jour pour le produit id={}: {} -> {}", id, product.getStock() - quantity, newStock);
            return productRepository.save(product);
        });
    }
}
