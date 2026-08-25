import 'package:firebase_messaging/firebase_messaging.dart';

class WebNotificationService {
  static Future<void> requestPermission() async {
    // No-op on mobile — browser Notification API doesn't exist here.
  }

  static String getPermissionStatus() {
    return 'unsupported';
  }

  static void show(RemoteMessage message) {
    // No-op on mobile — FCM's native handling covers this instead.
  }
}
