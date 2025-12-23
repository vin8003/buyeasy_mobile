import 'package:flutter/material.dart';

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    List<WishlistItem> wishlistItems = [
      WishlistItem(
        name: 'Moong Dal',
        price: 90.0,
        imageUrl: 'https://via.placeholder.com/100',
      ),
      WishlistItem(
        name: 'Fortune Sunlite',
        price: 140.0,
        imageUrl: 'https://via.placeholder.com/100',
      ),
      WishlistItem(
        name: 'Turmeric Powder',
        price: 90.0,
        imageUrl: 'https://via.placeholder.com/100',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('My Wishlist')),
      body: wishlistItems.isEmpty
          ? const Center(
              child: Text(
                'Your Wishlist is empty!',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: wishlistItems.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = wishlistItems[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, size: 40),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₹${item.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        // TODO: remove from wishlist logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${item.name} removed from wishlist'),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class WishlistItem {
  String name;
  double price;
  String imageUrl;

  WishlistItem({
    required this.name,
    required this.price,
    required this.imageUrl,
  });
}
