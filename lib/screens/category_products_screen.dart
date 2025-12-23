import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import '../services/api_service.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String categoryName;
  final int? retailerId;

  const CategoryProductsScreen({
    Key? key,
    required this.categoryName,
    this.retailerId,
  }) : super(key: key);

  @override
  _CategoryProductsScreenState createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final ApiService _apiService = ApiService();
  List<Product> _products = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    if (widget.retailerId == null) {
      setState(() {
        _errorMessage = 'Please select a retailer from the Home screen first.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await _apiService.getProducts(widget.retailerId!);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final allProducts = data.map((json) => Product.fromJson(json)).toList();

        setState(() {
          // Filter by category
          // Note: Ensure the casing matches. Backend category names vs UI category names.
          // The category.name from CategoryScreen comes from backend, so it should match product.categoryName from backend.
          _products = allProducts
              .where((p) => p.categoryName == widget.categoryName)
              .toList();
          _isLoading = false;
        });
      } else {
        throw 'Failed to load products';
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load products. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                    ),
                    if (widget.retailerId != null) ...[
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _fetchProducts,
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : _products.isEmpty
          ? const Center(child: Text('No products found in this category.'))
          : GridView.builder(
              padding: const EdgeInsets.all(10.0),
              itemCount: _products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2 / 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (ctx, i) {
                return ProductCard(product: _products[i]);
              },
            ),
    );
  }
}
