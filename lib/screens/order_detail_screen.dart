import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  _OrderDetailScreenState createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _order;
  bool _isLoading = true;
  StreamSubscription? _notificationSubscription;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetail();
    _listenForRefreshNotifications();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && _order != null) {
        final status = _order!['status'];
        // Stop polling if order is in terminal state
        if (status == 'delivered' ||
            status == 'cancelled' ||
            status == 'returned') {
          _stopPolling();
          return;
        }
        _fetchOrderDetail(isPolling: true);
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void _listenForRefreshNotifications() {
    _notificationSubscription = NotificationService().updateStream.listen((
      data,
    ) {
      if (data['event'] == 'order_refresh' &&
          data['order_id'] == widget.orderId.toString()) {
        if (mounted) {
          _fetchOrderDetail();
        }
      }
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _stopPolling();
    super.dispose();
  }

  Future<void> _fetchOrderDetail({bool isPolling = false}) async {
    if (!isPolling) {
      setState(() => _isLoading = true);
    }

    try {
      // Use last_updated to optimize if polling
      String? lastUpdated;
      if (isPolling && _order != null) {
        lastUpdated = _order!['updated_at'];
      }

      final response = await _apiService.getOrderDetail(
        widget.orderId,
        lastUpdated: lastUpdated,
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _order = response.data;
          });
        }
      } else if (response.statusCode == 304) {
        // Not modified, no need to update state
      }
    } catch (e) {
      if (mounted && !isPolling) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load order details: $e')),
        );
      }
    } finally {
      if (mounted && !isPolling) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _respondToModification(String action) async {
    try {
      final response = await _apiService.confirmOrderModification(
        widget.orderId,
        action,
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order modification ${action}ed')),
        );
        _fetchOrderDetail();
      } else {
        throw Exception('Failed to update');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _cancelOrder() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.cancelOrder(widget.orderId);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully')),
        );
        _fetchOrderDetail();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to cancel order: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'processing':
        return Colors.blue;
      case 'confirmed':
        return Colors.orange;
      case 'waiting_for_customer_approval':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: Text('Order not found.')),
      );
    }

    final date = DateTime.parse(_order!['created_at']);
    final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(date);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${_order!['order_number']}'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_order!['status'] == 'waiting_for_customer_approval') ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Price/Items Updated by Retailer',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.purple,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The retailer has modified this order. Please review the new prices and items below. Accept to proceed or Reject to cancel the order.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _respondToModification('reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _respondToModification('accept'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Accept'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            // Status Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Status',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _order!['status'].toString().toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(_order!['status']),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.receipt_long,
                      size: 40,
                      color: Colors.blueGrey,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Retailer Info
            const Text(
              'Store Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 1,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.store, color: Colors.white),
                ),
                title: Text(
                  _order!['retailer_name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _order!['retailer_address'] ?? 'Address not available',
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          _order!['retailer_phone'] ?? 'Phone not available',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Item List
            const Text(
              'Order Items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: (_order!['items'] as List).length,
              itemBuilder: (context, index) {
                final item = _order!['items'][index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          ApiService().formatImageUrl(item['product_image']),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image_not_supported),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['product_name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${item['quantity']} x ₹${item['unit_price']} / ${item['product_unit']}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₹${item['total_price']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 32),

            // Price Summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal'),
                Text('₹${_order!['subtotal']}'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Delivery Fee'),
                Text('₹${_order!['delivery_fee']}'),
              ],
            ),
            if (double.parse((_order!['discount_amount'] ?? '0').toString()) >
                0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Discount', style: TextStyle(color: Colors.green)),
                  Text(
                    '-₹${_order!['discount_amount']}',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ],
            if (double.parse(
                  (_order!['discount_from_points'] ?? '0').toString(),
                ) >
                0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Points Discount',
                    style: TextStyle(color: Colors.green),
                  ),
                  Text(
                    '-₹${_order!['discount_from_points']}',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ],
            if (double.tryParse(
                      (_order!['points_redeemed'] ?? '0').toString(),
                    ) !=
                    null &&
                double.parse((_order!['points_redeemed'] ?? '0').toString()) >
                    0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Points Redeemed',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                  Text(
                    '${double.parse(_order!['points_redeemed'].toString()).toInt()} pts',
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${_order!['total_amount']}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // Order Info
            Text(
              'Order Info',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Placed On', formattedDate),
            _buildInfoRow(
              'Payment',
              _order!['payment_mode']
                  .toString()
                  .replaceAll('_', ' ')
                  .toUpperCase(),
            ),
            _buildInfoRow(
              'Delivery',
              _order!['delivery_mode'].toString().toUpperCase(),
            ),
            if (_order!['delivery_address_text'] != null)
              _buildInfoRow('Address', _order!['delivery_address_text']),

            // Cancel Button
            if (_order!['status'] == 'pending' ||
                _order!['status'] == 'waiting_for_customer_approval') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _cancelOrder,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel Order'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 30),

            // Rating Button
            if (_order!['status'] == 'delivered') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showRatingDialog,
                  icon: const Icon(Icons.star_rate_rounded),
                  label: const Text('Rate Store'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog() {
    int localRating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Rate Store'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('How was your experience with this store?'),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return IconButton(
                        icon: Icon(
                          index < localRating
                              ? Icons.star_rate_rounded
                              : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 36,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            localRating = index + 1;
                          });
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: commentController,
                    decoration: const InputDecoration(
                      hintText: 'Add a comment (optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: localRating == 0
                      ? null
                      : () async {
                          Navigator.pop(context);
                          _submitReview(localRating, commentController.text);
                        },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitReview(int rating, String comment) async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.createRetailerReview(
        _order!['retailer'],
        rating,
        comment,
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your review!')),
        );
        _fetchOrderDetail();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error submitting review: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
