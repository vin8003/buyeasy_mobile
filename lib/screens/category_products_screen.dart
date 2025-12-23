import 'package:flutter/material.dart';
import '../models/product.dart'; // Ensure this path is correct
import '../widgets/product_card.dart'; // Ensure this path is correct

class CategoryProductsScreen extends StatelessWidget {
  final String categoryName;

  // Placeholder data using the CORRECTED Product constructor
  final List<Product> _products = [
    Product(
      id: 1,
      name: 'Sample Product 1',
      description: 'This is a description.',
      price: 199.99,
      image: 'https://via.placeholder.com/150',
      mrp: 249.99,
      discountPercent: 20,
      unit: 'piece',
    ),
    Product(
      id: 2,
      name: 'Sample Product 2',
      description: 'This is a description.',
      price: 299.99,
      image: 'https://via.placeholder.com/150',
      mrp: 349.99,
      discountPercent: 14,
      unit: 'piece',
    ),
    Product(
      id: 3,
      name: 'Sample Product 3',
      description: 'This is a description.',
      price: 399.99,
      image: 'https://via.placeholder.com/150',
      mrp: 449.99,
      discountPercent: 11,
      unit: 'piece',
    ),
    Product(
      id: 4,
      name: 'Sample Product 4',
      description: 'This is a description.',
      price: 499.99,
      image: 'https://via.placeholder.com/150',
      mrp: 549.99,
      discountPercent: 9,
      unit: 'piece',
    ),
  ];

  CategoryProductsScreen({Key? key, required this.categoryName})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    // In a real app, you would filter products based on the categoryName
    // For now, we'll just display all sample products.
    final List<Product> filteredProducts = _products;

    return Scaffold(
      appBar: AppBar(title: Text(categoryName)),
      body: GridView.builder(
        padding: const EdgeInsets.all(10.0),
        itemCount: filteredProducts.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (ctx, i) {
          return ProductCard(product: filteredProducts[i]);
        },
      ),
    );
  }
}
