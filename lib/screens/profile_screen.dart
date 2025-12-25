import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import 'address_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  // Controllers for text fields
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneNumberController = TextEditingController();

  bool _isLoading = true;
  String _errorMessage = '';

  List<dynamic> _loyaltyPoints = [];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchLoyaltyPoints();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final response = await _apiService.fetchUserProfile();
      if (response.statusCode == 200) {
        final data = response.data;
        _firstNameController.text = data['first_name'] ?? '';
        _lastNameController.text = data['last_name'] ?? '';
        _emailController.text = data['email'] ?? '';
        String phone = data['phone_number'] ?? '';
        if (phone.startsWith('+91')) {
          phone = phone.substring(3);
        }
        _phoneNumberController.text = phone;
      } else {
        throw 'Failed to load profile';
      }
    } on DioException catch (e) {
      _errorMessage =
          e.response?.data['detail'] ??
          'An error occurred while fetching profile.';
      Fluttertoast.showToast(msg: _errorMessage);
    } catch (e) {
      _errorMessage = 'An unexpected error occurred.';
      Fluttertoast.showToast(msg: _errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLoyaltyPoints() async {
    try {
      final response = await _apiService.getAllCustomerLoyalty();
      if (response.statusCode == 200) {
        setState(() {
          _loyaltyPoints = response.data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching loyalty points: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final profileData = {
        'first_name': _firstNameController.text,
        'last_name': _lastNameController.text,
        // Email is often not editable, but including it based on your original code's intent
        'email': _emailController.text,
      };

      try {
        final response = await _apiService.updateUserProfile(profileData);

        if (response.statusCode == 200) {
          Fluttertoast.showToast(
            msg: "Profile updated successfully!",
            backgroundColor: Colors.green,
          );
        } else {
          throw 'Failed to save profile';
        }
      } on DioException catch (e) {
        _errorMessage =
            e.response?.data['detail'] ??
            'An error occurred while saving profile.';
        Fluttertoast.showToast(msg: _errorMessage, backgroundColor: Colors.red);
      } catch (e) {
        _errorMessage = 'An unexpected error occurred.';
        Fluttertoast.showToast(msg: _errorMessage, backgroundColor: Colors.red);
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Profile')),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty && _firstNameController.text.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage, style: TextStyle(color: Colors.red)),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _fetchProfile,
                    child: Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Edit Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TextFormField(
                          controller: _firstNameController,
                          decoration: InputDecoration(labelText: 'First Name'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your first name';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _lastNameController,
                          decoration: InputDecoration(labelText: 'Last Name'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your last name';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(labelText: 'Email'),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(
                              r'^[^@]+@[^@]+\.[^@]+',
                            ).hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneNumberController,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            prefixText: '+91 ',
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          readOnly: true,
                        ),
                        SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveProfile,
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text('Save Profile'),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 48),
                  // Reward Points Section
                  if (_loyaltyPoints.isNotEmpty) ...[
                    const Text(
                      'Your Reward Points',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _loyaltyPoints.length,
                        separatorBuilder: (ctx, i) => const Divider(),
                        itemBuilder: (ctx, i) {
                          final point = _loyaltyPoints[i];
                          return ListTile(
                            leading: const Icon(
                              Icons.loyalty,
                              color: Colors.amber,
                            ),
                            title: Text(
                              point['retailer_name'] ?? 'Unknown Retailer',
                            ),
                            trailing: Text(
                              '${double.parse(point['points'].toString()).toStringAsFixed(2)} pts',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Navigation Options
                  ListTile(
                    leading: const Icon(Icons.location_on),
                    title: const Text('My Addresses'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddressListScreen(),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('Order History'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.pushNamed(context, '/orders');
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      // Confirm Logout
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Logout'),
                          content: const Text(
                            'Are you sure you want to logout?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                'Logout',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await _apiService.logout();
                      }
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
