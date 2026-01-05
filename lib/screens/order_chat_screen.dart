import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/order_provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/notification_service.dart';

class OrderChatScreen extends StatefulWidget {
  final int orderId;
  final String orderNumber;
  final String retailerName;

  const OrderChatScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.retailerName,
  });

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _notificationSubscription;
  Timer? _pollingTimer;

  final List<String> _quickQueries = [
    "Where is my order?",
    "Item missing",
    "Packing issue",
    "Delivery time?",
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().setCurrentChatOrderId(widget.orderId);
      _fetchMessages();
    });
    _listenForNotifications();

    // Start polling as fallback for real-time
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchMessages();
    });
  }

  void _listenForNotifications() {
    _notificationSubscription = NotificationService().updateStream.listen((
      data,
    ) {
      if (data['event'] == 'order_chat_refresh' &&
          data['order_id'] == widget.orderId.toString()) {
        _fetchMessages();
      }
    });
  }

  void _fetchMessages() {
    context.read<OrderProvider>().fetchChatMessages(widget.orderId);
  }

  @override
  void dispose() {
    // We cannot use context.read here safely if we leave the screen?
    // Actually we can, but let's be safe.
    // However, we need to reset currentChatOrderId.
    // context.read<OrderProvider>().setCurrentChatOrderId(null); // This might throw if context is invalid.
    // Instead, we rely on the provider to not have it set, OR we do it.
    // Let's try to do it, but catch error just in case.
    try {
      context.read<OrderProvider>().setCurrentChatOrderId(null);
    } catch (e) {
      // debugPrint('Provider access error in dispose: $e');
    }

    _messageController.dispose();
    _scrollController.dispose();
    _notificationSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _sendMessage({String? quickMessage}) async {
    final message = quickMessage ?? _messageController.text.trim();
    if (message.isEmpty) return;

    if (quickMessage == null) {
      _messageController.clear();
    }

    try {
      await context.read<OrderProvider>().sendChatMessage(
        widget.orderId,
        message,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Soft background
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order #${widget.orderNumber}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Row(
              children: [
                const Icon(Icons.store, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  widget.retailerName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<OrderProvider>(
              builder: (context, provider, child) {
                final messages = provider.chatMessages;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.support_agent,
                          size: 80,
                          color: Colors.teal.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Need help with this order?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Chat directly with the retailer.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Scroll to bottom when messages load/update
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final bool isMe = msg['is_me'] ?? false;
                    return _buildMessageBubble(msg, isMe);
                  },
                );
              },
            ),
          ),
          _buildQuickReplies(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.grey[50],
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _quickQueries.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(_quickQueries[index]),
            backgroundColor: Colors.white,
            elevation: 1,
            labelStyle: TextStyle(
              color: Colors.teal[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.teal.withOpacity(0.2)),
            ),
            onPressed: () => _sendMessage(quickMessage: _quickQueries[index]),
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final DateTime createdAt = DateTime.parse(msg['created_at']);
    final String timeStr = DateFormat('hh:mm a').format(createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF2563EB) : Colors.white, // Blue vs White
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
          boxShadow: [
            if (!isMe)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Text(
                'Store',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              msg['message'] ?? '',
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white70 : Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Ask something...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _sendMessage(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB), // Primary Blue
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
