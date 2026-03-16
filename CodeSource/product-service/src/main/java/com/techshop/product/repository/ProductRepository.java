package com.techshop.product.repository;

import com.techshop.product.model.Product;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;

/**
 * Repository JPA pour l'accès aux données Product
 */
@Repository
public interface ProductRepository extends JpaRepository<Product, Long> {

    List<Product> findByActiveTrue();

    List<Product> findByCategoryAndActiveTrue(String category);

    List<Product> findByNameContainingIgnoreCaseAndActiveTrue(String name);

    List<Product> findByPriceBetweenAndActiveTrue(java.math.BigDecimal minPrice, java.math.BigDecimal maxPrice);
}
