import 'package:flutter/material.dart';
import '../models/models.dart';
import 'api_client.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    _currentRole = _parseRole(ApiClient.role);
  }

  UserRole _currentRole = UserRole.client;
  UserRole get currentRole => _currentRole;
  
  Map<String, dynamic>? _currentUserData;
  Map<String, dynamic>? get currentUserData => _currentUserData;

  void setRole(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }
  
  void updateFromBackendUser(Map<String, dynamic> userJson) {
    _currentUserData = userJson;
    _currentRole = _parseRole(userJson['role'] as String?);
    notifyListeners();
  }

  UserRole _parseRole(String? roleString) {
    switch (roleString) {
      case 'distributor':
        return UserRole.distributor;
      case 'courier':
        return UserRole.courier;
      case 'expert':
        return UserRole.aiExpert;
      case 'manager':
        return UserRole.manager;
      case 'admin':
        return UserRole.admin;
      case 'autoservice':
      default:
        return UserRole.client;
    }
  }

  Future<void> logout() async {
    await ApiClient.clearToken();
    _currentRole = UserRole.client; // Reset to default role
    _currentUserData = null;
    notifyListeners();
  }

  // Helper to check if user is authorized (can be extended to check token)
  bool get isAuthenticated => ApiClient.isAuthorized;
}

final authService = AuthService();
