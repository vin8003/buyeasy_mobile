import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isCodeSent = false;
  bool _isLoading = false;
  String? _verificationId;
  String? _idToken;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

  Future<void> _checkAccountExists() async {
    if (_formKey.currentState!.validate()) {
      final phone = '+91${_phoneController.text.trim()}';
      setState(() => _isLoading = true);
      try {
        final response = await _apiService.forgotPassword(phone);
        if (response.statusCode == 200) {
          await _sendFirebaseOtp();
        }
      } catch (e) {
        setState(() => _isLoading = false);
        String msg = "Failed to initiate password reset";
        if (e is DioException) {
          msg = e.response?.data['error'] ?? msg;
        }
        _showSnackBar(msg, isError: true);
      }
    }
  }

  Future<void> _sendFirebaseOtp() async {
    final phone = '+91${_phoneController.text.trim()}';
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
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
      _showSnackBar('Error sending OTP: $e', isError: true);
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      setState(() => _isLoading = true);
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        final idToken = await user.getIdToken();
        setState(() {
          _idToken = idToken;
          _isCodeSent = true;
          _isLoading = false;
        });
        _showSnackBar('OTP Verified! Please set new password.');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('OTP Verification Failed: $e', isError: true);
    }
  }

  Future<void> _verifyAndReset() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar("Passwords do not match", isError: true);
      return;
    }

    if (_otpController.text.isEmpty && _idToken == null) {
      _showSnackBar("Please enter OTP", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // 1. Verify OTP with Firebase if token not yet obtained
    if (_idToken == null) {
      if (_verificationId == null) {
        _showSnackBar(
          "Something went wrong. Please resend OTP.",
          isError: true,
        );
        setState(() => _isLoading = false);
        return;
      }

      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: _otpController.text.trim(),
        );

        final userCredential = await _auth.signInWithCredential(credential);
        final user = userCredential.user;
        if (user != null) {
          _idToken = await user.getIdToken();
        }
      } catch (e) {
        setState(() => _isLoading = false);
        _showSnackBar("Invalid OTP", isError: true);
        return;
      }
    }

    // 2. Call Backend Reset
    if (_idToken != null) {
      final phone = '+91${_phoneController.text.trim()}';
      try {
        final response = await _apiService.resetPassword(
          phone: phone,
          firebaseToken: _idToken!,
          newPassword: _passwordController.text.trim(),
        );

        if (response.statusCode == 200) {
          _showSnackBar("Password reset successfully! Please login.");
          if (mounted) {
            Navigator.pop(context);
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);
        String msg = "Failed to reset password";
        if (e is DioException) {
          msg = e.response?.data['error'] ?? msg;
        }
        _showSnackBar(msg, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  Image.asset('assets/images/logo.png', height: 80),
                  const SizedBox(height: 32),
                  if (!_isCodeSent) ...[
                    const Text(
                      'Forgot Password',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enter your registered phone number to receive an OTP',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixText: '+91 ',
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      validator: (value) => value!.isEmpty || value.length != 10
                          ? 'Enter valid 10-digit number'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _checkAccountExists,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Send OTP'),
                    ),
                  ] else ...[
                    const Text(
                      'Reset Password',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'OTP sent to +91${_phoneController.text}',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: 'OTP',
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      validator: (value) => (value!.isEmpty && _idToken == null)
                          ? 'Enter OTP'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Enter new password' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: !_isConfirmPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isConfirmPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _isConfirmPasswordVisible =
                                  !_isConfirmPasswordVisible;
                            });
                          },
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Confirm new password' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _verifyAndReset,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Reset Password'),
                    ),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isCodeSent = false;
                                _verificationId = null;
                                _idToken = null;
                              });
                            },
                      child: Text("Change Phone Number"),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
