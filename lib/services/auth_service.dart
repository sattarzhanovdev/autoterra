import 'package:flutter/material.dart';
import '../models/models.dart';
import 'api_client.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  UserRole _currentRole = UserRole.client;
  UserRole get currentRole => _currentRole;

  void setRole(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiClient.clearToken();
    _currentRole = UserRole.client; // Reset to default role
    notifyListeners();
  }

  // Helper to check if user is authorized (can be extended to check token)
  bool get isAuthenticated => ApiClient.isAuthorized;
}

final authService = AuthService();
