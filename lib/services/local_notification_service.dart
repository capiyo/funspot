import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'default_channel',
    'General Notifications',
    description: 'Votes, comments, comrades, and channel activity',
    importance: Importance.high,
  );

  static Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    if (kIsWeb) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        onTap(response.payload);
      },
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    developer.log('✅ LocalNotificationService initialized', name: 'Funzypp');
  }

  static Future<void> show(RemoteMessage message) async {
    if (kIsWeb) return;

    final title = message.notification?.title ??
        message.data['title'] ??
        'New Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: message.data.isNotEmpty ? _encodePayload(message.data) : null,
    );
  }

  static String _encodePayload(Map<String, dynamic> data) {
    // Simple flat encode; decode with Uri.splitQueryString on tap if needed,
    // or just re-derive navigation target from `type` alone.
    return data['type']?.toString() ?? '';
  }
}