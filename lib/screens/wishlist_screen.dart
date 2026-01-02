import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../models/wishlist_item.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  _WishlistScreenState createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final ApiService _apiService = ApiService();
  List<WishlistItem> _wishlist = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  Future<void> _fetchWishlist() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getWishlist();
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['results'] ?? response.data;
        setState(() {
          _wishlist = data.map((json) => WishlistItem.fromJson(json)).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load wishlist: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFromWishlist(WishlistItem item) async {
    try {
      final response = await _apiService.removeFromWishlist(item.productId);
      if (response.statusCode == 200) {
        setState(() {
          _wishlist.removeWhere((i) => i.id == item.id);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Removed from wishlist')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to remove: $e')));
    }
  }

  Future<void> _addToCart(WishlistItem item) async {
    try {
      final response = await _apiService.addToCart(item.productId, 1);
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Added to cart')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add to cart: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Wishlist')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _wishlist.isEmpty
          ? const Center(child: Text('Your wishlist is empty'))
          : ListView.builder(
              itemCount: _wishlist.length,
              itemBuilder: (context, index) {
                final item = _wishlist[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: item.productImage != null
                        ? CachedNetworkImage(
                            imageUrl: ApiService().formatImageUrl(
                              item.productImage,
                            ),
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey[200]),
                            errorWidget: (ctx, _, __) =>
                                const Icon(Icons.image_not_supported),
                          )
                        : const Icon(Icons.shopping_bag),
                    title: Text(item.productName),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Retailer: ${item.retailerName}'),
                        Text(
                          '₹${item.productPrice}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.shopping_cart,
                            color: Colors.green,
                          ),
                          onPressed: () => _addToCart(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeFromWishlist(item),
                        ),
                      ],
                    ),
                    onTap: () {
                      // Navigate to product detail if possible.
                      // Need to pass full Product object which we don't have here seamlessly.
                      // For now, just showing details.
                    },
                  ),
                );
              },
            ),
    );
  }
}
