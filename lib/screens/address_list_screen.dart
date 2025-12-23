import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/address.dart';
import 'add_edit_address_screen.dart';

class AddressListScreen extends StatefulWidget {
  final bool selectMode;

  const AddressListScreen({Key? key, this.selectMode = false})
    : super(key: key);

  @override
  _AddressListScreenState createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  final ApiService _apiService = ApiService();
  List<Address> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getAddresses();
      if (response.statusCode == 200) {
        setState(() {
          _addresses = (response.data as List)
              .map((json) => Address.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load addresses: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAddress(int id) async {
    try {
      await _apiService.deleteAddress(id);
      _fetchAddresses();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Address deleted')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete address: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectMode ? 'Select Address' : 'My Addresses'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
          ? const Center(child: Text('No addresses found. Add one!'))
          : ListView.builder(
              itemCount: _addresses.length,
              itemBuilder: (context, index) {
                final address = _addresses[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      address.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${address.addressLine1}, ${address.addressLine2}',
                        ),
                        Text(
                          '${address.city}, ${address.state} - ${address.pincode}',
                        ),
                      ],
                    ),
                    trailing: widget.selectMode
                        ? const Icon(Icons.check_circle_outline)
                        : IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteAddress(address.id!),
                          ),
                    onTap: () {
                      if (widget.selectMode) {
                        Navigator.pop(context, address);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AddEditAddressScreen(address: address),
                          ),
                        ).then((_) => _fetchAddresses());
                      }
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditAddressScreen(),
            ),
          ).then((_) => _fetchAddresses());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
