// lib/screens/web_home_shell.dart
import 'package:flutter/material.dart';
import '../WebView/homepage.dart'; // ← Use your working web page

class WebHomeShell extends StatelessWidget {
  const WebHomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomePageWeb(); // ← Your working web layout
  }
}
