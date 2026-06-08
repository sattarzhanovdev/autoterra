import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://neuro-map.online/api',
  );

  final http.Client _httpClient;

  ApiClient({http.Client? client}) : _httpClient = client ?? _DefaultHttpClient();
  static const _tokenKey = 'auth_token';
  static const _roleKey = 'user_role';
  static String? _token;
  static String? _role;

  static bool get isAuthorized => _token != null;
  static String? get role => _role;

  static Future<void> loadSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _role = prefs.getString(_roleKey);
  }

  static Future<void> clearToken() async {
    _token = null;
    _role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_roleKey);
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
    
    if (result.containsKey('user')) {
      final user = result['user'] as Map<String, dynamic>;
      _role = user['role'] as String?;
    }

    if (_token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);
      if (_role != null) {
        await prefs.setString(_roleKey, _role!);
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> resetPassword({
    required String phone,
    required String inn,
    required String newPassword,
  }) {
    return _post('/auth/password-reset/', {
      'phone': phone,
      'inn': inn,
      'new_password': newPassword,
    });
  }

  Future<Map<String, dynamic>> dashboard() {
    return _get('/dashboard/');
  }

  Future<Map<String, dynamic>> distributorDashboard() {
    return _get('/distributor/dashboard/');
  }

  Future<Map<String, dynamic>> me() => _get('/auth/me/');

  Future<Map<String, dynamic>> orderConfig() => _get('/order-config/');

  Future<List<Map<String, dynamic>>> products() async {
    final result = await _get('/products/');
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> stores() async {
    final result = await _get('/stores/');
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> orders() async {
    final result = await _get('/orders/');
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createOrder({
    String? storeId,
    required List<Map<String, dynamic>> items,
    required String comment,
  }) {
    return _post('/orders/create/', {
      if (storeId != null) 'storeId': storeId,
      'items': items,
      'comment': comment,
    });
  }

  Future<List<Map<String, dynamic>>> purchases() async {
    final result = await _get('/purchases/');
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> colorRequests() async {
    final result = await _get('/color-requests/');
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> courierTasks() async {
    final result = await _get('/courier-tasks/');
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> tickets() async {
    final result = await _get('/tickets/');
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final result = await _get('/notifications/');
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> markNotificationsRead() async {
    await _post('/notifications/read/', {});
  }

  Future<Map<String, dynamic>> sendNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'info',
    String? relatedLink,
  }) {
    return _post('/notifications/send/', {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      if (relatedLink != null) 'relatedLink': relatedLink,
    });
  }

  Future<List<Map<String, dynamic>>> managerClients() async {
    final result = await _get('/manager/clients/');
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createKnowledgeCard(Map<String, dynamic> body) {
    return _post('/knowledge-cards/create/', body);
  }

  Future<Map<String, dynamic>> updateKnowledgeCard(String id, Map<String, dynamic> body) {
    return _post('/knowledge-cards/$id/update/', body);
  }

  Future<Map<String, dynamic>> expertAnswerTicket(
    String ticketId, {
    required String answer,
    String? causes,
    bool createKnowledgeCard = false,
  }) {
    return _post('/tickets/$ticketId/expert-answer/', {
      'answer': answer,
      if (causes != null) 'causes': causes,
      'createKnowledgeCard': createKnowledgeCard,
    });
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
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getDistributors() async {
    final result = await _get('/distributors/');
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      
      body.forEach((key, value) {
        if (value is List || value is Map) {
          request.fields[key] = jsonEncode(value);
        } else {
          request.fields[key] = value.toString();
        }
      });

      request.files.add(http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: fileName,
      ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      return _decode(response);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> courierMyTasks() async {
    final result = await _get('/courier/tasks/');
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
      try {
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
        final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamedResponse);
        return _decode(response);
      } catch (e) {
        _handleError(e);
        rethrow;
      }
    } else {
      return _patch(path, {
        'status': status,
        if (courierComment != null) 'courier_comment': courierComment,
      });
    }
  }

  Future<List<Map<String, dynamic>>> distributorClients() async {
    final result = await _get('/distributor/clients/');
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> verifyPurchase(String id, {required String status, String? reason}) {
    return _patch('/distributor/purchases/$id/verify/', {
      'status': status,
      if (reason != null) 'rejection_reason': reason,
    });
  }

  Future<List<Map<String, dynamic>>> distributorOrders({String? status}) async {
    final query = status != null ? '?status=$status' : '';
    final result = await _get('/distributor/orders/$query');
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> distributorPurchases({String? status, bool? toVerify}) async {
    final Map<String, String> params = {};
    if (status != null) params['status'] = status;
    if (toVerify == true) params['to_verify'] = 'true';
    
    final queryString = params.isEmpty ? '' : '?${params.entries.map((e) => "${e.key}=${e.value}").join('&')}';
    final result = await _get('/distributor/purchases/$queryString');
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> distributorCouriers() async {
    final result = await _get('/distributor/couriers/');
    return List<Map<String, dynamic>>.from(result['results']);
  }

  Future<Map<String, dynamic>> distributorIntegration() => _get('/distributor/integration/');
  Future<Map<String, dynamic>> generateIntegrationToken() => _post('/distributor/integration/generate/', {});

  Future<Map<String, dynamic>> updateOrderStatus(String id, {required String status, String? reason, String? courierId, String? estimatedDeliveryDate}) {
    return _patch('/distributor/orders/$id/status/', {
      'status': status,
      if (reason != null) 'rejection_reason': reason,
      if (courierId != null) 'courier_id': courierId,
      if (estimatedDeliveryDate != null) 'estimated_delivery_date': estimatedDeliveryDate,
    });
  }

  Future<List<Map<String, dynamic>>> distributorStock() async {
    final result = await _get('/distributor/stock/');
    return (result['results'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  Future<Map<String, dynamic>> adminAnalytics({String? regionId, String? distributorId}) async {
    String path = '/admin/analytics/';
    final params = <String>[];
    if (regionId != null) params.add('region=$regionId');
    if (distributorId != null) params.add('distributor=$distributorId');
    if (params.isNotEmpty) path += '?${params.join('&')}';
    return _get(path);
  }

  Future<Map<String, dynamic>> test1CIntegration(List<dynamic> payload) {
    // Increased timeout for integration testing
    return _post('/integration/erp/stock-update/?dry_run=true', payload, timeout: const Duration(seconds: 60));
  }

  Future<void> distributorStockUpload(List<Map<String, dynamic>> items) async {
    await _post('/distributor/stock/upload/', {'items': items}, timeout: const Duration(seconds: 60));
  }

  Future<Map<String, dynamic>> _patch(String path, dynamic body) async {
    try {
      final response = await _httpClient
          .patch(
            Uri.parse('$baseUrl$path'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      return _decode(response);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? params}) async {
    try {
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: params);
      final response = await _httpClient
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 15));
      return _decode(response);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    dynamic body, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final response = await _httpClient
          .post(
            Uri.parse('$baseUrl$path'),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(timeout);
      return _decode(response);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  void _handleError(Object e) {
    final errStr = e.toString().toLowerCase();
    if (errStr.contains('socketexception') || errStr.contains('host lookup') || errStr.contains('connection refused')) {
      throw const ApiException('Сервер недоступен. Проверьте интернет-соединение или статус сервера.');
    }
    if (errStr.contains('timeoutexception')) {
      throw const ApiException('Превышено время ожидания. Сервер отвечает слишком долго.');
    }
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    String bodyString;
    try {
      bodyString = utf8.decode(response.bodyBytes);
    } catch (e) {
      throw ApiException('Failed to decode response body', e.toString());
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(bodyString);
    } catch (e) {
      // If it's not JSON, it might be an HTML error page from the server
      final snippet = bodyString.length > 100 ? '${bodyString.substring(0, 100)}...' : bodyString;
      throw ApiException(
        'Server returned non-JSON response (Status ${response.statusCode})',
        'Snippet: $snippet',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic>
          ? decoded['detail']?.toString()
          : null;
      throw ApiException(detail ?? 'API error ${response.statusCode}', decoded);
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiException('Unexpected API response format', decoded);
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
