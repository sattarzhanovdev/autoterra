import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'package:url_launcher/url_launcher.dart';

class ProductData {
  final String id;
  final String distributorId;
  final String sku;
  final String name;
  final String category;
  final String brand;
  final double volume;
  final double price;
  final int quantity;
  final StockStatus status;
  final DateTime updatedAt;

  const ProductData({
    required this.id,
    required this.distributorId,
    required this.sku,
    required this.name,
    required this.category,
    required this.brand,
    required this.volume,
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
    final orders = await _api.distributorOrders();
    final purchases = await _api.distributorPurchases(toVerify: true);
    final deliveryTasks = await _api.distributorDeliveryTasks();
    final colorRequests = await _api.distributorColorRequests();

    return DistributorDashboardData(
      metrics: _distributorMetricsFromJson(
        data['metrics'] ?? data,
      ),
      recentOrders: orders.map((item) => _orderFromJson(item)).toList(),
      pendingPurchases: purchases.map((item) => _purchaseFromJson(item)).toList(),
      recentDeliveryTasks: deliveryTasks.map((item) => _courierTaskFromJson(item)).toList(),
      pendingColorRequests: _list(colorRequests['results']).map((item) => _colorRequestFromJson(item)).toList(),
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

  Future<List<Purchase>> purchases() async {
    final items = (ApiClient.role == 'distributor') 
        ? await _api.distributorPurchases()
        : await _api.purchases();
    return compute(_parsePurchaseList, items);
  }

  static List<Purchase> _parsePurchaseList(List<dynamic> items) {
    return items.map((i) => _purchaseFromJson(i as Map<String, dynamic>)).toList();
  }

  Future<List<Order>> orders() async {
    final items = (ApiClient.role == 'distributor')
        ? await _api.distributorOrders()
        : await _api.orders();
    return compute(_parseOrderList, items);
  }

  static List<Order> _parseOrderList(List<dynamic> items) {
    return items.map((i) => _orderFromJson(i as Map<String, dynamic>)).toList();
  }

  Future<List<ColorRequest>> colorRequests() async {
    final items = await _api.colorRequests();
    return items.map(_colorRequestFromJson).toList();
  }

  Future<List<Purchase>> distributorPurchases({String? status, bool? toVerify}) async {
    final items = await _api.distributorPurchases(status: status, toVerify: toVerify);
    return items.map(_purchaseFromJson).toList();
  }

  Future<List<Client>> distributorClients() async {
    final items = await _api.distributorClients();
    return items.map(_clientFromJson).toList();
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

  Future<List<Order>> distributorOrders() async {
    final items = await _api.distributorOrders();
    return items.map(_orderFromJson).toList();
  }

  Future<List<CourierTask>> distributorDeliveryTasks() async {
    final items = await _api.distributorDeliveryTasks();
    return items.map(_courierTaskFromJson).toList();
  }

  Future<void> updateDeliveryStatus(String taskId, {String? status, String? courierId, String? reason}) async {
    await _api.updateDeliveryStatus(taskId, status: status, courierId: courierId, reason: reason);
  }

  Future<List<ProductData>> distributorStock() async {
    final items = await _api.distributorStock();
    // Use compute for large lists to keep UI responsive
    return compute(_parseProductList, items);
  }

  static List<ProductData> _parseProductList(List<dynamic> items) {
    return items.map((i) => _productFromJson(i as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> distributorCouriers() async {
    return _api.distributorCouriers();
  }

  Future<void> distributorStockUpload(List<Map<String, dynamic>> items) async {
    await _api.distributorStockUpload(items);
  }

  Future<void> addProduct(Map<String, dynamic> data) async {
    await _api.addProduct(data);
  }

  Future<List<ColorRequest>> distributorColorRequests({String? status}) async {
    final result = await _api.distributorColorRequests(status: status);
    return _list(result['results']).map((item) => _colorRequestFromJson(item)).toList();
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

  Future<Map<String, dynamic>> adminIntegrationTokens() {
    return _api.adminIntegrationTokens();
  }

  Future<Map<String, dynamic>> adminIntegrationGenerate(String distributorId) {
    return _api.adminIntegrationGenerate(distributorId);
  }

  Future<Map<String, dynamic>> adminIntegrationLogs() {
    return _api.adminIntegrationLogs();
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

  Future<List<CourierTask>> courierTasks() async {
    final items = (ApiClient.role == 'distributor')
        ? await _api.distributorDeliveryTasks()
        : await _api.courierTasks();
    return items.map(_courierTaskFromJson).toList();
  }

  Future<List<CourierTask>> courierMyTasks() async {
    final items = await _api.courierMyTasks();
    return items.map(_courierTaskFromJson).toList();
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

  Future<List<Referral>> referrals() async {
    final items = await _api.referrals();
    return items.map(_referralFromJson).toList();
  }

  Future<List<ExpertTicket>> tickets() async {
    final items = await _api.tickets();
    return items.map(_ticketFromJson).toList();
  }

  Future<List<Notification>> notifications() async {
    final items = await _api.notifications();
    return items.map(_notificationFromJson).toList();
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

  Future<List<Client>> managerClients() async {
    final items = await _api.managerClients();
    return items.map(_clientFromJson).toList();
  }

  Future<Map<String, dynamic>> managerClientUnified(String clientId) {
    return _api.managerClientUnified(clientId);
  }

  Future<List<Client>> managerClientsFiltered({
    String? status,
    String? category,
    String? regionId,
    String? distributorId,
  }) async {
    final items = await _api.managerClientsFiltered(
      status: status,
      category: category,
      regionId: regionId,
      distributorId: distributorId,
    );
    return items.map(_clientFromJson).toList();
  }

  Future<Client> managerCreateClient(Map<String, dynamic> data) async {
    final result = await _api.managerCreateClient(data);
    return _clientFromJson(result['client'] as Map<String, dynamic>);
  }

  Future<void> managerUpdateClientStatus(String clientId, String status) async {
    await _api.managerUpdateClientStatus(clientId, status);
  }

  Future<List<ContactHistoryEntry>> managerClientHistory(String clientId) async {
    final items = await _api.managerClientHistory(clientId);
    return items.map(ContactHistoryEntry.fromJson).toList();
  }

  Future<ContactHistoryEntry> managerAddContactHistory(String clientId, Map<String, dynamic> data) async {
    final result = await _api.managerAddContactHistory(clientId, data);
    return ContactHistoryEntry.fromJson(result['entry'] as Map<String, dynamic>);
  }

  Future<List<ManagerTask>> managerTasks({String? status}) async {
    final items = await _api.managerTasks(status: status);
    return items.map(ManagerTask.fromJson).toList();
  }

  Future<ManagerTask> managerCreateTask(Map<String, dynamic> data) async {
    final result = await _api.managerCreateTask(data);
    return ManagerTask.fromJson(result['task'] as Map<String, dynamic>);
  }

  Future<ManagerTask> managerUpdateTask(String taskId, Map<String, dynamic> data) async {
    final result = await _api.managerUpdateTask(taskId, data);
    return ManagerTask.fromJson(result['task'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> me() {
    return _api.me();
  }

  Future<List<KnowledgeCard>> knowledgeCards() async {
    final items = await _api.knowledgeCards();
    return items.map(_knowledgeCardFromJson).toList();
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

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) {
    return _api.register(data);
  }

  Future<List<Map<String, dynamic>>> getRegions() {
    return _api.getRegions();
  }

  Future<List<Map<String, dynamic>>> getDistributors() {
    return _api.getDistributors();
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

  Future<Map<String, dynamic>> test1CIntegration(List<dynamic> payload) {
    return _api.test1CIntegration(payload);
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
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      volume: _toDouble(json['volume']),
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
    return PurchaseItem(
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
      case 'accepted':
        return OrderStatus.accepted;
      case 'rejected':
        return OrderStatus.rejected;
      case 'fulfilled':
        return OrderStatus.fulfilled;
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
