import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/paginated.dart';

class ApiClient {
  static String get baseUrl => dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:8000/api';

  /// Размер страницы по умолчанию — совпадает с бэкендом (`DEFAULT_PAGE_SIZE`).
  static const int defaultPageSize = 20;

  final http.Client _httpClient;

  ApiClient({http.Client? client}) : _httpClient = client ?? _DefaultHttpClient();
  static const _tokenKey = 'auth_token';
  static const _roleKey = 'user_role';
  static String? _token;
  static String? _role;

  static bool get isAuthorized => _token != null;
  static String? get role => _role;

  /// Resolves a (possibly relative) media path returned by the backend into an
  /// absolute URL. Handles already-absolute URLs, root-relative ("/media/..")
  /// and bare-relative ("media/..") forms — the backend's MEDIA_URL has no
  /// leading slash, so attachment URLs come back relative.
  static String mediaUrl(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final host = baseUrl.replaceAll('/api', '').replaceAll(RegExp(r'/+$'), '');
    final path = url.startsWith('/') ? url : '/$url';
    return '$host$path';
  }

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

  Future<(Paginated<Map<String, dynamic>>, List<String>)> products({
    int page = 1,
    int pageSize = defaultPageSize,
    String? search,
    String? category,
    String? brand,
    bool inStockOnly = false,
  }) async {
    final (items, raw) = await _getPageWithMeta(
      '/products/',
      page: page,
      pageSize: pageSize,
      filters: {
        'search': search,
        'category': category,
        'brand': brand,
        'inStock': inStockOnly ? 'true' : null,
      },
    );
    final categories = ((raw['categories'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    return (items, categories);
  }

  Future<Paginated<Map<String, dynamic>>> stores({int page = 1, int pageSize = defaultPageSize}) {
    return _getPage('/stores/', page: page, pageSize: pageSize);
  }

  Future<Map<String, dynamic>> createStore(String name, String address) =>
      _post('/stores/', {'name': name, 'address': address});

  Future<Map<String, dynamic>> updateStore(String storeId, String name, String address) =>
      _patch('/stores/$storeId/', {'name': name, 'address': address});

  Future<void> deleteStore(String storeId) async {
    await _delete('/stores/$storeId/');
  }

  Future<Paginated<Map<String, dynamic>>> orders({int page = 1, int pageSize = defaultPageSize}) {
    return _getPage('/orders/', page: page, pageSize: pageSize);
  }

  Future<Map<String, dynamic>> createOrder({
    String? storeId,
    String? deliveryMethod,
    required List<Map<String, dynamic>> items,
    required String comment,
  }) {
    return _post('/orders/create/', {
      if (storeId != null) 'storeId': storeId,
      if (deliveryMethod != null) 'deliveryMethod': deliveryMethod,
      'items': items,
      'comment': comment,
    });
  }

  Future<void> cancelOrder(String orderId) async {
    await _post('/orders/$orderId/cancel/', {});
  }

  /// Один заказ — для перехода по ссылке из письма/пуша и обновления экрана.
  Future<Map<String, dynamic>> orderDetail(String orderId) {
    return _get('/orders/$orderId/');
  }

  // ── Безопасный поток заказа ──────────────────────────────────────────────────

  /// Оператор подтверждает заказ как есть. [force] обходит проверку остатков.
  Future<Map<String, dynamic>> confirmOrder(String orderId, {bool force = false}) {
    final suffix = force ? '?force=1' : '';
    return _post('/orders/$orderId/confirm/$suffix', {});
  }

  /// Оператор корректирует состав заказа.
  /// [items] — правки существующих позиций {itemId, quantity}, quantity=0 удаляет.
  /// [newItems] — добавляемые товары {productId, quantity}.
  Future<Map<String, dynamic>> adjustOrder(
    String orderId, {
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> newItems = const [],
    String reason = '',
  }) {
    return _post('/orders/$orderId/adjust/', {
      'items': items,
      'newItems': newItems,
      'reason': reason,
    });
  }

  /// Оператор отклоняет заказ с причиной.
  Future<Map<String, dynamic>> rejectOrder(String orderId, {String reason = ''}) {
    return _post('/orders/$orderId/reject/', {'reason': reason});
  }

  /// Оператор отмечает отправку заказа.
  Future<Map<String, dynamic>> shipOrder(String orderId) {
    return _post('/orders/$orderId/ship/', {});
  }

  /// Клиент соглашается со скорректированным заказом.
  Future<Map<String, dynamic>> acceptAdjustment(String orderId) {
    return _post('/orders/$orderId/accept-adjustment/', {});
  }

  /// Клиент инициирует оплату. Возвращает payload с confirmationUrl (YooKassa).
  Future<Map<String, dynamic>> payOrder(String orderId) {
    return _post('/orders/$orderId/pay/', {});
  }

  Future<(Paginated<Map<String, dynamic>>, Map<String, dynamic>)> purchases({
    int page = 1,
    int pageSize = defaultPageSize,
  }) async {
    final (items, raw) = await _getPageWithMeta('/purchases/', page: page, pageSize: pageSize);
    final stats = (raw['stats'] as Map?) ?? const {};
    return (items, Map<String, dynamic>.from(stats));
  }

  Future<Paginated<Map<String, dynamic>>> colorRequests({
    int page = 1,
    int pageSize = defaultPageSize,
    bool activeOnly = false,
  }) {
    return _getPage(
      '/color-requests/',
      page: page,
      pageSize: pageSize,
      filters: {'active': activeOnly ? 'true' : null},
    );
  }

  Future<Paginated<Map<String, dynamic>>> courierTasks({
    int page = 1,
    int pageSize = defaultPageSize,
    bool activeOnly = false,
  }) {
    return _getPage(
      '/courier-tasks/',
      page: page,
      pageSize: pageSize,
      filters: {'active': activeOnly ? 'true' : null},
    );
  }

  Future<Map<String, dynamic>> createCourierTask(Map<String, dynamic> body) {
    return _post('/courier-tasks/create/', body);
  }

  Future<void> cancelCourierTask(String id) {
    return _post('/courier-tasks/$id/cancel/', {});
  }

  Future<Map<String, dynamic>> updateCourierTask(String id, Map<String, dynamic> body) {
    return _post('/courier-tasks/$id/update/', body);
  }

  String exportUrl({String? regionId}) {
    final query = regionId != null ? '?region=$regionId' : '';
    final path = 'reports/export/$query';
    return baseUrl.endsWith('/') ? '$baseUrl$path' : '$baseUrl/$path';
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

  /// Рефералы плюс метаданные программы: сводка, личный код, ссылка-приглашение
  /// и условия подарка. Код приходит с сервера — он у каждого клиента свой.
  Future<(Paginated<Map<String, dynamic>>, Map<String, dynamic>)> referrals({int page = 1, int pageSize = defaultPageSize}) async {
    final (items, raw) = await _getPageWithMeta('/referrals/', page: page, pageSize: pageSize);
    final stats = Map<String, dynamic>.from((raw['stats'] as Map?) ?? const {});
    for (final key in ['referralCode', 'inviteLink', 'bonusThreshold', 'bonusGift']) {
      if (raw[key] != null) stats[key] = raw[key];
    }
    return (items, stats);
  }

  Future<Paginated<Map<String, dynamic>>> tickets({int page = 1, int pageSize = defaultPageSize}) {
    return _getPage('/tickets/', page: page, pageSize: pageSize);
  }

  Future<Paginated<Map<String, dynamic>>> notifications({int page = 1, int pageSize = defaultPageSize}) {
    return _getPage('/notifications/', page: page, pageSize: pageSize);
  }

  Future<void> markNotificationsRead() async {
    await _post('/notifications/read/', {});
  }

  Future<void> registerDeviceToken({
    required String token,
    required String platform,
  }) async {
    await _post('/notifications/token/', {
      'token': token,
      'platform': platform,
    });
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

  Future<Paginated<Map<String, dynamic>>> managerClients({
    int page = 1,
    int pageSize = defaultPageSize,
  }) {
    return _getPage('/manager/clients/', page: page, pageSize: pageSize);
  }

  Future<Map<String, dynamic>> managerClientUnified(String clientId) async {
    return _get('/manager/clients/$clientId/unified/');
  }

  Future<Paginated<Map<String, dynamic>>> managerClientsFiltered({
    int page = 1,
    int pageSize = defaultPageSize,
    String? status,
    String? category,
    String? regionId,
    String? distributorId,
    String? search,
  }) {
    return _getPage(
      '/manager/clients/',
      page: page,
      pageSize: pageSize,
      filters: {
        'status': status,
        'category': category,
        'region': regionId,
        'distributor': distributorId,
        'search': search,
      },
    );
  }

  Future<Map<String, dynamic>> managerCreateClient(Map<String, dynamic> body) {
    return _post('/manager/clients/', body);
  }

  Future<Map<String, dynamic>> managerUpdateClientStatus(String clientId, String status) {
    return _post('/manager/clients/$clientId/status/', {'status': status});
  }

  Future<Paginated<Map<String, dynamic>>> managerClientHistory(
    String clientId, {
    int page = 1,
    int pageSize = defaultPageSize,
  }) {
    return _getPage(
      '/manager/clients/$clientId/history/',
      page: page,
      pageSize: pageSize,
    );
  }

  Future<Map<String, dynamic>> managerAddContactHistory(String clientId, Map<String, dynamic> body) {
    return _post('/manager/clients/$clientId/history/', body);
  }

  Future<Paginated<Map<String, dynamic>>> managerTasks({
    int page = 1,
    int pageSize = defaultPageSize,
    String? status,
  }) {
    return _getPage(
      '/manager/tasks/',
      page: page,
      pageSize: pageSize,
      filters: {'status': status},
    );
  }

  Future<Map<String, dynamic>> managerCreateTask(Map<String, dynamic> body) {
    return _post('/manager/tasks/', body);
  }

  Future<Map<String, dynamic>> managerUpdateTask(String taskId, Map<String, dynamic> body) {
    return _post('/manager/tasks/$taskId/', body);
  }

  Future<Paginated<Map<String, dynamic>>> adminManagers({
    int page = 1,
    int pageSize = defaultPageSize,
  }) {
    return _getPage('/admin/managers/', page: page, pageSize: pageSize);
  }

  Future<Paginated<Map<String, dynamic>>> adminManagerTasks({
    int page = 1,
    int pageSize = defaultPageSize,
    String? managerId,
    String? status,
  }) {
    return _getPage(
      '/admin/manager-tasks/',
      page: page,
      pageSize: pageSize,
      filters: {'managerId': managerId, 'status': status},
    );
  }

  Future<Map<String, dynamic>> adminCreateManagerTask(Map<String, dynamic> body) {
    return _post('/admin/manager-tasks/', body);
  }

  Future<void> adminDeleteManagerTask(String taskId) async {
    await _delete('/admin/manager-tasks/$taskId/');
  }

  Future<Paginated<Map<String, dynamic>>> adminManagerClients(
    String managerId, {
    int page = 1,
    int pageSize = defaultPageSize,
  }) {
    return _getPage(
      '/admin/managers/$managerId/clients/',
      page: page,
      pageSize: pageSize,
    );
  }

  Future<Map<String, dynamic>> createExpertTicket(Map<String, dynamic> body, {List<int>? fileBytes, String? fileName}) {
    if (fileBytes != null && fileName != null) {
      return _multipartPost('/tickets/create/', body, fileBytes, fileName, fileField: 'photo');
    }
    return _post('/tickets/create/', body);
  }

  Future<Paginated<Map<String, dynamic>>> knowledgeCards({
    int page = 1,
    int pageSize = defaultPageSize,
    String? search,
  }) {
    return _getPage(
      '/knowledge-cards/',
      page: page,
      pageSize: pageSize,
      filters: {'search': search},
    );
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

  Future<Paginated<Map<String, dynamic>>> getRegions({int page = 1, int pageSize = defaultPageSize}) {
    return _getPage('/regions/', page: page, pageSize: pageSize);
  }

  Future<Paginated<Map<String, dynamic>>> getDistributors({int page = 1, int pageSize = defaultPageSize}) {
    return _getPage('/distributors/', page: page, pageSize: pageSize);
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

  Future<void> cancelColorRequest(String id) {
    return _post('/color-requests/$id/cancel/', {});
  }

  Future<void> updateColorRequest(String id, Map<String, dynamic> body) {
    return _post('/color-requests/$id/update/', body);
  }

  Future<Map<String, dynamic>> _multipartPost(
    String path,
    Map<String, dynamic> body,
    List<int> fileBytes,
    String fileName, {
    String fileField = 'file',
  }) async {
    try {
      final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
      final fullUrl = baseUrl.endsWith('/') ? '$baseUrl$normalizedPath' : '$baseUrl/$normalizedPath';
      final request = http.MultipartRequest('POST', Uri.parse(fullUrl));
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
        contentType: _mediaTypeForFile(fileName),
      ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      return _decode(response);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// Maps a file name to its MIME type so multipart uploads send a real
  /// content type instead of the default application/octet-stream.
  MediaType? _mediaTypeForFile(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'mov':
        return MediaType('video', 'quicktime');
      case 'xlsx':
        return MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      case 'xls':
        return MediaType('application', 'vnd.ms-excel');
      default:
        return null;
    }
  }

  Future<Paginated<Map<String, dynamic>>> courierMyTasks({
    int page = 1,
    int pageSize = defaultPageSize,
    String? status,
  }) {
    return _getPage(
      '/courier/tasks/',
      page: page,
      pageSize: pageSize,
      filters: {'status': status},
    );
  }

  Future<Map<String, dynamic>> updateCourierTaskStatus(
    String taskId, {
    required String status,
    String? courierComment,
    List<int>? imageBytes,
    String? fileName,
  }) async {
    final path = '/courier/tasks/$taskId/status/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final fullUrl = baseUrl.endsWith('/') ? '$baseUrl$normalizedPath' : '$baseUrl/$normalizedPath';
    if (imageBytes != null && fileName != null) {
      try {
        final request = http.MultipartRequest('POST', Uri.parse(fullUrl));
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

  Future<Paginated<Map<String, dynamic>>> distributorClients({
    int page = 1,
    int pageSize = defaultPageSize,
    String? search,
  }) {
    return _getPage(
      '/distributor/clients/',
      page: page,
      pageSize: pageSize,
      filters: {'search': search},
    );
  }

  Future<Map<String, dynamic>> verifyPurchase(String id, {required String status, String? reason}) {
    return _patch('/distributor/purchases/$id/verify/', {
      'status': status,
      if (reason != null) 'rejection_reason': reason,
    });
  }

  Future<Paginated<Map<String, dynamic>>> distributorOrders({
    int page = 1,
    int pageSize = defaultPageSize,
    String? status,
  }) {
    return _getPage(
      '/distributor/orders/',
      page: page,
      pageSize: pageSize,
      filters: {'status': status},
    );
  }

  Future<Paginated<Map<String, dynamic>>> distributorDeliveryTasks({
    int page = 1,
    int pageSize = defaultPageSize,
    String? status,
    bool activeOnly = false,
  }) {
    return _getPage(
      '/distributor/delivery-tasks/',
      page: page,
      pageSize: pageSize,
      filters: {
        'status': status,
        'active': activeOnly ? 'true' : null,
      },
    );
  }

  Future<Map<String, dynamic>> updateDeliveryStatus(String taskId, {String? status, String? courierId, String? reason}) async {
    return _post('/distributor/delivery-tasks/$taskId/status/', {
      if (status != null) 'status': status,
      if (courierId != null) 'courierId': courierId,
      if (reason != null) 'reason': reason,
    });
  }

  Future<Paginated<Map<String, dynamic>>> distributorPurchases({
    int page = 1,
    int pageSize = defaultPageSize,
    String? status,
    bool? toVerify,
  }) {
    return _getPage(
      '/distributor/purchases/',
      page: page,
      pageSize: pageSize,
      filters: {
        'status': status,
        'to_verify': toVerify == true ? 'true' : null,
      },
    );
  }

  Future<Paginated<Map<String, dynamic>>> distributorCouriers({
    int page = 1,
    int pageSize = defaultPageSize,
  }) {
    return _getPage('/distributor/couriers/', page: page, pageSize: pageSize);
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

  Future<Paginated<Map<String, dynamic>>> distributorStock({
    int page = 1,
    int pageSize = defaultPageSize,
    String? search,
    String? category,
  }) {
    return _getPage(
      '/distributor/stock/',
      page: page,
      pageSize: pageSize,
      filters: {'search': search, 'category': category},
    );
  }

  Future<Paginated<Map<String, dynamic>>> adminIntegrationTokens({
    int page = 1,
    int pageSize = defaultPageSize,
  }) {
    return _getPage('/admin/integration/tokens/', page: page, pageSize: pageSize);
  }

  Future<Map<String, dynamic>> adminIntegrationGenerate(String distributorId) async {
    return _post('/admin/integration/generate/$distributorId/', {});
  }

  Future<Paginated<Map<String, dynamic>>> adminIntegrationLogs({
    int page = 1,
    int pageSize = defaultPageSize,
  }) {
    return _getPage('/admin/integration/logs/', page: page, pageSize: pageSize);
  }

  Future<Map<String, dynamic>> adminAnalytics({String? regionId, String? distributorId}) async {
    String path = '/admin/analytics/';
    final params = <String>[];
    if (regionId != null) params.add('region=$regionId');
    if (distributorId != null) params.add('distributor=$distributorId');
    if (params.isNotEmpty) path += '?${params.join('&')}';
    return _get(path);
  }

  Future<Map<String, dynamic>> test1CIntegration(List<dynamic> payload, String integrationToken) async {
    try {
      final fullUrl = baseUrl.endsWith('/')
          ? '${baseUrl}integration/erp/stock-update/?dry_run=true'
          : '$baseUrl/integration/erp/stock-update/?dry_run=true';
      final response = await _httpClient
          .post(
            Uri.parse(fullUrl),
            headers: {'Content-Type': 'application/json', 'X-Integration-Token': integrationToken},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 60));
      return _decode(response);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  Future<void> distributorStockUpload(List<Map<String, dynamic>> items) async {
    await _post('/distributor/stock/upload/', {'items': items}, timeout: const Duration(seconds: 60));
  }

  /// Загрузка ассортимента сырым Excel-файлом (шаблон WB «Общие характеристики»).
  /// Парсинг выполняется на сервере — поддерживает многострочную шапку и все поля.
  Future<Map<String, dynamic>> distributorStockUploadFile(
    List<int> fileBytes,
    String fileName,
  ) {
    return _multipartPost('/distributor/stock/upload-file/', {}, fileBytes, fileName, fileField: 'file');
  }

  Future<Map<String, dynamic>> addProduct(Map<String, dynamic> body) async {
    return _post('/distributor/stock/add/', body);
  }

  Future<Paginated<Map<String, dynamic>>> distributorColorRequests({
    int page = 1,
    int pageSize = defaultPageSize,
    String? status,
    bool activeOnly = false,
  }) {
    return _getPage(
      '/distributor/color-requests/',
      page: page,
      pageSize: pageSize,
      filters: {
        'status': status,
        'active': activeOnly ? 'true' : null,
      },
    );
  }

  Future<Map<String, dynamic>> distributorUpdateColorRequest(String id, Map<String, dynamic> body) async {
    return _post('/distributor/color-requests/$id/status/', body);
  }

  Future<Map<String, dynamic>> _patch(String path, dynamic body) async {
    try {
      final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
      final fullUrl = baseUrl.endsWith('/') ? '$baseUrl$normalizedPath' : '$baseUrl/$normalizedPath';
      final response = await _httpClient
          .patch(
            Uri.parse(fullUrl),
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

  /// Выгружает список клиентов файлом. Что попадёт в файл, решает сервер по
  /// роли: дистрибьютору — свои клиенты, менеджеру региона — его регионы,
  /// главному менеджеру — все. Возвращает байты и имя файла из заголовка.
  Future<({Uint8List bytes, String fileName})> exportClients({
    required String format,
    String? search,
    String? status,
    String? partnerStatus,
  }) async {
    final params = <String, String>{'format': format};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (partnerStatus != null && partnerStatus.isNotEmpty) {
      params['partnerStatus'] = partnerStatus;
    }

    final normalizedPath = 'clients/export/';
    final fullUrl = baseUrl.endsWith('/') ? '$baseUrl$normalizedPath' : '$baseUrl/$normalizedPath';
    final uri = Uri.parse(fullUrl).replace(queryParameters: params);

    // Файл может собираться дольше обычного запроса — список бывает большой.
    final response = await _httpClient
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      // Ошибка приходит JSON-ом даже на файловом эндпоинте.
      String message = 'Не удалось выгрузить список (${response.statusCode})';
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map && decoded['detail'] != null) message = '${decoded['detail']}';
      } catch (_) {}
      throw ApiException(message);
    }

    return (
      bytes: response.bodyBytes,
      fileName: _fileNameFrom(response.headers['content-disposition'], format),
    );
  }

  static String _fileNameFrom(String? contentDisposition, String format) {
    final match = RegExp(r'filename="([^"]+)"').firstMatch(contentDisposition ?? '');
    if (match != null) return match.group(1)!;
    final date = DateTime.now().toIso8601String().split('T').first;
    return 'autoterra-clients-$date.$format';
  }

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? params}) async {
    try {
      final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
      final fullUrl = baseUrl.endsWith('/') ? '$baseUrl$normalizedPath' : '$baseUrl/$normalizedPath';
      final uri = Uri.parse(fullUrl).replace(queryParameters: params);
      final response = await _httpClient
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 15));
      return _decode(response);
    } catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  /// GET списочного эндпоинта: подставляет параметры пагинации и разбирает
  /// ответ в [Paginated]. Пустые значения фильтров отбрасываются, чтобы не
  /// слать в запрос лишние ключи.
  Future<Paginated<Map<String, dynamic>>> _getPage(
    String path, {
    int page = 1,
    int pageSize = defaultPageSize,
    Map<String, String?>? filters,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
    };
    filters?.forEach((key, value) {
      if (value != null && value.isNotEmpty) params[key] = value;
    });
    final result = await _get(path, params: params);
    return Paginated.fromResponse(result);
  }

  /// Как [_getPage], но дополнительно отдаёт сырой ответ — нужно там, где
  /// рядом со списком приходят агрегаты (`stats`, `categories`, `unreadCount`).
  Future<(Paginated<Map<String, dynamic>>, Map<String, dynamic>)> _getPageWithMeta(
    String path, {
    int page = 1,
    int pageSize = defaultPageSize,
    Map<String, String?>? filters,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
    };
    filters?.forEach((key, value) {
      if (value != null && value.isNotEmpty) params[key] = value;
    });
    final result = await _get(path, params: params);
    return (Paginated.fromResponse(result), result);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    dynamic body, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
      final fullUrl = baseUrl.endsWith('/') ? '$baseUrl$normalizedPath' : '$baseUrl/$normalizedPath';
      final response = await _httpClient
          .post(
            Uri.parse(fullUrl),
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

  Future<Map<String, dynamic>> _delete(String path) async {
    try {
      final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
      final fullUrl = baseUrl.endsWith('/') ? '$baseUrl$normalizedPath' : '$baseUrl/$normalizedPath';
      final response = await _httpClient
          .delete(Uri.parse(fullUrl), headers: _headers())
          .timeout(const Duration(seconds: 15));
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
