import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  String? _token;

  final String _baseUrl = Platform.isAndroid
      ? 'http://10.0.2.2:8000/api'
      : 'http://127.0.0.1:8000/api';

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(milliseconds: 5000),
        receiveTimeout: const Duration(milliseconds: 5000),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null && _token!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          print('API Error: ${e.response?.data ?? e.message}');
          return handler.next(e);
        },
      ),
    );
  }

  Future<void> setAuthToken(String? token) async {
    _token = token;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove('access_token');
    } else {
      await prefs.setString('access_token', token);
    }
  }

  // --- Auth Methods ---
  Future<Response> login(String phone, String password) {
    _token = null; // Clear token before login
    return _dio.post(
      '/auth/customer/login-with-password/',
      data: {'phone_number': phone, 'password': password},
    );
  }

  Future<Response> signup(Map<String, dynamic> data) {
    _token = null; // Clear token before signup
    return _dio.post('/auth/customer/signup/', data: data);
  }

  // --- User Profile Methods ---
  Future<Response> fetchUserProfile() {
    return _dio.get('/auth/profile/');
  }

  Future<Response> updateUserProfile(Map<String, dynamic> profileData) {
    return _dio.put('/auth/profile/update/', data: profileData);
  }

  // --- Product Methods ---
  Future<Response> getProductsForRetailer(int retailerId) {
    return _dio.get('/products/retailer/$retailerId/');
  }

  // --- Cart Methods ---
  Future<Response> addToCart(int productId, int quantity) {
    return _dio.post(
      '/cart/add/',
      data: {'product_id': productId, 'quantity': quantity},
    );
  }

  Future<Response> getCart(int retailerId) {
    return _dio.get('/cart/', queryParameters: {'retailer_id': retailerId});
  }
}
