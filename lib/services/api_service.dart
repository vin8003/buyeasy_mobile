import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart'; // For GlobalKey and NavigatorState

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  String? _accessToken;
  String? _refreshToken;

  String _baseUrl = 'http://ordereasy.win/api/';

  // Navigation key to allow navigating from outside the widget tree
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Callback for when automatic logout happens due to token expiration
  VoidCallback? _onForcedLogout;

  /// Set a callback to be invoked when the API service forces a logout
  /// due to token expiration or invalid token.
  void setForcedLogoutCallback(VoidCallback? callback) {
    _onForcedLogout = callback;
  }

  String formatImageUrl(String? path) {
    if (path == null || path.isEmpty) return 'https://via.placeholder.com/150';
    if (path.startsWith('http')) return path;

    // Media files are usually at /media/, but baseUrl often ends in /api/
    // We need to strip /api/ to get the base domain for media files.
    String mediaBase = _baseUrl;
    if (mediaBase.endsWith('/api/')) {
      mediaBase = mediaBase.substring(0, mediaBase.length - 5);
    } else if (mediaBase.endsWith('/api')) {
      mediaBase = mediaBase.substring(0, mediaBase.length - 4);
    }

    return '$mediaBase${path.startsWith('/') ? path : '/$path'}';
  }

  // --- Concurrency / Refresh Locking ---
  bool _isRefreshing = false;
  late final _refreshCompleter = <Completer<String?>>[];

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(milliseconds: 30000),
        receiveTimeout: const Duration(milliseconds: 30000),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Do NOT attach token for refresh endpoint
          if (options.path.contains('/auth/token/refresh/')) {
            return handler.next(options);
          }

          if (_accessToken != null && _accessToken!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          // Handle 401 (Unauthorized) errors
          if (e.response?.statusCode == 401) {
            // Check if it's a refresh token failure or if we don't have a refresh token
            if (_refreshToken == null ||
                e.requestOptions.path.contains('/auth/token/refresh/')) {
              logout();
              return handler.next(e);
            }

            if (_isRefreshing) {
              // Wait for the current refresh to complete
              final completer = Completer<String?>();
              _refreshCompleter.add(completer);
              final newToken = await completer.future;

              if (newToken != null) {
                return _retry(e.requestOptions, newToken, handler);
              } else {
                return handler.next(e);
              }
            }

            _isRefreshing = true;

            try {
              // Attempt to refresh token
              final newAccessToken = await _refreshTokenAndGetNew();

              // Complete all waiting requests
              for (var completer in _refreshCompleter) {
                completer.complete(newAccessToken);
              }
              _refreshCompleter.clear();
              _isRefreshing = false;

              if (newAccessToken != null) {
                return _retry(e.requestOptions, newAccessToken, handler);
              } else {
                logout();
                return handler.next(e);
              }
            } catch (refreshError) {
              // Fail all waiting
              for (var completer in _refreshCompleter) {
                completer.complete(null);
              }
              _refreshCompleter.clear();
              _isRefreshing = false;

              logout();
              return handler.next(e);
            }
          }
          print('API Error: ${e.response?.data ?? e.message}');
          return handler.next(e);
        },
      ),
    );
    _initBaseUrl(); // Load saved URL on startup
  }

  Future<void> _initBaseUrl() async {
    _baseUrl = 'http://127.0.0.1:8000/api/';
    _dio.options.baseUrl = _baseUrl;
    print('ApiService Initialized with Base URL: $_baseUrl');
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    _dio.options.baseUrl = url;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', url);
  }

  String get baseUrl => _baseUrl;

  Future<void> _retry(
    RequestOptions requestOptions,
    String newToken,
    ErrorInterceptorHandler handler,
  ) async {
    final options = Options(
      method: requestOptions.method,
      headers: requestOptions.headers,
    );
    options.headers?['Authorization'] = 'Bearer $newToken';
    try {
      final response = await _dio.request(
        requestOptions.path,
        data: requestOptions.data,
        queryParameters: requestOptions.queryParameters,
        options: options,
      );
      handler.resolve(response);
    } catch (e) {
      if (e is DioException) {
        handler.next(e);
      }
    }
  }

  Future<void> logout() async {
    await setAuthToken(null, null);
    // Notify listeners (e.g., AuthProvider) about the forced logout
    _onForcedLogout?.call();
    // Use navigatorKey to navigate to login screen
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      '/login',
      (route) => false,
    );
  }

  Future<void> registerDeviceToken(String token) async {
    try {
      await _dio.post(
        'auth/device/register/',
        data: {
          'registration_id': token,
          'type': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
          'name': 'mobile_app',
        },
      );
      if (kDebugMode) {
        print('FCM Token registered successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to register FCM token: $e');
      }
    }
  }

  Future<String?> _refreshTokenAndGetNew() async {
    try {
      // NOTE: Standard Dio call here will trigger interceptors.
      // But we added logic in onRequest to SKIP Auth header for this path.
      final response = await _dio.post(
        'auth/token/refresh/',
        data: {'refresh': _refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccess = response.data['access'];
        // Backend might return a new refresh token too, if configured (SimpleJWT rotation)
        final newRefresh = response.data['refresh'] ?? _refreshToken;

        await setAuthToken(newAccess, newRefresh);
        return newAccess;
      }
    } catch (e) {
      print('Token Refresh Failed: $e');
    }
    return null;
  }

  Future<void> checkAuthToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
  }

  Future<void> setAuthToken(String? access, String? refresh) async {
    _accessToken = access;
    _refreshToken = refresh;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (access == null) {
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
    } else {
      await prefs.setString('access_token', access);
      if (refresh != null) {
        await prefs.setString('refresh_token', refresh);
      }
    }
  }

  // --- Auth Methods ---
  Future<Response> login(String phone, String password) async {
    await setAuthToken(null, null); // Clear tokens before login
    return _dio.post(
      'auth/customer/login/',
      data: {'username': phone, 'password': password},
    );
  }

  Future<Response> signup(Map<String, dynamic> data) async {
    await setAuthToken(null, null); // Clear tokens before signup
    return _dio.post('auth/customer/signup/', data: data);
  }

  // --- User Profile Methods ---
  Future<Response> fetchUserProfile() {
    return _dio.get('customer/profile/');
  }

  Future<Response> updateUserProfile(Map<String, dynamic> data) {
    return _dio.put('customer/profile/update/', data: data);
  }

  // Products
  Future<Response> getProducts(int retailerId) {
    return _dio.get('products/retailer/$retailerId/');
  }

  Future<Response> getCategories() {
    return _dio.get('products/categories/');
  }

  Future<Response> getRetailerCategories(int retailerId) {
    return _dio.get('products/retailer/$retailerId/categories/');
  }

  Future<Response> getFeaturedProducts(int retailerId) {
    return _dio.get('products/retailer/$retailerId/featured/');
  }

  // Cart
  Future<Response> getCart(int retailerId) {
    return _dio.get('cart/', queryParameters: {'retailer_id': retailerId});
  }

  Future<Response> addToCart(int productId, int quantity) {
    return _dio.post(
      'cart/add/',
      data: {'product_id': productId, 'quantity': quantity},
    );
  }

  Future<Response> updateCartItem(int itemId, int quantity) {
    return _dio.put('cart/items/$itemId/', data: {'quantity': quantity});
  }

  Future<Response> removeCartItem(int itemId) {
    return _dio.delete('cart/items/$itemId/remove/');
  }

  // Retailers
  Future<Response> getRetailers({
    String? city,
    String? userPincode,
    double? lat,
    double? lng,
  }) {
    final queryParams = <String, dynamic>{};
    if (city != null) queryParams['city'] = city;
    if (userPincode != null) queryParams['user_pincode'] = userPincode;
    if (lat != null) queryParams['lat'] = lat;
    if (lng != null) queryParams['lng'] = lng;

    return _dio.get('retailers/', queryParameters: queryParams);
  }

  // Address
  Future<Response> getAddresses() {
    return _dio.get('customer/addresses/');
  }

  Future<Response> addAddress(Map<String, dynamic> addressData) {
    return _dio.post('customer/addresses/create/', data: addressData);
  }

  Future<Response> updateAddress(int id, Map<String, dynamic> addressData) {
    return _dio.put('customer/addresses/$id/update/', data: addressData);
  }

  Future<Response> deleteAddress(int id) {
    return _dio.delete('customer/addresses/$id/delete/');
  }

  // Orders
  Future<Response> placeOrder(Map<String, dynamic> orderData) {
    return _dio.post('orders/place/', data: orderData);
  }

  Future<Response> getOrderHistory() {
    return _dio.get('orders/history/');
  }

  Future<Response> getOrderDetail(int orderId, {String? lastUpdated}) {
    final queryParameters = <String, dynamic>{};
    if (lastUpdated != null) {
      queryParameters['last_updated'] = lastUpdated;
    }

    return _dio.get(
      'orders/$orderId/',
      queryParameters: queryParameters,
      options: Options(
        validateStatus: (status) {
          return status != null &&
              (status >= 200 && status < 300 || status == 304);
        },
      ),
    );
  }

  Future<Response> cancelOrder(int orderId, {String? reason}) {
    return _dio.post('orders/$orderId/cancel/', data: {'reason': reason ?? ''});
  }

  // Reviews
  Future<Response> getRetailerReviews(int retailerId) {
    return _dio.get('retailers/$retailerId/reviews/');
  }

  Future<Response> createRetailerReview(
    int retailerId,
    int rating,
    String comment,
  ) {
    return _dio.post(
      'retailers/$retailerId/reviews/create/',
      data: {'rating': rating, 'comment': comment},
    );
  }

  // Verify Phone (OTP)
  Future<Response> requestPhoneVerification() {
    return _dio.post('auth/customer/request-verification/');
  }

  Future<Response> verifyOtp(
    String phone, {
    String? otp,
    String? firebaseToken,
  }) {
    final data = {'phone_number': phone};
    if (otp != null) data['otp_code'] = otp;
    if (firebaseToken != null) data['firebase_token'] = firebaseToken;

    return _dio.post('auth/customer/verify-otp/', data: data);
  }

  Future<Response> forgotPassword(String phone) {
    return _dio.post('auth/password/forgot/', data: {'phone_number': phone});
  }

  Future<Response> resetPassword({
    required String phone,
    required String newPassword,
    String? otp,
    String? firebaseToken,
  }) {
    final data = <String, dynamic>{
      'phone_number': phone,
      'new_password': newPassword,
      'confirm_password': newPassword,
    };
    if (otp != null) data['otp_code'] = otp;
    if (firebaseToken != null) data['firebase_token'] = firebaseToken;

    return _dio.post('auth/password/reset/', data: data);
  }

  // Wishlist
  Future<Response> getWishlist() {
    return _dio.get('customer/wishlist/');
  }

  Future<Response> addToWishlist(int productId) {
    return _dio.post('customer/wishlist/add/', data: {'product': productId});
  }

  Future<Response> removeFromWishlist(int productId) {
    return _dio.delete('customer/wishlist/remove/$productId/');
  }

  Future<Response> confirmOrderModification(int orderId, String action) {
    return _dio.post(
      'orders/$orderId/confirm-modification/',
      data: {'action': action},
    );
  }

  // Rewards
  Future<Response> fetchRewardConfiguration(int retailerId) {
    return _dio.get(
      'customer/reward-configuration/',
      queryParameters: {'retailer_id': retailerId},
    );
  }

  Future<Response> getCustomerLoyalty(int retailerId) {
    return _dio.get(
      'customer/loyalty/',
      queryParameters: {'retailer_id': retailerId},
    );
  }

  Future<Response> getAllCustomerLoyalty() {
    return _dio.get('customer/loyalty/all/');
  }

  // Referral
  Future<Response> applyReferralCode(String referralCode, int retailerId) {
    return _dio.post(
      'customer/referral/apply/',
      data: {'referral_code': referralCode, 'retailer_id': retailerId},
    );
  }

  Future<Response> getReferralStats() {
    return _dio.get('customer/referral/stats/');
  }

  // Chat
  Future<Response> getOrderChatMessages(int orderId) {
    return _dio.get('orders/$orderId/chat/');
  }

  Future<Response> sendOrderMessage(int orderId, String message) {
    return _dio.post('orders/$orderId/chat/send/', data: {'message': message});
  }

  Future<Response> markOrderChatRead(int orderId) {
    return _dio.post('orders/$orderId/chat/read/');
  }
}
