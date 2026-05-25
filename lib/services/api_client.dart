import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://89.111.132.221:8000/api',
  );

  const ApiClient();
  static const _tokenKey = 'auth_token';
  static String? _token;

  static bool get isAuthorized => _token != null;

  static Future<void> loadSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    _token = token?.isEmpty == true ? null : token;
  }

  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final result = await _post('/login/', {
      'phone': phone,
      'password': password,
    });
    _token = result['token'] as String?;
    if (_token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);
    }
    return result;
  }

  Future<Map<String, dynamic>> dashboard() {
    return _get('/dashboard/');
  }

  Future<Map<String, dynamic>> me() => _get('/auth/me/');

  Future<Map<String, dynamic>> orderConfig() => _get('/order-config/');

  Future<List<Map<String, dynamic>>> products() async {
    final result = await _get('/products/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> stores() async {
    final result = await _get('/stores/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> orders() async {
    final result = await _get('/orders/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createOrder({
    required String storeId,
    required List<Map<String, dynamic>> items,
    required String comment,
  }) {
    return _post('/orders/create/', {
      'storeId': storeId,
      'items': items,
      'comment': comment,
    });
  }

  Future<List<Map<String, dynamic>>> purchases() async {
    final result = await _get('/purchases/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> colorRequests() async {
    final result = await _get('/color-requests/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createColorRequest(Map<String, dynamic> body) {
    return _post('/color-requests/create/', body);
  }

  Future<List<Map<String, dynamic>>> courierTasks() async {
    final result = await _get('/courier-tasks/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createCourierTask(Map<String, dynamic> body) {
    return _post('/courier-tasks/create/', body);
  }

  Future<List<Map<String, dynamic>>> referrals() async {
    final result = await _get('/referrals/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> tickets() async {
    final result = await _get('/tickets/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final result = await _get('/notifications/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> knowledgeCards() async {
    final result = await _get('/knowledge-cards/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<String> aiChat(String message) async {
    final result = await _post(
      '/ai/chat/',
      {'message': message},
      timeout: const Duration(seconds: 60),
    );
    return result['answer'] as String;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await http
        .get(Uri.parse('$baseUrl$path'), headers: _headers())
        .timeout(const Duration(seconds: 3));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(timeout);
    return _decode(response);
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic>
          ? decoded['detail']?.toString()
          : null;
      throw ApiException(detail ?? 'API error ${response.statusCode}', decoded);
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected API response', decoded);
    }
    return decoded;
  }
}

class ApiException implements Exception {
  final String message;
  final Object? details;

  const ApiException(this.message, [this.details]);

  @override
  String toString() => message;
}
