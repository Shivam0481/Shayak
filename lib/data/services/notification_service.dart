import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('BG message: ${message.notification?.title}');
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'shayak_alerts';
  static const _channelName = 'Shayak Alerts';

  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // v21 uses named parameter `settings:`
    await _local.initialize(settings: initSettings);

    // Create Android notification channel
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      importance: Importance.max,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_showLocalNotification);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM Token: $token');
    } catch (e) {
      debugPrint('FCM Token error: $e');
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.max,
        priority: Priority.high,
        color: Color(0xFF219EBC),
      ),
      iOS: DarwinNotificationDetails(),
    );

    // v21 uses named parameters for show()
    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch & 0xFFFF,
      title: message.notification?.title ?? 'Shayak Alert',
      body: message.notification?.body ?? '',
      notificationDetails: details,
    );
  }
}
