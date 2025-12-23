// cart_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  final int? retailerId;

  const CartScreen({super.key, this.retailerId});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isLoading = true;
  double _totalPrice = 0.0;
  List<CartItem> cartItems = [];

  @override
  void initState() {
    super.initState();
    if (widget.retailerId != null) {
      _fetchCart();
    } else {
      _isLoading = false;
    }
  }

  @override
  void didUpdateWidget(CartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.retailerId != oldWidget.retailerId) {
      if (widget.retailerId != null) {
        _fetchCart();
      } else {
        setState(() => cartItems = []);
      }
    }
  }

  Future<void> _fetchCart() async {
    if (widget.retailerId == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService().getCart(widget.retailerId!);
      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          cartItems = (data['items'] as List).map((item) {
            return CartItem(
              id: item['id'],
              productId: item['product'], // Product ID
              name: item['product_name'],
              price: double.parse(item['product_price'].toString()),
              quantity: item['quantity'],
              imageUrl: item['product_image'] != null
                  ? (item['product_image'].toString().startsWith('http')
                        ? item['product_image']
                        : 'http://127.0.0.1:8000${item['product_image']}')
                  : 'https://via.placeholder.com/150',
            );
          }).toList();
          _totalPrice = double.parse(
            data['total_amount'].toString(),
          ); // Use total_amount from serializer
        });
      }
    } catch (e) {
      print("Error fetching cart: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load cart')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateQuantity(int index, int quantity) async {
    // Optimistic update
    final item = cartItems[index];
    final oldQuantity = item.quantity;

    setState(() {
      item.quantity = quantity;
    });

    try {
      await ApiService().updateCartItem(item.id, quantity);
      _fetchCart(); // Refresh cart to get updated total price
    } catch (e) {
      // Revert on error
      setState(() {
        item.quantity = oldQuantity;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update quantity: $e')));
    }
  }

  void incrementQty(int index) {
    _updateQuantity(index, cartItems[index].quantity + 1);
  }

  void decrementQty(int index) {
    if (cartItems[index].quantity > 1) {
      _updateQuantity(index, cartItems[index].quantity - 1);
    }
  }

  Future<void> removeItem(int index) async {
    final item = cartItems[index];
    setState(() {
      cartItems.removeAt(index);
    });

    try {
      await ApiService().removeCartItem(item.id);
      _fetchCart();
    } catch (e) {
      _fetchCart(); // Refresh to restore state on error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to remove item')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.retailerId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Cart')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.store_mall_directory,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please select a retailer to view cart',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Cart')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Cart')),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cartItems.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = cartItems[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                child: const Icon(Icons.image_not_supported),
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
                              const SizedBox(height: 6),
                              Text(
                                '₹${item.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    onPressed: () => decrementQty(index),
                                  ),
                                  Text(
                                    '${item.quantity}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () => incrementQty(index),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => removeItem(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '₹${_totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      if (cartItems.isEmpty) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CheckoutScreen(
                            totalAmount: _totalPrice,
                            retailerId: widget.retailerId!,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'Proceed to Checkout',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CartItem {
  int id;
  int productId;
  String name;
  double price;
  int quantity;
  String imageUrl;

  CartItem({
    required this.id,
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    required this.imageUrl,
  });
}
