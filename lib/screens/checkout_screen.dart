import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../models/address.dart';
import '../models/reward_configuration.dart';
import 'address_list_screen.dart';
import 'phone_verification_screen.dart';
import 'package:shop_easyy/providers/navigation_provider.dart';
import 'package:provider/provider.dart';

class CheckoutScreen extends StatefulWidget {
  final double totalAmount;
  final int retailerId;

  const CheckoutScreen({
    super.key,
    required this.totalAmount,
    required this.retailerId,
  });

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final ApiService _apiService = ApiService();
  Address? _selectedAddress;
  String _paymentMode = 'cash'; // Default to cash for now
  String _deliveryMode = 'delivery';
  bool _isLoading = false;

  // Rewards
  bool _useRewardPoints = false;
  RewardConfiguration? _rewardConfig;
  double _userRewardPoints = 0.0;
  double _discountFromPoints = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
    _fetchRewardData();
  }

  Future<void> _fetchAddresses() async {
    try {
      final response = await _apiService.getAddresses();
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        if (data.isNotEmpty) {
          final addresses = data.map((json) => Address.fromJson(json)).toList();

          // Find default address
          final defaultAddress = addresses.firstWhere(
            (addr) => addr.isDefault,
            orElse: () => addresses.first,
          );

          setState(() {
            _selectedAddress = defaultAddress;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching addresses: $e');
    }
  }

  Future<void> _fetchRewardData() async {
    try {
      // Fetch config
      final configResponse = await _apiService.fetchRewardConfiguration(
        widget.retailerId,
      );
      if (configResponse.statusCode == 200) {
        setState(() {
          _rewardConfig = RewardConfiguration.fromJson(configResponse.data);
        });
      }

      // Fetch user points for this retailer
      final loyaltyResponse = await _apiService.getCustomerLoyalty(
        widget.retailerId,
      );
      if (loyaltyResponse.statusCode == 200) {
        setState(() {
          final rawPoints = loyaltyResponse.data['points'];
          if (rawPoints != null) {
            if (rawPoints is num) {
              _userRewardPoints = rawPoints.toDouble();
            } else if (rawPoints is String) {
              _userRewardPoints = double.tryParse(rawPoints) ?? 0.0;
            } else {
              _userRewardPoints = 0.0;
            }
          } else {
            _userRewardPoints = 0.0;
          }
        });
      }

      _calculateDiscount();
    } catch (e) {
      debugPrint('Error fetching reward data: $e');
    }
  }

  void _calculateDiscount() {
    if (!_useRewardPoints || _rewardConfig == null || _userRewardPoints <= 0) {
      setState(() {
        _discountFromPoints = 0.0;
      });
      return;
    }

    double subtotal = widget.totalAmount;
    double deliveryFee = _deliveryMode == 'delivery' ? 50.0 : 0.0;
    double total = subtotal + deliveryFee;

    double maxByPercent = (total * _rewardConfig!.maxRewardUsagePercent) / 100;
    double maxByFlat = _rewardConfig!.maxRewardUsageFlat;
    double maxByBalance = _userRewardPoints * _rewardConfig!.conversionRate;

    double redeemable = [
      total,
      maxByPercent,
      maxByFlat,
      maxByBalance,
    ].reduce((curr, next) => curr < next ? curr : next);

    setState(() {
      _discountFromPoints = redeemable;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Delivery Address Section
            const Text(
              'Delivery Address',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: Text(
                  _selectedAddress != null
                      ? _selectedAddress!.title
                      : 'Select Address',
                ),
                subtitle: _selectedAddress != null
                    ? Text(
                        '${_selectedAddress!.addressLine1}, ${_selectedAddress!.city} - ${_selectedAddress!.pincode}',
                      )
                    : const Text('Please select a delivery address'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _selectAddress,
              ),
            ),
            const SizedBox(height: 24),

            // Delivery Mode
            const Text(
              'Delivery Mode',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            RadioListTile<String>(
              title: const Text('Home Delivery'),
              value: 'delivery',
              groupValue: _deliveryMode,
              onChanged: (value) => setState(() {
                _deliveryMode = value!;
                if (value == 'delivery') {
                  _paymentMode = 'cash';
                } else {
                  _paymentMode = 'cash_pickup';
                }
                _calculateDiscount();
              }),
            ),
            RadioListTile<String>(
              title: const Text('Store Pickup'),
              value: 'pickup',
              groupValue: _deliveryMode,
              onChanged: (value) => setState(() {
                _deliveryMode = value!;
                if (value == 'pickup') {
                  _paymentMode = 'cash_pickup';
                } else {
                  _paymentMode = 'cash';
                }
                _calculateDiscount();
              }),
            ),
            const SizedBox(height: 24),

            // Payment Mode
            const Text(
              'Payment Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            RadioListTile<String>(
              title: const Text('Cash on Delivery / Pay at Store'),
              value: _deliveryMode == 'delivery' ? 'cash' : 'cash_pickup',
              groupValue: _paymentMode,
              onChanged: (value) => setState(() => _paymentMode = value!),
            ),

            const SizedBox(height: 24),

            // Rewards Section
            if (_rewardConfig != null && _userRewardPoints > 0) ...[
              const Text(
                'Rewards',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              CheckboxListTile(
                title: Text(
                  'Use Reward Points (Available: $_userRewardPoints)',
                ),
                subtitle: Text('1 Point = ₹${_rewardConfig!.conversionRate}'),
                value: _useRewardPoints,
                onChanged: (value) {
                  setState(() {
                    _useRewardPoints = value!;
                    _calculateDiscount();
                  });
                },
              ),
              if (_useRewardPoints && _discountFromPoints > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Discount applied: ₹${_discountFromPoints.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.green),
                  ),
                ),
              const SizedBox(height: 24),
            ],

            // Order Summary
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal', style: TextStyle(fontSize: 16)),
                Text(
                  '₹${widget.totalAmount}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            // Add Delivery Fee logic here if needed (e.g. +50)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Delivery Fee', style: TextStyle(fontSize: 16)),
                Text(
                  _deliveryMode == 'delivery' ? '₹50.0' : '₹0.0',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            if (_discountFromPoints > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Points Discount',
                    style: TextStyle(fontSize: 16, color: Colors.green),
                  ),
                  Text(
                    '-₹${_discountFromPoints.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, color: Colors.green),
                  ),
                ],
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹${(widget.totalAmount + (_deliveryMode == 'delivery' ? 50 : 0) - _discountFromPoints).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _placeOrder,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Place Order', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddressListScreen(selectMode: true),
      ),
    );

    if (result != null && result is Address) {
      setState(() {
        _selectedAddress = result;
      });
    }
  }

  Future<void> _placeOrder() async {
    if (_deliveryMode == 'delivery' && _selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a delivery address')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final orderData = {
      "retailer_id": widget.retailerId,
      "address_id": _selectedAddress?.id,
      "delivery_mode": _deliveryMode,
      "payment_mode": _paymentMode,
      "use_reward_points": _useRewardPoints,
    };

    try {
      final response = await _apiService.placeOrder(orderData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully!')),
        );

        final orderId = response.data['id'];

        // 1. Switch index to Profile tab (4) in NavigationProvider
        context.read<NavigationProvider>().setIndex(4);

        // 2. Clear stack AND push order detail on the nested navigator
        // Since we are IN the nested navigator, we just need to ensure
        // we go to profile first then push order detail?
        // Actually HomeContainer will rebuild and show ProfileScreen if we set index.
        // But we want to SHOW the order detail on TOP of profile.

        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/profile', (route) => false);
        Navigator.of(context).pushNamed('/order-detail', arguments: orderId);
      }
    } on DioException catch (e) {
      String errorMessage = 'Failed to place order';
      bool isPhoneVerificationError = false;

      if (e.response != null && e.response!.data != null) {
        if (e.response!.data is Map && e.response!.data.containsKey('error')) {
          errorMessage = e.response!.data['error'];
          if (errorMessage.contains('verify your phone number')) {
            isPhoneVerificationError = true;
          }
        } else if (e.response!.data is Map &&
            e.response!.data.containsKey('detail')) {
          errorMessage = e.response!.data['detail'];
        }
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));

      if (isPhoneVerificationError) {
        _showVerificationDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: ${e.toString()}'),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Phone Verification Required'),
        content: const Text(
          'Your phone number needs to be verified before placing an order. Would you like to verify it now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _initiateVerification();
            },
            child: const Text('Verify Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _initiateVerification() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.requestPhoneVerification();
      if (response.statusCode == 200) {
        final phoneNumber = response.data['phone_number'];
        if (phoneNumber != null) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PhoneVerificationScreen(
                phoneNumber: phoneNumber,
                autoRequestOtp: false,
              ),
            ),
          );

          if (result == true) {
            _placeOrder(); // Auto-retry
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initiate verification: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
