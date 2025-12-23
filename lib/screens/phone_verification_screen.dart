import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'package:dio/dio.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const PhoneVerificationScreen({Key? key, required this.phoneNumber})
    : super(key: key);

  @override
  _PhoneVerificationScreenState createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _otpController = TextEditingController();
  late final TextEditingController _phoneController;
  final _apiService = ApiService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    String phone = widget.phoneNumber;
    if (phone.startsWith('+91')) {
      phone = phone.substring(3);
    }
    _phoneController = TextEditingController(text: phone);
  }

  @override
  void dispose() {
    _otpController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Phone')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter the OTP sent to your phone number',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter 10 digit number',
                prefixText: '+91 ',
                counterText: '',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'OTP Code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              maxLength: 6,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Verify', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isLoading ? null : _resendOtp,
              child: const Text('Update & Resend OTP'),
            ),
            const SizedBox(height: 8),
            const Text(
              'If you entered the wrong number, you can edit it above and click "Update & Resend OTP".',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    final phone = '+91${_phoneController.text.trim()}';

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.verifyOtp(phone, otp);
      if (response.statusCode == 200) {
        // Update tokens if provided
        if (response.data['tokens'] != null) {
          await _apiService.setAuthToken(
            response.data['tokens']['access'],
            response.data['tokens']['refresh'],
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Phone verified successfully! You can now place orders.',
            ),
          ),
        );
        Navigator.pop(context, true); // Return success
      }
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.response?.data['error'] ?? 'Verification failed'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    final newPhone = '+91${_phoneController.text.trim()}';

    if (_phoneController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit phone number'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. If phone number changed, update profile first
      if (newPhone != widget.phoneNumber) {
        final updateResponse = await _apiService.updateUserProfile({
          'phone_number': newPhone,
        });

        if (updateResponse.statusCode != 200) {
          throw 'Failed to update phone number';
        }
      }

      // 2. Request new OTP
      final response = await _apiService.requestPhoneVerification();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('OTP sent successfully')));
      }
    } catch (e) {
      String errorMessage = 'Failed to resend OTP';
      if (e is DioException && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map) {
          errorMessage =
              data['phone_number']?[0] ?? data['error'] ?? errorMessage;
        }
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
