import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Stream for silent updates
  final _updateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get updateStream => _updateController.stream;

  Future<void> initialize() async {
    _fcm = FirebaseMessaging.instance;
    // Request permissions (especially for iOS)
    NotificationSettings settings = await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (kDebugMode) {
      print('User granted permission: ${settings.authorizationStatus}');
    }

    // Initialize local notifications for foreground display
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
          '@mipmap/ic_launcher',
        ); // Standard launcher icon

    // Note: On some systems you might need to use a specifically created transparent icon
    // AndroidInitializationSettings('@drawable/ic_notification');

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: DarwinInitializationSettings(),
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification click while app is open
      },
    );

    // Create notification channel for Android 8.0+
    // Create notification channel for Android 8.0+
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen(_handleMessage);

    // Listen for background message clicks
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Message clicked! ${message.data}');
      }
    });
  }

  Future<String?> getToken() async {
    if (_fcm == null) return null;
    try {
      return await _fcm!.getToken();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting FCM token: $e');
      }
      return null;
    }
  }

  void _handleMessage(RemoteMessage message) {
    if (kDebugMode) {
      print('Handling foreground message: ${message.messageId}');
    }

    // Check if it's a silent update
    if (message.data['is_silent'] == 'true' || message.data['event'] != null) {
      _updateController.add(Map<String, dynamic>.from(message.data));
      // Don't show a notification if it's silent
      if (message.data['is_silent'] == 'true') return;
    }

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null && !kIsWeb) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidDetails(
            channelId: 'high_importance_channel',
            channelName: 'High Importance Notifications',
            icon: '@mipmap/ic_launcher',
          ),
        ),
      );
    }
  }
}

class AndroidDetails extends AndroidNotificationDetails {
  const AndroidDetails({
    required String channelId,
    required String channelName,
    String? icon,
  }) : super(
         channelId,
         channelName,
         importance: Importance.max,
         priority: Priority.high,
         icon: icon,
       );
}
