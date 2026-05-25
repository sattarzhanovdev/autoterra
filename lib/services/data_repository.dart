import '../models/models.dart';
import 'api_client.dart';

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

class DataRepository {
  final ApiClient _api;

  const DataRepository({ApiClient api = const ApiClient()}) : _api = api;

  Future<DashboardData> dashboard() async {
    final data = await _api.dashboard();
    return DashboardData(
      client: _clientFromJson(data['client'] as Map<String, dynamic>),
      distributor: _distributorFromJson(
        data['distributor'] as Map<String, dynamic>,
      ),
      unreadCount: (data['unreadCount'] as num).toInt(),
      recentPurchases: _list(
        data['recentPurchases'],
      ).map((item) => _purchaseFromJson(item)).toList(),
      activeColorRequests: _list(
        data['activeColorRequests'],
      ).map((item) => _colorRequestFromJson(item)).toList(),
      fromBackend: true,
    );
  }

  Future<OrderConfigData> orderConfig() async {
    final data = await _api.orderConfig();
    return OrderConfigData(
      client: _clientFromJson(data['client'] as Map<String, dynamic>),
      distributor: _distributorFromJson(
        data['distributor'] as Map<String, dynamic>,
      ),
      stores: _list(data['stores']).map(_storeFromJson).toList(),
      products: _list(data['products']).map(_productFromJson).toList(),
    );
  }

  Future<List<Purchase>> purchases() async {
    final items = await _api.purchases();
    return items.map(_purchaseFromJson).toList();
  }

  Future<List<Purchase>> orders() async {
    final items = await _api.orders();
    return items.map(_purchaseFromJson).toList();
  }

  Future<List<ColorRequest>> colorRequests() async {
    final items = await _api.colorRequests();
    return items.map(_colorRequestFromJson).toList();
  }

  Future<List<CourierTask>> courierTasks() async {
    final items = await _api.courierTasks();
    return items.map(_courierTaskFromJson).toList();
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

  Future<List<KnowledgeCard>> knowledgeCards() async {
    final items = await _api.knowledgeCards();
    return items.map(_knowledgeCardFromJson).toList();
  }

  Future<void> createOrder({
    required String storeId,
    required List<Map<String, dynamic>> items,
    required String comment,
  }) async {
    await _api.createOrder(storeId: storeId, items: items, comment: comment);
  }

  static List<Map<String, dynamic>> _list(Object? value) {
    return (value as List<dynamic>).cast<Map<String, dynamic>>();
  }

  static Client _clientFromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as String,
      inn: json['inn'] as String,
      name: json['name'] as String,
      category: _clientCategory(json['category'] as String),
      region: json['region'] as String,
      city: json['city'] as String,
      contact: json['contact'] as String,
      phone: json['phone'] as String,
      distributorId: json['distributorId'] as String,
      managerId: json['managerId'] as String?,
      status: _clientStatus(json['status'] as String),
      partnerStatus: json['partnerStatus'] as String? ?? 'Silver',
      totalPurchases: (json['totalPurchases'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static Distributor _distributorFromJson(Map<String, dynamic> json) {
    return Distributor(
      id: json['id'] as String,
      name: json['name'] as String,
      inn: json['inn'] as String,
      regions: (json['regions'] as List<dynamic>).cast<String>(),
      phone: json['phone'] as String,
      email: json['email'] as String,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  static StoreData _storeFromJson(Map<String, dynamic> json) {
    return StoreData(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static ProductData _productFromJson(Map<String, dynamic> json) {
    return ProductData(
      id: json['id'] as String,
      distributorId: json['distributorId'] as String,
      sku: json['sku'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      brand: json['brand'] as String,
      volume: (json['volume'] as num).toDouble(),
      price: (json['price'] as num).toDouble(),
      quantity: (json['quantity'] as num).toInt(),
      status: _stockStatus(json['status'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  static Purchase _purchaseFromJson(Map<String, dynamic> json) {
    return Purchase(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      distributorId: json['distributorId'] as String,
      documentNumber: json['documentNumber'] as String,
      date: DateTime.parse(json['date'] as String),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      status: _purchaseStatus(json['status'] as String),
      orderStatus: json['orderStatus'] as String?,
      items: _list(
        json['items'],
      ).map((item) => _purchaseItemFromJson(item)).toList(),
      documentUrl: json['documentUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static PurchaseItem _purchaseItemFromJson(Map<String, dynamic> json) {
    return PurchaseItem(
      sku: json['sku'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      quantity: (json['quantity'] as num).toInt(),
      volume: (json['volume'] as num).toDouble(),
      price: (json['price'] as num).toDouble(),
      brand: json['brand'] as String,
    );
  }

  static ColorRequest _colorRequestFromJson(Map<String, dynamic> json) {
    return ColorRequest(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      carBrand: json['carBrand'] as String,
      carModel: json['carModel'] as String,
      vin: json['vin'] as String,
      colorCode: json['colorCode'] as String,
      colorName: json['colorName'] as String,
      urgent: json['urgent'] as bool? ?? false,
      status: _colorRequestStatus(json['status'] as String),
      recipe: json['recipe'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static CourierTask _courierTaskFromJson(Map<String, dynamic> json) {
    return CourierTask(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      type: json['type'] as String,
      address: json['address'] as String,
      scheduledTime: DateTime.parse(json['scheduledTime'] as String),
      contactName: json['contactName'] as String,
      contactPhone: json['contactPhone'] as String,
      carDescription: json['carDescription'] as String,
      status: _courierTaskStatus(json['status'] as String),
      courierId: json['courierId'] as String?,
      photoProof: json['photoProof'] as String?,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
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
      aiAnswer: json['aiAnswer'] as String?,
      expertAnswer: json['expertAnswer'] as String?,
      status: _ticketStatus(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static Notification _notificationFromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: _notificationType(json['type'] as String),
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
    return PurchaseStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => PurchaseStatus.pending,
    );
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
    return CourierTaskStatus.values.firstWhere(
      (item) => item.name == value,
      orElse: () => CourierTaskStatus.created,
    );
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
