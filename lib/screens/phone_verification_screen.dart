import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'package:dio/dio.dart';

class PhoneVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const PhoneVerificationScreen({super.key, required this.phoneNumber});

  @override
  _PhoneVerificationScreenState createState() =>
      _PhoneVerificationScreenState();
}

class _PhoneVerificationScreenState extends State<PhoneVerificationScreen> {
  final _otpController = TextEditingController();
  late final TextEditingController _phoneController;
  final _apiService = ApiService();
  final _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _isCodeSent = false;
  String? _verificationId;
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    String phone = widget.phoneNumber;
    // ensure starts with +91 or appropriate code if not present
    // The previous logic stripped +91, but Firebase needs it.
    // However, for display, we might want to strip it.
    // Let's keep it complete for the controller but stripping prefix for display might be confusing if user edits.
    // Let's assume input is full E.164 or needs to be.
    // If incoming is +919876543210.

    if (phone.startsWith('+91')) {
      _phoneController = TextEditingController(text: phone.substring(3));
    } else {
      _phoneController = TextEditingController(text: phone);
    }

    // Auto-start verification? Maybe or wait for user to click "Send OTP"
    // Usually better to auto-start if passed from signup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verifyPhoneNumber();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String get _fullPhoneNumber => '+91${_phoneController.text.trim()}';

  Future<void> _verifyPhoneNumber() async {
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
      await _auth.verifyPhoneNumber(
        phoneNumber: _fullPhoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android auto-verification
          await _signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            _isLoading = false;
          });
          _showSnackBar('Verification failed: ${e.message}', isError: true);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
            _isCodeSent = true;
            _isLoading = false;
          });
          _showSnackBar('OTP sent successfully');
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error initiating verification: $e', isError: true);
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final idToken = await user.getIdToken();
        if (idToken != null) {
          await _verifyBackend(idToken);
        } else {
          setState(() => _isLoading = false);
          _showSnackBar('Error: Failed to retrieve ID Token', isError: true);
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Sign in failed: ${e.message}', isError: true);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  Future<void> _verifyBackend(String idToken) async {
    try {
      // Call backend with Firebase ID Token
      final response = await _apiService.verifyOtp(
        _fullPhoneNumber,
        firebaseToken: idToken,
      );

      if (response.statusCode == 200) {
        // Update tokens logic
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
        e.response?.data['error'] ?? 'Backend verification failed',
        isError: true,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('An unexpected error occurred: $e', isError: true);
    }
  }

  void _submitOtp() async {
    if (_verificationId == null) {
      _showSnackBar('Please request OTP first', isError: true);
      return;
    }

    final smsCode = _otpController.text.trim();
    if (smsCode.length != 6) {
      _showSnackBar('Please enter a valid 6-digit OTP', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );

    await _signInWithCredential(credential);
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
              enabled:
                  !_isCodeSent, // Disable editing after sending? Or allow retry.
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
                onPressed: _isLoading ? null : _verifyPhoneNumber,
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

            const SizedBox(height: 8),
            const Text(
              'Verification provided by Firebase.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
