import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../models/paginated.dart';
import 'api_client.dart';
import 'package:url_launcher/url_launcher.dart';

class ProductData {
  final String id;
  final String distributorId;
  final String sku;
  final String? wbArticle;
  final String? groupName;
  final String name;
  final String category;
  final String brand;
  final String? description;
  final String? color;
  final String? barcode;
  final List<String> images;
  final String? videoUrl;
  final double volume;
  final double weight;
  final double packageHeight;
  final double packageLength;
  final double packageWidth;
  final String? tnved;
  final String? vatRate;
  final double price;
  final int quantity;
  final StockStatus status;
  final DateTime updatedAt;

  const ProductData({
    required this.id,
    required this.distributorId,
    required this.sku,
    this.wbArticle,
    this.groupName,
    required this.name,
    required this.category,
    required this.brand,
    this.description,
    this.color,
    this.barcode,
    this.images = const [],
    this.videoUrl,
    required this.volume,
    this.weight = 0,
    this.packageHeight = 0,
    this.packageLength = 0,
    this.packageWidth = 0,
    this.tnved,
    this.vatRate,
    required this.price,
    required this.quantity,
    required this.status,
    required this.updatedAt,
  });
}

class StoreData {
  final String id;
  final String name;
  final String address;
  final bool isActive;
  final DateTime createdAt;

  const StoreData({
    required this.id,
    required this.name,
    required this.address,
    required this.isActive,
    required this.createdAt,
  });
}

class OrderConfigData {
  final Client client;
  final Distributor distributor;
  final List<StoreData> stores;
  final List<ProductData> products;

  const OrderConfigData({
    required this.client,
    required this.distributor,
    required this.stores,
    required this.products,
  });
}

class DashboardData {
  final Client client;
  final Distributor distributor;
  final int unreadCount;
  final List<Purchase> recentPurchases;
  final List<ColorRequest> activeColorRequests;
  final bool fromBackend;

  const DashboardData({
    required this.client,
    required this.distributor,
    required this.unreadCount,
    required this.recentPurchases,
    required this.activeColorRequests,
    required this.fromBackend,
  });
}

class DistributorDashboardData {
  final DistributorDashboardMetrics metrics;
  final List<Order> recentOrders;
  final List<Purchase> pendingPurchases;
  final List<CourierTask> recentDeliveryTasks;
  final List<ColorRequest> pendingColorRequests;

  const DistributorDashboardData({
    required this.metrics,
    required this.recentOrders,
    required this.pendingPurchases,
    required this.recentDeliveryTasks,
    required this.pendingColorRequests,
  });
}

class DataRepository {
  final ApiClient _api;
  ApiClient get api => _api;

  DataRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<void> downloadReport({String? regionId}) async {
    final url = Uri.parse(_api.exportUrl(regionId: regionId));
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  Future<DashboardData> dashboard() async {
    final data = await _api.dashboard();
    return DashboardData(
      client: _clientFromJson(data['client'] as Map<String, dynamic>),
      distributor: distributorFromJson(
        data['distributor'] as Map<String, dynamic>,
      ),
      unreadCount: (data['unreadCount'] as num? ?? 0).toInt(),
      recentPurchases: _list(
        data['recentPurchases'] ?? [],
      ).map((item) => _purchaseFromJson(item)).toList(),
      activeColorRequests: _list(
        data['activeColorRequests'] ?? [],
      ).map((item) => _colorRequestFromJson(item)).toList(),
      fromBackend: true,
    );
  }

  Future<DistributorDashboardData> distributorDashboard() async {
    final data = await _api.distributorDashboard();
    // На дашборде показываются только свежие записи — берём первую
    // короткую страницу вместо полного списка.
    const previewSize = 10;
    final orders = await _api.distributorOrders(pageSize: previewSize);
    final purchases = await _api.distributorPurchases(toVerify: true, pageSize: previewSize);
    final deliveryTasks = await _api.distributorDeliveryTasks(pageSize: previewSize);
    final colorRequests = await _api.distributorColorRequests(pageSize: previewSize);

    return DistributorDashboardData(
      metrics: _distributorMetricsFromJson(
        data['metrics'] ?? data,
      ),
      recentOrders: orders.items.map((item) => _orderFromJson(item)).toList(),
      pendingPurchases: purchases.items.map((item) => _purchaseFromJson(item)).toList(),
      recentDeliveryTasks: deliveryTasks.items.map((item) => _courierTaskFromJson(item)).toList(),
      pendingColorRequests: colorRequests.items.map((item) => _colorRequestFromJson(item)).toList(),
    );
  }

  static DistributorDashboardMetrics _distributorMetricsFromJson(
    Map<String, dynamic> json,
  ) {
    return DistributorDashboardMetrics(
      clients: (json['clients'] as num? ?? 0).toInt(),
      purchasesToVerify: (json['purchasesToVerify'] as num? ?? 0).toInt(),
      ordersToProcess: (json['ordersToProcess'] as num? ?? 0).toInt(),
      deliveriesToAssign: (json['deliveriesToAssign'] as num? ?? 0).toInt(),
      colorLabPending: (json['colorLabPending'] as num? ?? 0).toInt(),
    );
  }

  Future<OrderConfigData> orderConfig() async {
    final data = await _api.orderConfig();
    return OrderConfigData(
      client: _clientFromJson(data['client'] as Map<String, dynamic>),
      distributor: distributorFromJson(
        data['distributor'] as Map<String, dynamic>,
      ),
      stores: _list(data['stores']).map(_storeFromJson).toList(),
      products: _list(data['products']).map(_productFromJson).toList(),
    );
  }

  /// Магазины клиента целиком — список короткий и нужен в выпадающих списках.
  Future<List<Store>> clientStores() {
    return fetchAllPages((page) async {
      final result = await _api.stores(page: page);
      return result.map(Store.fromJson);
    });
  }

  Future<Store> createStore(String name, String address) async {
    final result = await _api.createStore(name, address);
    return Store.fromJson(result['store'] as Map<String, dynamic>);
  }

  Future<Store> updateStore(String storeId, String name, String address) async {
    final result = await _api.updateStore(storeId, name, address);
    return Store.fromJson(result['store'] as Map<String, dynamic>);
  }

  Future<void> deleteStore(String storeId) => _api.deleteStore(storeId);

  /// Покупки вместе со сводкой по всей выборке. У дистрибьютора сводки нет —
  /// он видит чужие покупки на проверке, итоги там не показываются.
  Future<(Paginated<Purchase>, Map<String, dynamic>)> purchases({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
  }) async {
    Paginated<Map<String, dynamic>> result;
    Map<String, dynamic> stats = const {};
    if (ApiClient.role == 'distributor') {
      result = await _api.distributorPurchases(page: page, pageSize: pageSize);
    } else {
      (result, stats) = await _api.purchases(page: page, pageSize: pageSize);
    }
    final parsed = await compute(_parsePurchaseList, result.items);
    return (Paginated(items: parsed, pageInfo: result.pageInfo), stats);
  }

  static List<Purchase> _parsePurchaseList(List<dynamic> items) {
    return items.map((i) => _purchaseFromJson(i as Map<String, dynamic>)).toList();
  }

  Future<Paginated<Order>> orders({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
  }) async {
    final result = (ApiClient.role == 'distributor')
        ? await _api.distributorOrders(page: page, pageSize: pageSize)
        : await _api.orders(page: page, pageSize: pageSize);
    final parsed = await compute(_parseOrderList, result.items);
    return Paginated(items: parsed, pageInfo: result.pageInfo);
  }

  static List<Order> _parseOrderList(List<dynamic> items) {
    return items.map((i) => _orderFromJson(i as Map<String, dynamic>)).toList();
  }

  Future<Paginated<ColorRequest>> colorRequests({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
    bool activeOnly = false,
  }) async {
    final result = await _api.colorRequests(
      page: page,
      pageSize: pageSize,
      activeOnly: activeOnly,
    );
    return result.map(_colorRequestFromJson);
  }

  Future<Paginated<Purchase>> distributorPurchases({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
    String? status,
    bool? toVerify,
  }) async {
    final result = await _api.distributorPurchases(
      page: page,
      pageSize: pageSize,
      status: status,
      toVerify: toVerify,
    );
    return result.map(_purchaseFromJson);
  }

  Future<Paginated<Client>> distributorClients({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
    String? search,
  }) async {
    final result = await _api.distributorClients(
      page: page,
      pageSize: pageSize,
      search: search,
    );
    return result.map(_clientFromJson);
  }

  Future<Purchase> verifyPurchase(String id, {required bool verify, String? reason}) async {
    final result = await _api.verifyPurchase(
      id, 
      status: verify ? 'verified' : 'rejected',
      reason: reason,
    );
    return _purchaseFromJson(result['purchase'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> distributorIntegration() {
    return _api.distributorIntegration();
  }

  Future<void> generateIntegrationToken() async {
    await _api.generateIntegrationToken();
  }

  Future<Paginated<Order>> distributorOrders({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
    String? status,
  }) async {
    final result = await _api.distributorOrders(
      page: page,
      pageSize: pageSize,
      status: status,
    );
    return result.map(_orderFromJson);
  }

  Future<Paginated<CourierTask>> distributorDeliveryTasks({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
    String? status,
  }) async {
    final result = await _api.distributorDeliveryTasks(
      page: page,
      pageSize: pageSize,
      status: status,
    );
    return result.map(_courierTaskFromJson);
  }

  Future<void> updateDeliveryStatus(String taskId, {String? status, String? courierId, String? reason}) async {
    await _api.updateDeliveryStatus(taskId, status: status, courierId: courierId, reason: reason);
  }

  Future<Paginated<ProductData>> distributorStock({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
    String? search,
    String? category,
  }) async {
    final result = await _api.distributorStock(
      page: page,
      pageSize: pageSize,
      search: search,
      category: category,
    );
    // Use compute for large lists to keep UI responsive
    final parsed = await compute(_parseProductList, result.items);
    return Paginated(items: parsed, pageInfo: result.pageInfo);
  }

  static List<ProductData> _parseProductList(List<dynamic> items) {
    return items.map((i) => _productFromJson(i as Map<String, dynamic>)).toList();
  }

  /// Курьеры целиком — используются в выпадающем списке назначения.
  Future<List<Map<String, dynamic>>> distributorCouriers() {
    return fetchAllPages((page) => _api.distributorCouriers(page: page));
  }

  Future<void> distributorStockUpload(List<Map<String, dynamic>> items) async {
    await _api.distributorStockUpload(items);
  }

  /// Загружает Excel-файл ассортимента на сервер (парсинг на бэкенде).
  /// Возвращает {created, updated, processed, errors}.
  Future<Map<String, dynamic>> distributorStockUploadFile(
    List<int> fileBytes,
    String fileName,
  ) async {
    return _api.distributorStockUploadFile(fileBytes, fileName);
  }

  Future<void> addProduct(Map<String, dynamic> data) async {
    await _api.addProduct(data);
  }

  Future<Paginated<ColorRequest>> distributorColorRequests({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
    String? status,
    bool activeOnly = false,
  }) async {
    final result = await _api.distributorColorRequests(
      page: page,
      pageSize: pageSize,
      status: status,
      activeOnly: activeOnly,
    );
    return result.map(_colorRequestFromJson);
  }

  Future<ColorRequest> distributorUpdateColorRequest(String id, Map<String, dynamic> body) async {
    final result = await _api.distributorUpdateColorRequest(id, body);
    return _colorRequestFromJson(result['request'] as Map<String, dynamic>);
  }

  Future<Order> updateOrderStatus(String id, {required String status, String? reason, String? courierId, String? estimatedDeliveryDate}) async {
    final result = await _api.updateOrderStatus(
      id, 
      status: status, 
      reason: reason,
      courierId: courierId,
      estimatedDeliveryDate: estimatedDeliveryDate,
    );
    return _orderFromJson(result['order'] as Map<String, dynamic>);
  }

  Future<Paginated<Map<String, dynamic>>> adminIntegrationTokens({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
  }) {
    return _api.adminIntegrationTokens(page: page, pageSize: pageSize);
  }

  Future<Map<String, dynamic>> adminIntegrationGenerate(String distributorId) {
    return _api.adminIntegrationGenerate(distributorId);
  }

  Future<Paginated<Map<String, dynamic>>> adminIntegrationLogs({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
  }) {
    return _api.adminIntegrationLogs(page: page, pageSize: pageSize);
  }

  Future<Map<String, dynamic>> adminAnalytics({String? regionId, String? distributorId}) {
    return _api.adminAnalytics(regionId: regionId, distributorId: distributorId);
  }

  Future<void> createCourierTask(Map<String, dynamic> data) async {
    await _api.createCourierTask(data);
  }

  Future<void> cancelCourierTask(String id) async {
    await _api.cancelCourierTask(id);
  }

  Future<void> updateCourierTask(String id, Map<String, dynamic> data) async {
    await _api.updateCourierTask(id, data);
  }

  Future<Paginated<CourierTask>> courierTasks({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
    String? status,
    bool activeOnly = false,
  }) async {
    final result = (ApiClient.role == 'distributor')
        ? await _api.distributorDeliveryTasks(
            page: page,
            pageSize: pageSize,
            status: status,
            activeOnly: activeOnly,
          )
        : await _api.courierTasks(
            page: page,
            pageSize: pageSize,
            activeOnly: activeOnly,
          );
    return result.map(_courierTaskFromJson);
  }

  Future<Paginated<CourierTask>> courierMyTasks({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
    String? status,
  }) async {
    final result = await _api.courierMyTasks(
      page: page,
      pageSize: pageSize,
      status: status,
    );
    return result.map(_courierTaskFromJson);
  }

  Future<CourierTask> updateCourierTaskStatus(
    String taskId, {
    required String status,
    String? courierComment,
    List<int>? imageBytes,
    String? fileName,
  }) async {
    final result = await _api.updateCourierTaskStatus(
      taskId,
      status: status,
      courierComment: courierComment,
      imageBytes: imageBytes,
      fileName: fileName,
    );
    return _courierTaskFromJson(result['task'] as Map<String, dynamic>);
  }

  Future<ExpertTicket> expertAnswerTicket(
    String ticketId, {
    required String answer,
    String? causes,
    bool createKnowledgeCard = false,
  }) async {
    final result = await _api.expertAnswerTicket(
      ticketId,
      answer: answer,
      causes: causes,
      createKnowledgeCard: createKnowledgeCard,
    );
    return _ticketFromJson(result['ticket'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> managerDashboard({String? regionId, String? distributorId}) {
    return _api.managerDashboard(regionId: regionId, distributorId: distributorId);
  }

  Future<Referral> createReferral(Map<String, dynamic> data) async {
    final result = await _api.createReferral(data);
    return _referralFromJson(result['referral'] as Map<String, dynamic>);
  }

  /// Рефералы вместе со сводной статистикой, которая приходит тем же ответом.
  Future<(Paginated<Referral>, Map<String, dynamic>)> referrals({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
  }) async {
    final (result, stats) = await _api.referrals(page: page, pageSize: pageSize);
    return (result.map(_referralFromJson), stats);
  }

  Future<Paginated<ExpertTicket>> tickets({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
  }) async {
    final result = await _api.tickets(page: page, pageSize: pageSize);
    return result.map(_ticketFromJson);
  }

  Future<Paginated<Notification>> notifications({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
  }) async {
    final result = await _api.notifications(page: page, pageSize: pageSize);
    return result.map(_notificationFromJson);
  }

  Future<void> markNotificationsRead() async {
    await _api.markNotificationsRead();
  }

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'info',
    String? relatedLink,
  }) async {
    await _api.sendNotification(
      userId: userId,
      title: title,
      body: body,
      type: type,
      relatedLink: relatedLink,
    );
  }

  Future<Paginated<Client>> managerClients({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
  }) async {
    final result = await _api.managerClients(page: page, pageSize: pageSize);
    return result.map(_clientFromJson);
  }

  Future<Map<String, dynamic>> managerClientUnified(String clientId) {
    return _api.managerClientUnified(clientId);
  }

  Future<Paginated<Client>> managerClientsFiltered({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
    String? status,
    String? category,
    String? regionId,
    String? distributorId,
    String? search,
  }) async {
    final result = await _api.managerClientsFiltered(
      page: page,
      pageSize: pageSize,
      status: status,
      category: category,
      regionId: regionId,
      distributorId: distributorId,
      search: search,
    );
    return result.map(_clientFromJson);
  }

  Future<Client> managerCreateClient(Map<String, dynamic> data) async {
    final result = await _api.managerCreateClient(data);
    return _clientFromJson(result['client'] as Map<String, dynamic>);
  }

  Future<void> managerUpdateClientStatus(String clientId, String status) async {
    await _api.managerUpdateClientStatus(clientId, status);
  }

  Future<Paginated<ContactHistoryEntry>> managerClientHistory(
    String clientId, {
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
  }) async {
    final result = await _api.managerClientHistory(
      clientId,
      page: page,
      pageSize: pageSize,
    );
    return result.map(ContactHistoryEntry.fromJson);
  }

  Future<ContactHistoryEntry> managerAddContactHistory(String clientId, Map<String, dynamic> data) async {
    final result = await _api.managerAddContactHistory(clientId, data);
    return ContactHistoryEntry.fromJson(result['entry'] as Map<String, dynamic>);
  }

  Future<Paginated<ManagerTask>> managerTasks({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
    String? status,
  }) async {
    final result = await _api.managerTasks(
      page: page,
      pageSize: pageSize,
      status: status,
    );
    return result.map(ManagerTask.fromJson);
  }

  Future<ManagerTask> managerCreateTask(Map<String, dynamic> data) async {
    final result = await _api.managerCreateTask(data);
    return ManagerTask.fromJson(result['task'] as Map<String, dynamic>);
  }

  Future<ManagerTask> managerUpdateTask(String taskId, Map<String, dynamic> data) async {
    final result = await _api.managerUpdateTask(taskId, data);
    return ManagerTask.fromJson(result['task'] as Map<String, dynamic>);
  }

  /// Менеджеры целиком — список используется в выпадающих фильтрах.
  Future<List<Map<String, dynamic>>> adminManagers() {
    return fetchAllPages((page) => _api.adminManagers(page: page));
  }

  Future<Paginated<ManagerTask>> adminManagerTasks({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
    String? managerId,
    String? status,
  }) async {
    final result = await _api.adminManagerTasks(
      page: page,
      pageSize: pageSize,
      managerId: managerId,
      status: status,
    );
    return result.map(ManagerTask.fromJson);
  }

  Future<ManagerTask> adminCreateManagerTask(Map<String, dynamic> data) async {
    final result = await _api.adminCreateManagerTask(data);
    return ManagerTask.fromJson(result['task'] as Map<String, dynamic>);
  }

  Future<void> adminDeleteManagerTask(String taskId) => _api.adminDeleteManagerTask(taskId);

  /// Клиенты менеджера целиком — используются в выпадающем списке при
  /// назначении задачи.
  Future<List<Map<String, dynamic>>> adminManagerClients(String managerId) {
    return fetchAllPages((page) => _api.adminManagerClients(managerId, page: page));
  }

  Future<Map<String, dynamic>> me() {
    return _api.me();
  }

  Future<Paginated<KnowledgeCard>> knowledgeCards({
    int page = 1,
    int pageSize = ApiClient.defaultPageSize,
    String? search,
  }) async {
    final result = await _api.knowledgeCards(
      page: page,
      pageSize: pageSize,
      search: search,
    );
    return result.map(_knowledgeCardFromJson);
  }

  Future<KnowledgeCard> createKnowledgeCard(Map<String, dynamic> data) async {
    final result = await _api.createKnowledgeCard(data);
    return _knowledgeCardFromJson(result['card'] as Map<String, dynamic>);
  }

  Future<KnowledgeCard> updateKnowledgeCard(String id, {bool? isApproved, String? problem, String? solution, String? causes}) async {
    final result = await _api.updateKnowledgeCard(id, {
      if (isApproved != null) 'status': isApproved ? 'approved' : 'draft',
      if (problem != null) 'problem': problem,
      if (solution != null) 'solution': solution,
      if (causes != null) 'causes': causes,
    });
    return _knowledgeCardFromJson(result['card'] as Map<String, dynamic>);
  }

  Future<void> createOrder({
    String? storeId,
    String? deliveryMethod,
    required List<Map<String, dynamic>> items,
    required String comment,
  }) async {
    await _api.createOrder(
      storeId: storeId, 
      deliveryMethod: deliveryMethod,
      items: items, 
      comment: comment
    );
  }

  Future<void> cancelOrder(String orderId) async {
    await _api.cancelOrder(orderId);
  }

  Future<Order> orderDetail(String orderId) async {
    final res = await _api.orderDetail(orderId);
    return _orderFromJson(Map<String, dynamic>.from(res['order'] as Map));
  }

  // ── Безопасный поток заказа ──────────────────────────────────────────────────

  /// Подтверждение заказа оператором.
  ///
  /// Если по позициям не хватает остатков, сервер отвечает 409 и списком
  /// дефицитов. Разворачиваем это в [OrderShortageException], чтобы экран мог
  /// предложить корректировку вместо показа сырой ошибки. [force] пропускает
  /// проверку — оператор подтверждает под свою ответственность.
  Future<Order> confirmOrder(String orderId, {bool force = false}) async {
    try {
      final res = await _api.confirmOrder(orderId, force: force);
      return _orderFromJson(Map<String, dynamic>.from(res['order'] as Map));
    } on ApiException catch (e) {
      final shortages = OrderShortage.parseList(e.details);
      if (shortages.isEmpty) rethrow;
      throw OrderShortageException(e.message, shortages);
    }
  }

  Future<Order> adjustOrder(
    String orderId, {
    required List<Map<String, dynamic>> items,
    String reason = '',
  }) async {
    final res = await _api.adjustOrder(orderId, items: items, reason: reason);
    return _orderFromJson(Map<String, dynamic>.from(res['order'] as Map));
  }

  Future<Order> rejectOrder(String orderId, {String reason = ''}) async {
    final res = await _api.rejectOrder(orderId, reason: reason);
    return _orderFromJson(Map<String, dynamic>.from(res['order'] as Map));
  }

  Future<Order> shipOrder(String orderId) async {
    final res = await _api.shipOrder(orderId);
    return _orderFromJson(Map<String, dynamic>.from(res['order'] as Map));
  }

  Future<Order> acceptAdjustment(String orderId) async {
    final res = await _api.acceptAdjustment(orderId);
    return _orderFromJson(Map<String, dynamic>.from(res['order'] as Map));
  }

  /// Инициирует оплату. Возвращает confirmationUrl (ссылку YooKassa) либо null.
  Future<String?> payOrder(String orderId) async {
    final res = await _api.payOrder(orderId);
    final payment = res['payment'];
    if (payment is Map && payment['confirmationUrl'] != null) {
      return payment['confirmationUrl'].toString();
    }
    return null;
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) {
    return _api.register(data);
  }

  /// Справочники регионов и дистрибьюторов целиком — идут в выпадающие списки
  /// форм регистрации и фильтров.
  Future<List<Map<String, dynamic>>> getRegions() {
    return fetchAllPages((page) => _api.getRegions(page: page));
  }

  Future<List<Map<String, dynamic>>> getDistributors() {
    return fetchAllPages((page) => _api.getDistributors(page: page));
  }

  Future<Map<String, dynamic>> createPurchase(Map<String, dynamic> data, {List<int>? fileBytes, String? fileName}) {
    return _api.createPurchase(data, fileBytes: fileBytes, fileName: fileName);
  }

  Future<Map<String, dynamic>> createColorRequest(Map<String, dynamic> data, {List<int>? fileBytes, String? fileName}) {
    return _api.createColorRequest(data, fileBytes: fileBytes, fileName: fileName);
  }

  Future<void> cancelColorRequest(String id) {
    return _api.cancelColorRequest(id);
  }

  Future<void> updateColorRequest(String id, Map<String, dynamic> data) {
    return _api.updateColorRequest(id, data);
  }

  Future<Map<String, dynamic>> createExpertTicket(Map<String, dynamic> data, {List<int>? fileBytes, String? fileName}) {
    return _api.createExpertTicket(data, fileBytes: fileBytes, fileName: fileName);
  }

  Future<Map<String, dynamic>> test1CIntegration(List<dynamic> payload, String integrationToken) {
    return _api.test1CIntegration(payload, integrationToken);
  }

  static List<Map<String, dynamic>> _list(Object? value) {
    if (value == null) return [];
    return (value as List<dynamic>).cast<Map<String, dynamic>>();
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String? _toString(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return value.toString();
  }

  static Client _clientFromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'].toString(),
      externalId: _toString(json['externalId']),
      inn: json['inn'].toString(),
      name: json['name']?.toString() ?? 'Без названия',
      category: _clientCategory(json['category']?.toString() ?? 'b'),
      region: json['region']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      contact: json['contact']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      distributorId: json['distributorId']?.toString() ?? '',
      managerId: _toString(json['managerId']),
      status: _clientStatus(json['status']?.toString() ?? 'active'),
      partnerStatus: json['partnerStatus']?.toString() ?? 'Silver',
      totalPurchases: _toDouble(json['totalPurchases']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      distributorName: _toString(json['distributorName']),
      regionId: _toString(json['regionId']),
    );
  }

  static Distributor distributorFromJson(Map<String, dynamic> json) {
    return Distributor(
      id: json['id'].toString(),
      externalId: _toString(json['externalId']),
      name: json['name']?.toString() ?? 'Неизвестно',
      inn: json['inn']?.toString() ?? '',
      regions: (json['regions'] as List<dynamic>?)?.cast<String>() ?? [],
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  static StoreData _storeFromJson(Map<String, dynamic> json) {
    return StoreData(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static ProductData _productFromJson(Map<String, dynamic> json) {
    return ProductData(
      id: json['id'].toString(),
      distributorId: json['distributorId']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      wbArticle: _toString(json['wbArticle']),
      groupName: _toString(json['groupName']),
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      description: _toString(json['description']),
      color: _toString(json['color']),
      barcode: _toString(json['barcode']),
      images: (json['images'] is List)
          ? (json['images'] as List).map((e) => e.toString()).toList()
          : <String>[],
      videoUrl: _toString(json['videoUrl']),
      volume: _toDouble(json['volume']),
      weight: _toDouble(json['weight']),
      packageHeight: _toDouble(json['packageHeight']),
      packageLength: _toDouble(json['packageLength']),
      packageWidth: _toDouble(json['packageWidth']),
      tnved: _toString(json['tnved']),
      vatRate: _toString(json['vatRate']),
      price: _toDouble(json['price']),
      quantity: _toInt(json['quantity']),
      status: _stockStatus(json['status']?.toString() ?? 'inStock'),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static Order _orderFromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'].toString(),
      externalId: _toString(json['externalId']),
      clientId: json['clientId']?.toString() ?? '',
      clientName: _toString(json['clientName']),
      clientInn: _toString(json['clientInn']),
      distributorId: json['distributorId']?.toString() ?? '',
      storeName: json['storeName']?.toString() ?? '',
      documentNumber: json['documentNumber']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      totalAmount: _toDouble(json['totalAmount']),
      status: _orderStatus(json['status']?.toString() ?? 'new'),
      deliveryMethod: json['deliveryMethod']?.toString() ?? 'courier',
      items: _list(json['items']).map((item) => _purchaseItemFromJson(item)).toList(),
      comment: _toString(json['comment']),
      rejectionReason: _toString(json['rejectionReason']),
      courierId: _toString(json['courierId']),
      courierName: _toString(json['courierName']),
      estimatedDeliveryDate: json['estimatedDeliveryDate'] != null ? DateTime.tryParse(json['estimatedDeliveryDate'].toString()) : null,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      confirmedAt: json['confirmedAt'] != null ? DateTime.tryParse(json['confirmedAt'].toString()) : null,
      paidAt: json['paidAt'] != null ? DateTime.tryParse(json['paidAt'].toString()) : null,
      shippedAt: json['shippedAt'] != null ? DateTime.tryParse(json['shippedAt'].toString()) : null,
      isPayable: json['isPayable'] == true,
      adjustments: _list(json['adjustments']).map((a) => _orderAdjustmentFromJson(a)).toList(),
      pendingPaymentUrl: json['pendingPayment'] is Map
          ? _toString((json['pendingPayment'] as Map)['confirmationUrl'])
          : null,
    );
  }

  static OrderAdjustment _orderAdjustmentFromJson(Map<String, dynamic> json) {
    return OrderAdjustment(
      id: json['id'].toString(),
      originalItems: _list(json['originalItems']).map((i) => _purchaseItemFromJson(i)).toList(),
      adjustedItems: _list(json['adjustedItems']).map((i) => _purchaseItemFromJson(i)).toList(),
      reason: _toString(json['reason']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static Purchase _purchaseFromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'].toString(),
      clientId: json['clientId']?.toString() ?? '',
      clientName: _toString(json['clientName']),
      clientInn: _toString(json['clientInn']),
      distributorId: json['distributorId']?.toString() ?? '',
      documentNumber: json['documentNumber']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      totalAmount: _toDouble(json['totalAmount']),
      status: _purchaseStatus(json['status']?.toString() ?? 'pending'),
      orderStatus: _toString(json['orderStatus']),
      items: _list(json['items']).map((item) => _purchaseItemFromJson(item)).toList(),
      documentUrl: _toString(json['documentUrl']),
      attachments: _list(json['attachments']).map((item) => AppAttachment.fromJson(item)).toList(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  static PurchaseItem _purchaseItemFromJson(Map<String, dynamic> json) {
    final available = json['availableQuantity'];
    return PurchaseItem(
      id: json['id']?.toString(),
      productId: json['productId']?.toString(),
      availableQuantity: available == null ? null : _toInt(available),
      sku: json['sku']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      quantity: _toInt(json['quantity']),
      volume: _toDouble(json['volume']),
      price: _toDouble(json['price']),
      brand: json['brand']?.toString() ?? '',
    );
  }

  static ColorRequest _colorRequestFromJson(Map<String, dynamic> json) {
    return ColorRequest.fromJson(json);
  }

  static CourierTask _courierTaskFromJson(Map<String, dynamic> json) {
    return CourierTask.fromJson(json);
  }

  static Referral _referralFromJson(Map<String, dynamic> json) {
    return Referral(
      id: json['id'] as String,
      inviterId: json['inviterId'] as String,
      inviteeInn: json['inviteeInn'] as String,
      inviteeName: json['inviteeName'] as String,
      region: json['region'] as String,
      isRegistered: json['isRegistered'] as bool? ?? false,
      hasPurchase: json['hasPurchase'] as bool? ?? false,
      purchaseAmount: (json['purchaseAmount'] as num).toDouble(),
      conditionMet: json['conditionMet'] as bool? ?? false,
      gift: json['gift'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static ExpertTicket _ticketFromJson(Map<String, dynamic> json) {
    return ExpertTicket(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      question: json['question'] as String,
      category: json['category'] as String,
      risk: json['risk'] as String? ?? 'low',
      aiAnswer: json['aiAnswer'] as String?,
      aiDraftAnswer: json['aiDraftAnswer'] as String?,
      similarCases: (json['similarCases'] as List<dynamic>?)?.cast<String>() ?? [],
      expertAnswer: json['expertAnswer'] as String?,
      status: _ticketStatus(json['status'] as String),
      photo: json['photo'] as String?,
      videoLink: json['videoLink'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static Notification _notificationFromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: _notificationType(json['type'] as String),
      relatedLink: json['relatedLink'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static KnowledgeCard _knowledgeCardFromJson(Map<String, dynamic> json) {
    return KnowledgeCard(
      id: json['id'] as String,
      problem: json['problem'] as String,
      causes: json['causes'] as String,
      solution: json['solution'] as String,
      skus: (json['skus'] as List<dynamic>).cast<String>(),
      restrictions: json['restrictions'] as String?,
      approvingExpert: json['approvingExpert'] as String,
      isApproved: json['isApproved'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static ClientCategory _clientCategory(String value) {
    return ClientCategory.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ClientCategory.b,
    );
  }

  static ClientStatus _clientStatus(String value) {
    return ClientStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ClientStatus.active,
    );
  }

  static PurchaseStatus _purchaseStatus(String value) {
    switch (value) {
      case 'new':
        return PurchaseStatus.newPurchase;
      case 'pending':
        return PurchaseStatus.pending;
      case 'pending_verification':
        return PurchaseStatus.pendingVerification;
      case 'under_review':
        return PurchaseStatus.underReview;
      case 'duplicate_review':
        return PurchaseStatus.duplicateReview;
      case 'verified':
        return PurchaseStatus.verified;
      case 'rejected':
        return PurchaseStatus.rejected;
      default:
        return PurchaseStatus.pending;
    }
  }

  static OrderStatus _orderStatus(String value) {
    switch (value) {
      case 'new':
        return OrderStatus.newOrder;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'adjusted':
        return OrderStatus.adjusted;
      case 'accepted':
        return OrderStatus.accepted;
      case 'rejected':
        return OrderStatus.rejected;
      case 'paid':
        return OrderStatus.paid;
      case 'shipped':
        return OrderStatus.shipped;
      case 'fulfilled':
        return OrderStatus.fulfilled;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.newOrder;
    }
  }

  static StockStatus _stockStatus(String value) {
    return StockStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => StockStatus.inStock,
    );
  }

  static ColorRequestStatus _colorRequestStatus(String value) {
    return ColorRequestStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => ColorRequestStatus.created,
    );
  }

  static CourierTaskStatus _courierTaskStatus(String value) {
    switch (value) {
      case 'in_progress':
        return CourierTaskStatus.inProgress;
      case 'delivered':
        return CourierTaskStatus.delivered;
      case 'returned':
        return CourierTaskStatus.returned;
      case 'cancelled':
        return CourierTaskStatus.cancelled;
      default:
        return CourierTaskStatus.assigned;
    }
  }

  static TicketStatus _ticketStatus(String value) {
    return TicketStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => TicketStatus.open,
    );
  }

  static NotificationType _notificationType(String value) {
    return NotificationType.values.firstWhere(
      (item) => item.name == value,
      orElse: () => NotificationType.system,
    );
  }
}
