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
  // String _referralCode = ''; // Removed as unused
  List<dynamic> _loyaltyPoints = [];
  List<dynamic> _retailers = [];
  int? _selectedRetailerId;
  final TextEditingController _applyCodeController = TextEditingController();
  bool _isApplyingCode = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchLoyaltyPoints();
    _fetchRetailers();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneNumberController.dispose();
    _applyCodeController.dispose();
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
        // setState(() {
        //   _referralCode = data['referral_code'] ?? '';
        // });
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

  Future<void> _fetchRetailers() async {
    try {
      final response = await _apiService.getRetailers();
      if (response.statusCode == 200) {
        setState(() {
          _retailers = response.data['results'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error fetching retailers: $e');
    }
  }

  Future<void> _applyReferralCode() async {
    final code = _applyCodeController.text.trim();
    if (code.isEmpty) {
      Fluttertoast.showToast(msg: "Please enter a referral code");
      return;
    }
    if (_selectedRetailerId == null) {
      Fluttertoast.showToast(msg: "Please select a retailer");
      return;
    }

    setState(() => _isApplyingCode = true);
    try {
      final response = await _apiService.applyReferralCode(
        code,
        _selectedRetailerId!,
      );
      if (response.statusCode == 201) {
        Fluttertoast.showToast(
          msg: response.data['message'],
          backgroundColor: Colors.green,
        );
        _applyCodeController.clear();
      }
    } on DioException catch (e) {
      final errorMsg = e.response?.data['error'] ?? 'Failed to apply code.';
      Fluttertoast.showToast(msg: errorMsg, backgroundColor: Colors.red);
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'An unexpected error occurred.',
        backgroundColor: Colors.red,
      );
    } finally {
      setState(() => _isApplyingCode = false);
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty && _firstNameController.text.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _fetchProfile,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.1),
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_firstNameController.text} ${_lastNameController.text}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _emailController.text,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Account Settings Card
                  _buildSectionCard(
                    title: 'Account Settings',
                    icon: Icons.settings,
                    children: [
                      ExpansionTile(
                        leading: const Icon(Icons.edit_note),
                        title: const Text('Edit Personal Info'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  TextFormField(
                                    controller: _firstNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'First Name',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your first name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _lastNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Last Name',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your last name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _emailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      border: OutlineInputBorder(),
                                    ),
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
                                  const SizedBox(height: 16),
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
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _saveProfile,
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Update Profile'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // My Activity Card
                  _buildSectionCard(
                    title: 'My Activity',
                    icon: Icons.history,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.shopping_bag_outlined),
                        title: const Text('Order History'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => Navigator.pushNamed(context, '/orders'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined),
                        title: const Text('My Addresses'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddressListScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // Rewards & Referrals Card
                  _buildSectionCard(
                    title: 'Rewards & Referrals',
                    icon: Icons.card_giftcard,
                    children: [
                      if (_loyaltyPoints.isNotEmpty)
                        ExpansionTile(
                          leading: const Icon(Icons.stars, color: Colors.amber),
                          title: const Text('My Reward Points'),
                          subtitle: Text('${_loyaltyPoints.length} Shops'),
                          children: [
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _loyaltyPoints.length,
                              separatorBuilder: (ctx, i) => const Divider(),
                              itemBuilder: (ctx, i) {
                                final point = _loyaltyPoints[i];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                  ),
                                  title: Text(
                                    point['retailer_name'] ??
                                        'Unknown Retailer',
                                  ),
                                  trailing: Text(
                                    '${double.parse(point['points'].toString()).toStringAsFixed(2)} pts',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ExpansionTile(
                        leading: const Icon(Icons.person_add_alt_1_outlined),
                        title: const Text('Apply Referral Code'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Enter a referral code to get points on your first purchase.',
                                  style: TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<int>(
                                  initialValue: _selectedRetailerId,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Retailer',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: _retailers.map((retailer) {
                                    return DropdownMenuItem<int>(
                                      value: retailer['id'],
                                      child: Text(retailer['shop_name']),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedRetailerId = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _applyCodeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Referral Code',
                                    border: OutlineInputBorder(),
                                  ),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _isApplyingCode
                                      ? null
                                      : _applyReferralCode,
                                  child: _isApplyingCode
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Apply'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ListTile(
                        leading: const Icon(Icons.bar_chart_outlined),
                        title: const Text('Referral Statistics'),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _showReferralStats,
                      ),
                    ],
                  ),

                  // Logout Card
                  _buildSectionCard(
                    title: 'App',
                    icon: Icons.apps,
                    children: [
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
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Logout'),
                              content: const Text(
                                'Are you sure you want to logout?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
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
