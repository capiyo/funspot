import 'dart:developer' as developer;
import 'dart:html' as html;
import 'package:firebase_messaging/firebase_messaging.dart';

class WebNotificationService {
  static bool _permissionGranted = false;

  static Future<void> requestPermission() async {
    final permission = await html.Notification.requestPermission();
    _permissionGranted = permission == 'granted';
    developer.log('🌐 Web notification permission: $permission',
        name: 'Funzypp');
  }

  static String getPermissionStatus() {
    return html.Notification.permission ?? 'default';
  }

  static void show(RemoteMessage message) {
    if (!_permissionGranted) return;

    final title = message.notification?.title ??
        message.data['title'] ??
        'New Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';

    final notification = html.Notification(
      title,
      body: body,
      icon: '/icons/funspot.png',
    );

    notification.onClick.listen((_) {
      notification.close();
    });
  }
}
