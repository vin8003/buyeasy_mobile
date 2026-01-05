import 'package:flutter/material.dart';
import '../services/api_service.dart';

class OrderProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<dynamic> _chatMessages = [];
  bool _isLoading = false;

  List<dynamic> get chatMessages => _chatMessages;
  bool get isLoading => _isLoading;

  Future<void> fetchChatMessages(int orderId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiService.getOrderMessages(orderId);
      if (response.statusCode == 200) {
        _chatMessages = response.data;
      }
    } catch (e) {
      debugPrint('Error fetching chat messages: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendChatMessage(int orderId, String message) async {
    try {
      final response = await _apiService.sendOrderMessage(orderId, message);
      if (response.statusCode == 201) {
        _chatMessages.add(response.data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error sending chat message: $e');
      rethrow;
    }
  }

  Map<int, int> _unreadCounts = {};
  Map<int, int> get unreadCounts => _unreadCounts;

  void updateUnreadCount(int orderId, int count) {
    _unreadCounts[orderId] = count;
    notifyListeners();
  }

  void incrementUnreadCount(int orderId) {
    _unreadCounts[orderId] = (_unreadCounts[orderId] ?? 0) + 1;
    notifyListeners();
  }

  void resetUnreadCount(int orderId) {
    _unreadCounts[orderId] = 0;
    notifyListeners();
  }

  int? _currentChatOrderId;
  int? get currentChatOrderId => _currentChatOrderId;

  void setCurrentChatOrderId(int? orderId) {
    _currentChatOrderId = orderId;
    if (orderId != null) {
      // Also reset unread count when entering chat
      resetUnreadCount(orderId);
    }
    notifyListeners();
  }

  void clearMessages() {
    _chatMessages = [];
    notifyListeners();
  }
}
