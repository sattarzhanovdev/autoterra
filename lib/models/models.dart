enum ClientStatus { newClient, pending, underReview, active, blocked, archived }

enum ManagerTaskStatus { pending, completed }

enum ClientCategory { a, b, c }

enum PurchaseStatus { newPurchase, pending, pendingVerification, underReview, duplicateReview, verified, rejected }

enum OrderStatus {
  newOrder,
  confirmed,
  adjusted,
  accepted, // legacy
  rejected,
  paid,
  shipped,
  fulfilled,
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  /// Значение статуса на бэкенде (Django).
  String get apiValue {
    switch (this) {
      case OrderStatus.newOrder: return 'new';
      case OrderStatus.confirmed: return 'confirmed';
      case OrderStatus.adjusted: return 'adjusted';
      case OrderStatus.accepted: return 'accepted';
      case OrderStatus.rejected: return 'rejected';
      case OrderStatus.paid: return 'paid';
      case OrderStatus.shipped: return 'shipped';
      case OrderStatus.fulfilled: return 'fulfilled';
      case OrderStatus.cancelled: return 'cancelled';
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.newOrder: return 'Ожидает подтверждения';
      case OrderStatus.confirmed: return 'Подтверждён';
      case OrderStatus.adjusted: return 'Скорректирован';
      case OrderStatus.accepted: return 'Принят';
      case OrderStatus.rejected: return 'Отклонён';
      case OrderStatus.paid: return 'Оплачен';
      case OrderStatus.shipped: return 'Отправлен';
      case OrderStatus.fulfilled: return 'Доставлен';
      case OrderStatus.cancelled: return 'Отменён';
    }
  }

  /// Клиент может инициировать оплату.
  bool get isPayable =>
      this == OrderStatus.confirmed || this == OrderStatus.adjusted;
}

enum StockStatus { inStock, low, onOrder, outOfStock }

enum CourierTaskStatus { created, assigned, inProgress, delivered, returned, cancelled }

enum ColorRequestStatus { created, assigned, pickedUp, inProgress, ready, delivered, cancelled }

enum UserRole { client, distributor, manager, admin, courier, aiExpert }

extension UserRoleExtension on UserRole {
  String get label {
    switch (this) {
      case UserRole.client: return 'Автосервис';
      case UserRole.distributor: return 'Дистрибьютор';
      case UserRole.manager: return 'Менеджер';
      case UserRole.admin: return 'Импортер';
      case UserRole.courier: return 'Курьер';
      case UserRole.aiExpert: return 'AI Эксперт';
    }
  }
}

class User {
  final String id;
  final String phone;
  final String email;
  final UserRole role;
  final ClientStatus status;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.phone,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
  });
}

class Store {
  final String id;
  final String name;
  final String address;
  final bool isActive;
  final DateTime createdAt;

  const Store({
    required this.id,
    required this.name,
    required this.address,
    this.isActive = true,
    required this.createdAt,
  });

  factory Store.fromJson(Map<String, dynamic> json) => Store(
        id: json['id'].toString(),
        name: json['name'] as String,
        address: json['address'] as String,
        isActive: (json['isActive'] as bool?) ?? true,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class Client {
  final String id;
  final String? externalId;
  final String inn;
  final String name;
  final ClientCategory category;
  final String region;
  final String city;
  final String contact;
  final String phone;
  final String distributorId;
  final String? managerId;
  final ClientStatus status;
  final String partnerStatus;
  final double totalPurchases;
  final DateTime createdAt;

  final String? distributorName;
  final String? regionId;

  const Client({
    required this.id,
    this.externalId,
    required this.inn,
    required this.name,
    required this.category,
    required this.region,
    required this.city,
    required this.contact,
    required this.phone,
    required this.distributorId,
    this.managerId,
    required this.status,
    this.partnerStatus = 'Silver',
    this.totalPurchases = 0,
    required this.createdAt,
    this.distributorName,
    this.regionId,
  });

  String get categoryLabel {
    switch (category) {
      case ClientCategory.a:
        return 'A';
      case ClientCategory.b:
        return 'B';
      case ClientCategory.c:
        return 'C';
    }
  }

  String get categoryDescription {
    switch (category) {
      case ClientCategory.a:
        return 'Дилерский салон';
      case ClientCategory.b:
        return 'Автосервис с кузовным цехом';
      case ClientCategory.c:
        return 'Гаражный сервис';
    }
  }
}

class Distributor {
  final String id;
  final String? externalId;
  final String name;
  final String inn;
  final List<String> regions;
  final String phone;
  final String email;
  final bool isActive;

  const Distributor({
    required this.id,
    this.externalId,
    required this.name,
    required this.inn,
    required this.regions,
    required this.phone,
    required this.email,
    this.isActive = true,
  });
}

class DistributorDashboardMetrics {
  final int clients;
  final int purchasesToVerify;
  final int ordersToProcess;
  final int deliveriesToAssign;
  final int colorLabPending;

  const DistributorDashboardMetrics({
    required this.clients,
    required this.purchasesToVerify,
    required this.ordersToProcess,
    required this.deliveriesToAssign,
    required this.colorLabPending,
  });
}

class Order {
  final String id;
  final String? externalId;
  final String clientId;
  final String? clientName;
  final String? clientInn;
  final String distributorId;
  final String storeName;
  final String documentNumber;
  final DateTime date;
  final double totalAmount;
  final OrderStatus status;
  final String deliveryMethod;
  final List<PurchaseItem> items;
  final String? comment;
  final String? rejectionReason;
  final String? courierId;
  final String? courierName;
  final DateTime? estimatedDeliveryDate;
  final DateTime createdAt;
  final DateTime? confirmedAt;
  final DateTime? paidAt;
  final DateTime? shippedAt;
  final bool isPayable;
  final List<OrderAdjustment> adjustments;
  /// Ссылка на страницу оплаты YooKassa, если платёж уже создан и ждёт оплаты.
  final String? pendingPaymentUrl;

  const Order({
    required this.id,
    this.externalId,
    required this.clientId,
    this.clientName,
    this.clientInn,
    required this.distributorId,
    required this.storeName,
    required this.documentNumber,
    required this.date,
    required this.totalAmount,
    required this.status,
    this.deliveryMethod = 'courier',
    required this.items,
    this.comment,
    this.rejectionReason,
    this.courierId,
    this.courierName,
    this.estimatedDeliveryDate,
    required this.createdAt,
    this.confirmedAt,
    this.paidAt,
    this.shippedAt,
    this.isPayable = false,
    this.adjustments = const [],
    this.pendingPaymentUrl,
  });
}

/// Позиция, по которой запрошено больше, чем есть на складе.
class OrderShortage {
  final String productId;
  final String name;
  final String sku;
  final int requested;
  final int available;

  const OrderShortage({
    required this.productId,
    required this.name,
    required this.sku,
    required this.requested,
    required this.available,
  });

  /// Достаёт дефициты из тела ответа 409. Возвращает пустой список, если
  /// ошибка не про остатки.
  static List<OrderShortage> parseList(Object? details) {
    if (details is! Map) return const [];
    final raw = details['shortages'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((row) {
      return OrderShortage(
        productId: row['productId']?.toString() ?? '',
        name: row['name']?.toString() ?? '',
        sku: row['sku']?.toString() ?? '',
        requested: int.tryParse('${row['requested']}') ?? 0,
        available: int.tryParse('${row['available']}') ?? 0,
      );
    }).toList();
  }
}

/// Заказ нельзя подтвердить: по части позиций не хватает остатков.
class OrderShortageException implements Exception {
  final String message;
  final List<OrderShortage> shortages;

  const OrderShortageException(this.message, this.shortages);

  @override
  String toString() => message;
}

class OrderAdjustment {
  final String id;
  final List<PurchaseItem> originalItems;
  final List<PurchaseItem> adjustedItems;
  final String? reason;
  final DateTime createdAt;

  const OrderAdjustment({
    required this.id,
    this.originalItems = const [],
    this.adjustedItems = const [],
    this.reason,
    required this.createdAt,
  });
}

class Purchase {
  final String id;
  final String clientId;
  final String? clientName;
  final String? clientInn;
  final String distributorId;
  final String documentNumber;
  final DateTime date;
  final double totalAmount;
  final PurchaseStatus status;
  final String? orderStatus;
  final List<PurchaseItem> items;
  final String? documentUrl;
  final List<AppAttachment> attachments;
  final DateTime createdAt;

  const Purchase({
    required this.id,
    required this.clientId,
    this.clientName,
    this.clientInn,
    required this.distributorId,
    required this.documentNumber,
    required this.date,
    required this.totalAmount,
    required this.status,
    this.orderStatus,
    required this.items,
    this.documentUrl,
    this.attachments = const [],
    required this.createdAt,
  });
}

class AppAttachment {
  final String id;
  final String url;
  final String name;
  final String? fileType;

  const AppAttachment({
    required this.id,
    required this.url,
    required this.name,
    this.fileType,
  });

  factory AppAttachment.fromJson(Map<String, dynamic> json) {
    return AppAttachment(
      id: json['id'].toString(),
      url: json['url'] ?? '',
      name: json['name'] ?? '',
      fileType: json['fileType'],
    );
  }
}

class PurchaseItem {
  /// Идентификатор позиции заказа. Нужен оператору, чтобы отправить
  /// корректировку. У позиций покупки и у снимков в истории его нет.
  final String? id;
  final String? productId;
  final String sku;
  final String name;
  final String category;
  final int quantity;
  final double volume;
  final double price;
  final String brand;

  /// Остаток на складе. `null` — товар под заказ, остаток не ограничивает.
  final int? availableQuantity;

  const PurchaseItem({
    this.id,
    this.productId,
    required this.sku,
    required this.name,
    required this.category,
    required this.quantity,
    required this.volume,
    required this.price,
    required this.brand,
    this.availableQuantity,
  });

  double get total => price * quantity;

  /// Запрошено больше, чем есть на складе.
  bool get isShort =>
      availableQuantity != null && quantity > availableQuantity!;

  PurchaseItem copyWith({int? quantity}) {
    return PurchaseItem(
      id: id,
      productId: productId,
      sku: sku,
      name: name,
      category: category,
      quantity: quantity ?? this.quantity,
      volume: volume,
      price: price,
      brand: brand,
      availableQuantity: availableQuantity,
    );
  }
}

class StockItem {
  final String id;
  final String? externalId;
  final String distributorId;
  final String sku;
  final String name;
  final int quantity;
  final StockStatus status;
  final String category;
  final DateTime updatedAt;

  const StockItem({
    required this.id,
    this.externalId,
    required this.distributorId,
    required this.sku,
    required this.name,
    required this.quantity,
    required this.status,
    required this.category,
    required this.updatedAt,
  });
}

class ColorRequest {
  final String id;
  final String clientId;
  final String? clientName;
  final String carBrand;
  final String carModel;
  final String carYear;
  final String vin;
  final String colorCode;
  final String colorName;
  final bool urgent;
  final ColorRequestStatus status;
  final String transferMethod;
  final String? pickupAddress;
  final DateTime? pickupTime;
  final String? contactPerson;
  final String? contactPhone;
  final DateTime? slaDeadline;
  final bool isOverdue;
  final String? recipe;
  final String? comment;
  final List<CourierTask> courierTasks;
  final DateTime createdAt;

  const ColorRequest({
    required this.id,
    required this.clientId,
    this.clientName,
    required this.carBrand,
    required this.carModel,
    this.carYear = '',
    required this.vin,
    required this.colorCode,
    required this.colorName,
    this.urgent = false,
    required this.status,
    required this.transferMethod,
    this.pickupAddress,
    this.pickupTime,
    this.contactPerson,
    this.contactPhone,
    this.slaDeadline,
    this.isOverdue = false,
    this.recipe,
    this.comment,
    this.courierTasks = const [],
    required this.createdAt,
  });

  factory ColorRequest.fromJson(Map<String, dynamic> json) {
    return ColorRequest(
      id: json['id'].toString(),
      clientId: json['clientId'].toString(),
      clientName: json['clientName'],
      carBrand: json['carBrand'] ?? '',
      carModel: json['carModel'] ?? '',
      carYear: json['carYear']?.toString() ?? '',
      vin: json['vin'] ?? '',
      colorCode: json['colorCode'] ?? '',
      colorName: json['colorName'] ?? '',
      urgent: json['urgent'] ?? false,
      status: _parseStatus(json['status']?.toString()),
      transferMethod: json['transferMethod'] ?? 'courier',
      pickupAddress: json['pickupAddress'],
      pickupTime: json['pickupTime'] != null ? DateTime.parse(json['pickupTime']) : null,
      contactPerson: json['contactPerson'],
      contactPhone: json['contactPhone'],
      slaDeadline: json['slaDeadline'] != null ? DateTime.parse(json['slaDeadline']) : null,
      isOverdue: json['isOverdue'] ?? false,
      recipe: json['recipe'],
      comment: json['comment'],
      courierTasks: json['courierTasks'] != null
          ? (json['courierTasks'] as List)
              .map((item) => CourierTask.fromJson(item as Map<String, dynamic>))
              .toList()
          : const [],
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
    );
  }

  static ColorRequestStatus _parseStatus(String? value) {
    switch (value) {
      case 'created': return ColorRequestStatus.created;
      case 'assigned': return ColorRequestStatus.assigned;
      case 'picked_up': return ColorRequestStatus.pickedUp;
      case 'in_progress': return ColorRequestStatus.inProgress;
      case 'ready': return ColorRequestStatus.ready;
      case 'delivered': return ColorRequestStatus.delivered;
      case 'cancelled': return ColorRequestStatus.cancelled;
      default: return ColorRequestStatus.created;
    }
  }
}

class CourierTask {
  final String id;
  final String clientId;
  final String clientName;
  final String? courierName;
  final String taskType; // 'pickup' | 'delivery' | 'return'
  final String typeDisplay;
  final String address;
  final String? contactName;
  final String? contactPhone;
  final String timeSlot;
  final CourierTaskStatus status;
  final String statusDisplay;
  final String? assignedCourierId;
  final String? photoProof;
  final String? comment;
  final String? courierComment;
  final DateTime createdAt;

  const CourierTask({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.courierName,
    required this.taskType,
    required this.typeDisplay,
    required this.address,
    this.contactName,
    this.contactPhone,
    required this.timeSlot,
    required this.status,
    required this.statusDisplay,
    this.assignedCourierId,
    this.photoProof,
    this.comment,
    this.courierComment,
    required this.createdAt,
  });

  String get type => taskType;

  factory CourierTask.fromJson(Map<String, dynamic> json) {
    return CourierTask(
      id: json['id'].toString(),
      clientId: json['clientId'].toString(),
      clientName: json['clientName'] ?? '',
      courierName: json['courierName'],
      taskType: json['taskType'] ?? 'delivery',
      typeDisplay: json['typeDisplay'] ?? '',
      address: json['address'] ?? '',
      contactName: json['contactName'],
      contactPhone: json['contactPhone'],
      timeSlot: json['timeSlot'] ?? '',
      status: _parseStatus(json['status']),
      statusDisplay: json['statusDisplay'] ?? '',
      assignedCourierId: json['assignedCourierId']?.toString(),
      photoProof: json['photoProof'],
      comment: json['comment'],
      courierComment: json['courierComment'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  static CourierTaskStatus _parseStatus(String? status) {
    switch (status) {
      case 'created':
        return CourierTaskStatus.created;
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
}

class Referral {
  final String id;
  final String inviterId;
  final String inviteeInn;
  final String inviteeName;
  final String region;
  final bool isRegistered;
  final bool hasPurchase;
  final double purchaseAmount;
  final bool conditionMet;
  final String? gift;
  final DateTime createdAt;

  const Referral({
    required this.id,
    required this.inviterId,
    required this.inviteeInn,
    required this.inviteeName,
    required this.region,
    this.isRegistered = false,
    this.hasPurchase = false,
    this.purchaseAmount = 0,
    this.conditionMet = false,
    this.gift,
    required this.createdAt,
  });
}

class ExpertTicket {
  final String id;
  final String clientId;
  final String question;
  final String category;
  final String risk;
  final String? aiAnswer;
  final String? aiDraftAnswer;
  final List<String> similarCases;
  final String? expertAnswer;
  final TicketStatus status;
  final String? photo;
  final String? videoLink;
  final DateTime createdAt;

  const ExpertTicket({
    required this.id,
    required this.clientId,
    required this.question,
    required this.category,
    this.risk = 'low',
    this.aiAnswer,
    this.aiDraftAnswer,
    this.similarCases = const [],
    this.expertAnswer,
    required this.status,
    this.photo,
    this.videoLink,
    required this.createdAt,
  });
}

enum TicketStatus { open, aiAnswered, escalated, expertAnswered, closed }

class Notification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String? relatedLink;
  final bool isRead;
  final DateTime createdAt;

  const Notification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.relatedLink,
    this.isRead = false,
    required this.createdAt,
  });
}

enum NotificationType { order, color, delivery, referral, ai, system }

class KnowledgeCard {
  final String id;
  final String problem;
  final String causes;
  final String solution;
  final List<String> skus;
  final String? restrictions;
  final String approvingExpert;
  final bool isApproved;
  final DateTime createdAt;

  const KnowledgeCard({
    required this.id,
    required this.problem,
    required this.causes,
    required this.solution,
    required this.skus,
    this.restrictions,
    required this.approvingExpert,
    this.isApproved = true,
    required this.createdAt,
  });
}

// ── Manager entities ──────────────────────────────────────────────────────────

class ManagerTask {
  final String id;
  final String clientId;
  final String clientName;
  final String managerId;
  final String managerName;
  final String text;
  final DateTime? deadline;
  final ManagerTaskStatus status;
  final String comment;
  final DateTime createdAt;

  const ManagerTask({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.managerId = '',
    this.managerName = '',
    required this.text,
    this.deadline,
    required this.status,
    this.comment = '',
    required this.createdAt,
  });

  factory ManagerTask.fromJson(Map<String, dynamic> json) {
    ManagerTaskStatus parseStatus(String? s) =>
        s == 'completed' ? ManagerTaskStatus.completed : ManagerTaskStatus.pending;

    return ManagerTask(
      id: json['id'].toString(),
      clientId: json['clientId'].toString(),
      clientName: json['clientName']?.toString() ?? '',
      managerId: json['managerId']?.toString() ?? '',
      managerName: json['managerName']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'].toString())
          : null,
      status: parseStatus(json['status']?.toString()),
      comment: json['comment']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ContactHistoryEntry {
  final String id;
  final String clientId;
  final String type; // 'call' | 'visit' | 'email' | 'other'
  final String typeDisplay;
  final String result;
  final DateTime date;
  final String authorId;
  final String authorName;

  const ContactHistoryEntry({
    required this.id,
    required this.clientId,
    required this.type,
    required this.typeDisplay,
    required this.result,
    required this.date,
    required this.authorId,
    required this.authorName,
  });

  factory ContactHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ContactHistoryEntry(
      id: json['id'].toString(),
      clientId: json['clientId'].toString(),
      type: json['type']?.toString() ?? 'call',
      typeDisplay: json['typeDisplay']?.toString() ?? 'Звонок',
      result: json['result']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName']?.toString() ?? '',
    );
  }

}
