import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final bool isWishlisted;

  const ProductCard({
    Key? key,
    required this.product,
    this.isWishlisted = false,
  }) : super(key: key);

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late bool _isWishlisted;

  @override
  void initState() {
    super.initState();
    _isWishlisted = widget.isWishlisted;
  }

  Future<void> _addToCart(BuildContext context) async {
    try {
      final response = await ApiService().addToCart(widget.product.id, 1);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.product.name} added to cart'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add to cart'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleWishlist() async {
    setState(() {
      _isWishlisted = !_isWishlisted;
    });

    try {
      if (_isWishlisted) {
        await ApiService().addToWishlist(widget.product.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.product.name} added to wishlist'),
              backgroundColor: Colors.pinkAccent,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        await ApiService().removeFromWishlist(widget.product.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.product.name} removed from wishlist'),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      // Revert if API fails
      setState(() {
        _isWishlisted = !_isWishlisted;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update wishlist'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final String imageUrl = product.image.startsWith('http')
        ? product.image
        : 'http://127.0.0.1:8000${product.image}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[100],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[100],
                        child: const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                if (product.discountPercent > 0)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${product.discountPercent.toStringAsFixed(0)}% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: IconButton(
                    icon: Icon(
                      _isWishlisted ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: _isWishlisted ? Colors.pinkAccent : Colors.black54,
                    ),
                    onPressed: _toggleWishlist,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            product.unit,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${product.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              if (product.discountPercent > 0)
                                Text(
                                  '₹${product.mrp.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => _addToCart(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 18,
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
