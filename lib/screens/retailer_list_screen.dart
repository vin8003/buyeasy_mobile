import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/retailer.dart';

class RetailerListScreen extends StatefulWidget {
  final Function(Retailer) onRetailerSelected;

  const RetailerListScreen({super.key, required this.onRetailerSelected});

  @override
  _RetailerListScreenState createState() => _RetailerListScreenState();
}

class _RetailerListScreenState extends State<RetailerListScreen> {
  final ApiService _apiService = ApiService();
  List<Retailer> _retailers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRetailers();
  }

  Future<void> _fetchRetailers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getRetailers();
      if (response.statusCode == 200) {
        setState(() {
          _retailers = (response.data['results'] as List)
              .map((json) => Retailer.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load retailers: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select a Retailer')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _retailers.isEmpty
          ? const Center(child: Text('No retailers found near you.'))
          : ListView.builder(
              itemCount: _retailers.length,
              itemBuilder: (context, index) {
                final retailer = _retailers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: InkWell(
                    onTap: () => widget.onRetailerSelected(retailer),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            retailer.shopName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            retailer.businessType,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                size: 16,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(retailer.averageRating.toString()),
                              const SizedBox(width: 16),
                              const Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text('${retailer.city}, ${retailer.state}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (retailer.offersDelivery)
                                Chip(
                                  label: const Text(
                                    'Delivery',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor: Colors.green[100],
                                  padding: EdgeInsets.zero,
                                ),
                              if (retailer.offersPickup)
                                Chip(
                                  label: const Text(
                                    'Pickup',
                                    style: TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor: Colors.blue[100],
                                  padding: EdgeInsets.zero,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
