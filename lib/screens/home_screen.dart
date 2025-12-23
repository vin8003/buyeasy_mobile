import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import 'product_page.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // final response = await _apiService.get(
      //   '/products/retailer/1/',
      //   requiresAuth: false,
      // );
      final response = null;
      if (response.statusCode == 200) {
        final List<dynamic> productJson = response.data['results'];

        // --- DEBUGGING PRINT ---
        // This will show us the exact data coming from the server.
        print('--- Received product data from server: ---');
        print(productJson);
        // --- END DEBUGGING ---

        setState(() {
          _products = productJson
              .map((json) {
                // We'll wrap the parsing in a try-catch to pinpoint any bad data
                try {
                  return Product.fromJson(json);
                } catch (e) {
                  print('Error parsing product: $json');
                  print('Error details: $e');
                  return null; // Return null for products that fail to parse
                }
              })
              .where((product) => product != null)
              .cast<Product>()
              .toList(); // Filter out any nulls
        });
      } else {
        throw 'Failed to load products (${response.statusCode})';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data['detail'] ?? 'A network error occurred.';
      print('DioException: $_errorMessage');
    } catch (e) {
      _errorMessage = 'An unexpected error occurred while processing data.';
      print('Generic Exception: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop Easy'),
        actions: [IconButton(icon: const Icon(Icons.search), onPressed: () {})],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchProducts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: InkWell(
          onTap: _fetchProducts,
          child: const Text('No products found. Tap to retry.'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchProducts,
      child: GridView.builder(
        padding: const EdgeInsets.all(10.0),
        itemCount: _products.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (ctx, i) => GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/product', arguments: _products[i]);
          },
          child: ProductCard(product: _products[i]),
        ),
      ),
    );
  }
}
