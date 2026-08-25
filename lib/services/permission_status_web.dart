import 'dart:html' as html;

String getWebPermissionStatus() => html.Notification.permission ?? 'default';
