// lib/services/app_state.dart
import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  String _userId = '';
  String _username = '';
  bool _isLoggedIn = false;
  bool _needsRefresh = false;

  String get userId => _userId;
  String get username => _username;
  bool get isLoggedIn => _isLoggedIn;
  bool get needsRefresh => _needsRefresh;

  void login(String uid, String uname) {
    _userId = uid;
    _username = uname;
    _isLoggedIn = true;
    _needsRefresh = true;
    notifyListeners();
  }

  void logout() {
    _userId = '';
    _username = '';
    _isLoggedIn = false;
    _needsRefresh = false;
    notifyListeners();
  }

  void refreshCompleted() {
    _needsRefresh = false;
    notifyListeners();
  }
}
