import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'package:dio/dio.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final bool autoRequestOtp;

  const PhoneVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.autoRequestOtp = true,
  });

  @override
  _PhoneVerificationScreenState createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _otpController = TextEditingController();
  late final TextEditingController _phoneController;
  final _apiService = ApiService();

  bool _isLoading = false;
  bool _isCodeSent = false;
  // Trigger auto-send on init only once
  bool _hasAutoSent = false;

  @override
  void initState() {
    super.initState();
    String phone = widget.phoneNumber;
    // ensure starts with +91 or appropriate code if not present
    if (phone.startsWith('+91')) {
      _phoneController = TextEditingController(text: phone.substring(3));
    } else {
      _phoneController = TextEditingController(text: phone);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.autoRequestOtp && !_hasAutoSent) {
        _requestOtp();
        _hasAutoSent = true;
      } else if (!widget.autoRequestOtp) {
        // If auto-send is disabled, we assume the code was already sent by the previous screen.
        // We should update the UI to show code is sent.
        setState(() {
          _isCodeSent = true;
          _hasAutoSent = true; // Prevent future auto-sends if state changes
        });
      }
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber => '+91${_phoneController.text.trim()}';

  Future<void> _requestOtp() async {
    if (_phoneController.text.trim().length != 10) {
      _showSnackBar(
        'Please enter a valid 10-digit phone number',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Backend Request for OTP
      final response = await _apiService.requestPhoneVerification();

      if (response.statusCode == 200) {
        setState(() {
          _isCodeSent = true;
          _isLoading = false;
        });
        _showSnackBar(response.data['message'] ?? 'OTP sent successfully');
      }
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      // Handle cases where phone is already verified or other errors
      _showSnackBar(
        e.response?.data['error'] ?? 'Failed to send OTP',
        isError: true,
      );
      if (e.response?.data['message'] == 'Phone number already verified') {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error sending OTP: $e', isError: true);
    }
  }

  Future<void> _submitOtp() async {
    final smsCode = _otpController.text.trim();
    if (smsCode.length != 6) {
      _showSnackBar('Please enter a valid 6-digit OTP', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.verifyOtp(
        _fullPhoneNumber,
        otp: smsCode,
      );

      if (response.statusCode == 200) {
        if (response.data['tokens'] != null) {
          await _apiService.setAuthToken(
            response.data['tokens']['access'],
            response.data['tokens']['refresh'],
          );
        }
        _showSnackBar('Phone verified successfully!');
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar(
        e.response?.data['error'] ?? 'Verification failed',
        isError: true,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('An unexpected error occurred: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
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
              enabled: !_isCodeSent,
            ),
            if (_isCodeSent) ...[
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
            ],
            const SizedBox(height: 24),

            if (_isCodeSent)
              ElevatedButton(
                onPressed: _isLoading ? null : _submitOtp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Verify', style: TextStyle(fontSize: 18)),
              )
            else
              ElevatedButton(
                onPressed: _isLoading ? null : _requestOtp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Send OTP', style: TextStyle(fontSize: 18)),
              ),

            const SizedBox(height: 16),
            if (_isCodeSent)
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _isCodeSent = false;
                          _isLoading = false;
                        });
                      },
                child: const Text('Change Number / Resend'),
              ),
          ],
        ),
      ),
    );
  }
}
