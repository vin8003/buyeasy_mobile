import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _referralCode = '';

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
        setState(() {
          _referralCode = data['referral_code'] ?? '';
        });
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
                  // Refer & Earn Section
                  const Text(
                    'Refer & Earn',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'Share your referral code and earn points when your friends shop!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.blue),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _referralCode,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.copy,
                                  color: Colors.blue,
                                ),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _referralCode),
                                  );
                                  Fluttertoast.showToast(
                                    msg: "Referral code copied!",
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text('Referral Statistics'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      _showReferralStats();
                    },
                  ),
                  const SizedBox(height: 16),
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

  void _showReferralStats() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getReferralStats();
      setState(() => _isLoading = false);
      if (response.statusCode == 200) {
        final data = response.data;
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Referral Statistics',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem(
                        'Total Referrals',
                        data['total_referrals'].toString(),
                      ),
                      _buildStatItem(
                        'Successful',
                        data['successful_referrals'].toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Referral History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: data['referrals_detail'].isEmpty
                        ? const Center(child: Text('No referrals yet.'))
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: data['referrals_detail'].length,
                            separatorBuilder: (context, index) =>
                                const Divider(),
                            itemBuilder: (context, index) {
                              final ref = data['referrals_detail'][index];
                              return ListTile(
                                title: Text(ref['referee_name']),
                                subtitle: Text('at ${ref['retailer_name']}'),
                                trailing: ref['is_rewarded']
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : const Icon(
                                        Icons.pending,
                                        color: Colors.orange,
                                      ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(msg: "Error fetching stats: $e");
    }
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
