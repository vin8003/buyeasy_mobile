import 'package:flutter/material.dart';
import '../models/product.dart'; // Ensure this path is correct
import '../widgets/product_card.dart'; // Ensure this path is correct

import '../services/api_service.dart';

class SearchResultsScreen extends StatefulWidget {
  final String query;
  final List<Product> searchResults;

  const SearchResultsScreen({
    super.key,
    required this.query,
    required this.searchResults,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  Set<int> _wishlistedProductIds = {};
  bool _isLoadingWishlist = true;

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  Future<void> _fetchWishlist() async {
    try {
      final response = await ApiService().getWishlist();
      if (response.statusCode == 200) {
        final List<dynamic> wishlistJson = response.data is List
            ? response.data
            : response.data['results'] ?? [];
        setState(() {
          _wishlistedProductIds = wishlistJson
              .map((json) => json['product'] as int)
              .toSet();
          _isLoadingWishlist = false;
        });
      }
    } catch (e) {
      print('Error fetching wishlist in search: $e');
      setState(() => _isLoadingWishlist = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Results for "${widget.query}"')),
      body: widget.searchResults.isEmpty
          ? const Center(child: Text('No products found.'))
          : _isLoadingWishlist
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(10.0),
              itemCount: widget.searchResults.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (ctx, i) {
                final product = widget.searchResults[i];
                return ProductCard(
                  product: product,
                  isWishlisted: _wishlistedProductIds.contains(product.id),
                );
              },
            ),
    );
  }
}
