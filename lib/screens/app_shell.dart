// lib/screens/app_shell.dart
import 'package:flutter/material.dart';
import 'home_page.dart'; // your existing mobile HomePage
import 'web_home_shell.dart'; // new, wraps your 3 web widgets

class AppShell extends StatelessWidget {
  final String? userId;
  const AppShell({super.key, this.userId});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return const WebHomeShell();
        }
        return HomePage(
          key: ValueKey('home_${userId ?? 'guest'}'),
          initialTab: 0,
        );
      },
    );
  }
}
