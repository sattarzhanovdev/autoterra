import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://89.111.132.221:8000/api',
  );

  final http.Client _httpClient;

  ApiClient({http.Client? client}) : _httpClient = client ?? _DefaultHttpClient();
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

  Future<List<Map<String, dynamic>>> courierTasks() async {
    final result = await _get('/courier-tasks/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createCourierTask(Map<String, dynamic> body) {
    return _post('/courier-tasks/create/', body);
  }

  String exportUrl({String? regionId}) {
    final query = regionId != null ? '?region=$regionId' : '';
    return '$baseUrl/reports/export/$query';
  }

  Future<Map<String, dynamic>> managerDashboard({String? regionId, String? distributorId}) async {
    final params = <String, String>{};
    if (regionId != null) params['region'] = regionId;
    if (distributorId != null) params['distributor'] = distributorId;
    return _get('/manager/dashboard/', params: params);
  }

  Future<Map<String, dynamic>> createReferral(Map<String, dynamic> body) {
    return _post('/referrals/create/', body);
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

  Future<void> markNotificationsRead() async {
    await _post('/notifications/read/', {});
  }

  Future<List<Map<String, dynamic>>> managerClients() async {
    final result = await _get('/manager/clients/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> managerClientUnified(String clientId) async {
    return _get('/manager/clients/$clientId/unified/');
  }

  Future<Map<String, dynamic>> createExpertTicket(Map<String, dynamic> body, {List<int>? fileBytes, String? fileName}) {
    if (fileBytes != null && fileName != null) {
      return _multipartPost('/tickets/create/', body, fileBytes, fileName, fileField: 'photo');
    }
    return _post('/tickets/create/', body);
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

  Future<Map<String, dynamic>> register(Map<String, dynamic> body) {
    return _post('/auth/register/', body);
  }

  Future<List<Map<String, dynamic>>> getRegions() async {
    final result = await _get('/regions/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createPurchase(Map<String, dynamic> body, {List<int>? fileBytes, String? fileName}) {
    if (fileBytes != null && fileName != null) {
      return _multipartPost('/purchases/create/', body, fileBytes, fileName, fileField: 'document');
    }
    return _post('/purchases/create/', body);
  }

  Future<Map<String, dynamic>> createColorRequest(Map<String, dynamic> body, {List<int>? fileBytes, String? fileName}) {
    if (fileBytes != null && fileName != null) {
      return _multipartPost('/color-requests/create/', body, fileBytes, fileName, fileField: 'photo');
    }
    return _post('/color-requests/create/', body);
  }

  Future<Map<String, dynamic>> _multipartPost(
    String path,
    Map<String, dynamic> body,
    List<int> fileBytes,
    String fileName, {
    String fileField = 'file',
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    
    // Add text fields
    body.forEach((key, value) {
      if (value is List || value is Map) {
        request.fields[key] = jsonEncode(value);
      } else {
        request.fields[key] = value.toString();
      }
    });

    // Add file
    request.files.add(http.MultipartFile.fromBytes(
      fileField,
      fileBytes,
      filename: fileName,
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _decode(response);
  }

  Future<List<Map<String, dynamic>>> getDistributors() async {
    final result = await _get('/distributors/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> courierMyTasks() async {
    final result = await _get('/courier/tasks/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> updateCourierTaskStatus(
    String taskId, {
    required String status,
    String? courierComment,
    List<int>? imageBytes,
    String? fileName,
  }) async {
    final path = '/courier/tasks/$taskId/status/';
    if (imageBytes != null && fileName != null) {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      request.fields['status'] = status;
      if (courierComment != null) {
        request.fields['courier_comment'] = courierComment;
      }
      request.files.add(http.MultipartFile.fromBytes(
        'proof_photo',
        imageBytes,
        filename: fileName,
      ));
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _decode(response);
    } else {
      return _patch(path, {
        'status': status,
        if (courierComment != null) 'courier_comment': courierComment,
      });
    }
  }

  Future<List<Map<String, dynamic>>> distributorPurchases() async {
    final result = await _get('/distributor/purchases/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> verifyPurchase(String id, {required String status, String? reason}) {
    return _patch('/distributor/purchases/$id/verify/', {
      'status': status,
      if (reason != null) 'rejection_reason': reason,
    });
  }

  Future<List<Map<String, dynamic>>> distributorOrders() async {
    final result = await _get('/distributor/orders/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> updateOrderStatus(String id, {required String status, String? reason}) {
    return _patch('/distributor/orders/$id/status/', {
      'status': status,
      if (reason != null) 'rejection_reason': reason,
    });
  }

  Future<Map<String, dynamic>> adminIntegrationTokens() async {
    return _get('/admin/integration/tokens/');
  }

  Future<Map<String, dynamic>> adminIntegrationGenerate(String distributorId) async {
    return _post('/admin/integration/generate/$distributorId/', {});
  }

  Future<Map<String, dynamic>> adminIntegrationLogs() async {
    return _get('/admin/integration/logs/');
  }

  Future<Map<String, dynamic>> adminAnalytics() async {
    return _get('/admin/analytics/');
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> body) async {
    final response = await _httpClient
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: _headers(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 3));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? params}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
    final response = await _httpClient
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 3));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final response = await _httpClient
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

class _DefaultHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _inner.send(request);
  }
}

class ApiException implements Exception {
  final String message;
  final Object? details;

  const ApiException(this.message, [this.details]);

  @override
  String toString() => message;
}
