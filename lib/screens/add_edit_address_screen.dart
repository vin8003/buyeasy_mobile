import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/address.dart';
import 'location_picker_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/pincode_service.dart';

class AddEditAddressScreen extends StatefulWidget {
  final Address? address;
  final bool isCompulsory;

  const AddEditAddressScreen({
    super.key,
    this.address,
    this.isCompulsory = false,
  });

  @override
  _AddEditAddressScreenState createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  late TextEditingController _titleController;
  late TextEditingController _line1Controller;
  late TextEditingController _line2Controller;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _pincodeController;
  String _addressType = 'home';
  bool _isDefault = false;
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.address?.title ?? '');
    _line1Controller = TextEditingController(
      text: widget.address?.addressLine1 ?? '',
    );
    _line2Controller = TextEditingController(
      text: widget.address?.addressLine2 ?? '',
    );
    _cityController = TextEditingController(text: widget.address?.city ?? '');
    _stateController = TextEditingController(text: widget.address?.state ?? '');
    _pincodeController = TextEditingController(
      text: widget.address?.pincode ?? '',
    );
    _addressType = widget.address?.addressType ?? 'home';
    _isDefault = widget.address?.isDefault ?? false;
    _latitude = widget.address?.latitude;
    _longitude = widget.address?.longitude;

    _pincodeController.addListener(_onPincodeChanged);
  }

  void _onPincodeChanged() {
    final pincode = _pincodeController.text;
    if (pincode.length == 6) {
      _lookupPincode(pincode);
    }
  }

  Future<void> _lookupPincode(String pincode) async {
    final data = await PincodeService().getCityStateFromPincode(pincode);
    if (data != null && mounted) {
      setState(() {
        _cityController.text = data['city'] ?? _cityController.text;
        _stateController.text = data['state'] ?? _stateController.text;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final addressData = {
        'title': _titleController.text,
        'address_type': _addressType,
        'address_line1': _line1Controller.text,
        'address_line2': _line2Controller.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'pincode': _pincodeController.text,
        'is_default': _isDefault,
        'latitude': _latitude != null
            ? double.parse(_latitude!.toStringAsFixed(8))
            : null,
        'longitude': _longitude != null
            ? double.parse(_longitude!.toStringAsFixed(8))
            : null,
      };

      try {
        if (widget.address == null) {
          await _apiService.addAddress(addressData);
        } else {
          await _apiService.updateAddress(widget.address!.id!, addressData);
        }
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save address: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.address == null ? 'Add Address' : 'Edit Address'),
        automaticallyImplyLeading: !widget.isCompulsory,
      ),
      body: PopScope(
        canPop: !widget.isCompulsory,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title (e.g., My Home)',
                  ),
                  validator: (value) =>
                      value!.isEmpty ? 'Please enter a title' : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _addressType,
                  decoration: const InputDecoration(labelText: 'Address Type'),
                  items: ['home', 'office', 'other'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() => _addressType = newValue!);
                  },
                ),
                TextFormField(
                  controller: _line1Controller,
                  decoration: const InputDecoration(
                    labelText: 'Address Line 1',
                  ),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _line2Controller,
                  decoration: const InputDecoration(
                    labelText: 'Address Line 2 (Optional)',
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(labelText: 'City'),
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(labelText: 'State'),
                        validator: (value) =>
                            value!.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _pincodeController,
                  decoration: const InputDecoration(labelText: 'Pincode'),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      value!.length != 6 ? 'Enter valid 6-digit pincode' : null,
                ),
                CheckboxListTile(
                  title: const Text('Set as Default Address'),
                  value: _isDefault,
                  onChanged: (bool? value) {
                    setState(() => _isDefault = value!);
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final LatLng? result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LocationPickerScreen(
                          initialLocation:
                              _latitude != null && _longitude != null
                              ? LatLng(_latitude!, _longitude!)
                              : null,
                        ),
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        _latitude = result.latitude;
                        _longitude = result.longitude;
                      });
                    }
                  },
                  icon: const Icon(Icons.map),
                  label: Text(
                    _latitude != null
                        ? 'Location Selected (${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})'
                        : 'Select Location from Map',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Address'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
