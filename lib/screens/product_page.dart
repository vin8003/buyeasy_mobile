import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductPage extends StatefulWidget {
  final Product product;

  const ProductPage({super.key, required this.product});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final ApiService _apiService = ApiService();
  bool _isAddingToCart = false;

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  Future<void> _addToCart() async {
    setState(() {
      _isAddingToCart = true;
    });

    try {
      final response = await _apiService.addToCart(
        widget.product.id,
        1,
      ); // Adding quantity of 1

      if (response.statusCode == 201) {
        _showSnackBar('${widget.product.name} added to cart!');
      }
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data['detail'] ?? 'Could not add item to cart.';
      _showSnackBar(errorMessage, isError: true);
    } catch (e) {
      _showSnackBar('An unexpected error occurred.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isAddingToCart = false;
        });
      }
    }
  }

  Future<void> _addToWishlist() async {
    try {
      final response = await _apiService.addToWishlist(widget.product.id);
      if (response.statusCode == 201) {
        _showSnackBar('${widget.product.name} added to wishlist!');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 400 &&
          e.response?.data['error'] == 'Product already in wishlist') {
        _showSnackBar('${widget.product.name} is already in your wishlist.');
      } else {
        _showSnackBar('Failed to add to wishlist', isError: true);
      }
    } catch (e) {
      _showSnackBar('An unexpected error occurred.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    final String imageUrl = ApiService().formatImageUrl(widget.product.image);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.favorite_border,
            ), // Use border for now as we don't know state
            tooltip: 'Add to Wishlist',
            onPressed: _addToWishlist,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            CachedNetworkImage(
              imageUrl: imageUrl,
              placeholder: (context, url) =>
                  Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.error),
              fit: BoxFit.cover,
              height: 300,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${widget.product.price.toStringAsFixed(2)}',
                    style: textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (widget.product.stockQuantity > 0)
                    Text(
                      'In Stock (${widget.product.stockQuantity} ${widget.product.unit}s available)',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  else
                    const Text(
                      'Out of Stock',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Description',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.product.description, style: textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: (_isAddingToCart || widget.product.stockQuantity <= 0)
              ? null
              : _addToCart,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.product.stockQuantity <= 0
                ? Colors.grey
                : null,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 18),
          ),
          child: _isAddingToCart
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  widget.product.stockQuantity <= 0
                      ? 'Out of Stock'
                      : 'Add to Cart',
                ),
        ),
      ),
    );
  }
}
