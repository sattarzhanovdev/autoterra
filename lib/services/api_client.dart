import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static String get baseUrl {
    switch (environment) {
      case 'production':
        return 'https://api.autoterra.app/api';
      case 'staging':
        return 'https://staging-api.autoterra.app/api';
      case 'development':
      default:
        const url = String.fromEnvironment('API_BASE_URL');
        return url.isNotEmpty ? url : 'http://10.0.2.2:8000/api';
    }
  }

  const ApiClient();
  static const _tokenKey = 'auth_token';
  static String? _token;
  static String? currentRole;

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
    final user = result['user'];
    currentRole = user is Map<String, dynamic> ? user['role']?.toString() : null;
    if (_token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);
    }
    return result;
  }

  Future<Map<String, dynamic>> register({
    required String inn,
    required String companyName,
    required String region,
    required String category,
    required String contactName,
    required String phone,
    required String email,
    required String password,
    String registrationSource = 'client',
  }) {
    return _post('/register/', {
      'inn': inn,
      'companyName': companyName,
      'region': region,
      'category': category,
      'contactName': contactName,
      'phone': phone,
      'email': email,
      'password': password,
      'registrationSource': registrationSource,
    });
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

  Future<Map<String, dynamic>> createPurchase({
    required String inn,
    required String documentNumber,
    required DateTime date,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    List<PlatformFile> attachments = const [],
  }) async {
    return _multipartPost('/purchases/create/', {
      'inn': inn,
      'documentNumber': documentNumber,
      'date': date.toIso8601String().split('T').first,
      'totalAmount': totalAmount.toString(),
      'items': jsonEncode(items),
    }, attachments);
  }

  Future<List<Map<String, dynamic>>> colorRequests() async {
    final result = await _get('/color-requests/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createColorRequest(
    Map<String, dynamic> body, {
    List<PlatformFile> attachments = const [],
  }) {
    if (attachments.isEmpty) return _post('/color-requests/create/', body);
    return _multipartPost('/color-requests/create/', _stringFields(body), attachments);
  }

  Future<List<Map<String, dynamic>>> courierTasks() async {
    final result = await _get('/courier-tasks/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createCourierTask(Map<String, dynamic> body) {
    return _post('/courier-tasks/create/', body);
  }

  Future<Map<String, dynamic>> uploadCourierProof({
    required String taskId,
    required List<PlatformFile> attachments,
  }) {
    return _multipartPost('/courier-tasks/$taskId/proof/', {}, attachments);
  }

  Future<List<Map<String, dynamic>>> courierMyTasks() async {
    final result = await _get('/courier/tasks/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> courierTaskDetail(String id) {
    return _get('/courier/tasks/$id/');
  }

  Future<Map<String, dynamic>> courierUpdateTaskStatus(String id, String status, {String comment = ''}) {
    return _post('/courier/tasks/$id/status/', {'status': status, 'comment': comment});
  }

  Future<Map<String, dynamic>> courierUpdateComment(String id, String comment) {
    return _post('/courier/tasks/$id/comment/', {'comment': comment});
  }

  Future<Map<String, dynamic>> courierUploadProof({
    required String taskId,
    required List<PlatformFile> attachments,
  }) {
    return _multipartPost('/courier/tasks/$taskId/proof/', {}, attachments);
  }

  Future<Map<String, dynamic>> assignCourierTask({
    required String taskId,
    required String courierId,
  }) {
    return _post('/courier/tasks/$taskId/assign/', {'courierId': courierId});
  }

  Future<Map<String, dynamic>> distributorDashboard() => _get('/distributor/dashboard/');

  Future<List<Map<String, dynamic>>> distributorClients() async {
    final result = await _get('/distributor/clients/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> distributorPurchases() async {
    final result = await _get('/distributor/purchases/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> distributorConfirmPurchase(String id) {
    return _post('/distributor/purchases/$id/confirm/', {});
  }

  Future<Map<String, dynamic>> distributorRejectPurchase(String id, String reason) {
    return _post('/distributor/purchases/$id/reject/', {'reason': reason});
  }

  Future<List<Map<String, dynamic>>> distributorOrders() async {
    final result = await _get('/distributor/orders/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> distributorAcceptOrder(String id) {
    return _post('/distributor/orders/$id/accept/', {});
  }

  Future<Map<String, dynamic>> distributorRejectOrder(String id, String reason) {
    return _post('/distributor/orders/$id/reject/', {'reason': reason});
  }

  Future<Map<String, dynamic>> distributorUpdateOrderStatus(String id, String status) {
    return _post('/distributor/orders/$id/status/', {'status': status});
  }

  Future<List<Map<String, dynamic>>> distributorStock() async {
    final result = await _get('/distributor/stock/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> distributorUploadStock(List<Map<String, dynamic>> items) {
    return _post('/distributor/stock/upload/', {'items': items});
  }

  Future<Map<String, dynamic>> distributorReports() => _get('/distributor/reports/');

  Future<List<Map<String, dynamic>>> referrals() async {
    final result = await _get('/referrals/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> tickets() async {
    final result = await _get('/tickets/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createTicket(
    Map<String, dynamic> body, {
    List<PlatformFile> attachments = const [],
  }) {
    if (attachments.isEmpty) return _post('/tickets/create/', body);
    return _multipartPost('/tickets/create/', _stringFields(body), attachments);
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    final result = await _get('/notifications/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> knowledgeCards() async {
    final result = await _get('/knowledge-cards/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> regions() async {
    final result = await _get('/regions/');
    return (result['results'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> aiChatWithMeta(String message) async {
    return _post(
      '/ai/chat/',
      {'message': message},
      timeout: const Duration(seconds: 60),
    );
  }

  Future<String> aiChat(String message) async {
    final result = await aiChatWithMeta(message);
    return result['answer'] as String;
  }

  Future<Map<String, dynamic>> expertAnswerTicket(String id, Map<String, dynamic> body) {
    return _post('/tickets/$id/expert-answer/', body);
  }

  Future<Map<String, dynamic>> updateKnowledgeCard(String id, Map<String, dynamic> body) {
    return _post('/knowledge-cards/$id/update/', body);
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

  Future<Map<String, dynamic>> _multipartPost(
    String path,
    Map<String, String> fields,
    List<PlatformFile> attachments,
  ) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }
    request.fields.addAll(fields);
    for (final file in attachments) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      request.files.add(
        http.MultipartFile.fromBytes('attachments', bytes, filename: file.name),
      );
    }
    final streamed = await request.send().timeout(const Duration(seconds: 12));
    final response = await http.Response.fromStream(streamed);
    return _decode(response);
  }

  Map<String, String> _stringFields(Map<String, dynamic> body) {
    return body.map((key, value) => MapEntry(key, value?.toString() ?? ''));
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
