import 'package:flutter/material.dart';
import '../models/models.dart';
import 'api_client.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

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
    final roleString = userJson['role'] as String?;
    
    switch (roleString) {
      case 'distributor':
        _currentRole = UserRole.distributor;
        break;
      case 'courier':
        _currentRole = UserRole.courier;
        break;
      case 'expert':
        _currentRole = UserRole.aiExpert;
        break;
      case 'autoservice':
      default:
        _currentRole = UserRole.client;
        break;
    }
    notifyListeners();
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
