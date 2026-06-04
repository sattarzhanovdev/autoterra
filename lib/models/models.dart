enum ClientStatus {
  newClient,
  pending,
  active,
  blocked,
  archived,
  newStatus,
  underReview,
  approved,
  rejected,
}

enum ClientCategory { a, b, c }

enum PurchaseStatus {
  pending,
  pendingVerification,
  underReview,
  duplicateReview,
  verified,
  rejected,
}

enum StockStatus { inStock, low, onOrder, outOfStock }

enum CourierTaskStatus {
  created,
  assigned,
  pickedUp,
  inProgress,
  delivered,
  returned,
  cancelled,
}

enum ColorRequestStatus { created, inProgress, ready, delivered }

class Client {
  final String id;
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

  const Client({
    required this.id,
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
  final String name;
  final String inn;
  final List<String> regions;
  final String phone;
  final String email;
  final bool isActive;

  const Distributor({
    required this.id,
    required this.name,
    required this.inn,
    required this.regions,
    required this.phone,
    required this.email,
    this.isActive = true,
  });
}

class Purchase {
  final String id;
  final String clientId;
  final String distributorId;
  final String documentNumber;
  final DateTime date;
  final double totalAmount;
  final PurchaseStatus status;
  final String? orderStatus;
  final List<PurchaseItem> items;
  final String? documentUrl;
  final List<Attachment> attachments;
  final DateTime createdAt;

  const Purchase({
    required this.id,
    required this.clientId,
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

class Attachment {
  final String id;
  final String url;
  final String name;
  final String fileType;
  final DateTime uploadedAt;
  final String? description;

  const Attachment({
    required this.id,
    required this.url,
    required this.name,
    required this.fileType,
    required this.uploadedAt,
    this.description,
  });
}

class PurchaseItem {
  final String sku;
  final String name;
  final String category;
  final int quantity;
  final double volume;
  final double price;
  final String brand;

  const PurchaseItem({
    required this.sku,
    required this.name,
    required this.category,
    required this.quantity,
    required this.volume,
    required this.price,
    required this.brand,
  });

  double get total => price * quantity;
}

class StockItem {
  final String id;
  final String distributorId;
  final String sku;
  final String name;
  final int quantity;
  final StockStatus status;
  final String category;
  final DateTime updatedAt;

  const StockItem({
    required this.id,
    required this.distributorId,
    required this.sku,
    required this.name,
    required this.quantity,
    required this.status,
    required this.category,
    required this.updatedAt,
  });
}

class RecipeMaterial {
  final String id;
  final String sku;
  final double quantity;
  final String unit;
  final String? comment;
  final int version;

  const RecipeMaterial({
    required this.id,
    required this.sku,
    required this.quantity,
    required this.unit,
    this.comment,
    this.version = 1,
  });
}

class ColorStatusHistory {
  final String status;
  final DateTime at;
  final String? by;
  final String? comment;

  const ColorStatusHistory({
    required this.status,
    required this.at,
    this.by,
    this.comment,
  });
}

class ColorRequest {
  final String id;
  final String clientId;
  final String carBrand;
  final String carModel;
  final String? carYear;
  final String vin;
  final String colorCode;
  final String colorName;
  final bool urgent;
  final String? comment;
  final bool courierPickup;
  final String? pickupAddress;
  final DateTime? pickupDate;
  final String? contactPerson;
  final String? contactPhone;
  final String deliveryMethod;
  final DateTime? slaDeadline;
  final bool isOverdue;
  final String? assignedDistributorId;
  final String? assignedStation;
  final ColorRequestStatus status;
  final List<ColorStatusHistory> statusHistory;
  final String? recipe;
  final List<RecipeMaterial> materials;
  final List<CourierTask> courierTasks;
  final List<Attachment> attachments;
  final DateTime createdAt;

  const ColorRequest({
    required this.id,
    required this.clientId,
    required this.carBrand,
    required this.carModel,
    this.carYear,
    required this.vin,
    required this.colorCode,
    required this.colorName,
    this.urgent = false,
    this.comment,
    this.courierPickup = false,
    this.pickupAddress,
    this.pickupDate,
    this.contactPerson,
    this.contactPhone,
    this.deliveryMethod = 'courier',
    this.slaDeadline,
    this.isOverdue = false,
    this.assignedDistributorId,
    this.assignedStation,
    required this.status,
    this.statusHistory = const [],
    this.recipe,
    this.materials = const [],
    this.courierTasks = const [],
    this.attachments = const [],
    required this.createdAt,
  });
}

class CourierTask {
  final String id;
  final String clientId;
  final String? clientName;
  final String? orderId;
  final String? colorRequestId;
  final String type; // 'pickup' | 'delivery' | 'return'
  final String address;
  final DateTime scheduledTime;
  final String contactName;
  final String contactPhone;
  final String carDescription;
  final CourierTaskStatus status;
  final String? courierId;
  final String? photoProof;
  final String? comment;
  final String? courierComment;
  final List<Map<String, dynamic>> statusHistory;
  final List<Attachment> attachments;
  final DateTime createdAt;

  const CourierTask({
    required this.id,
    required this.clientId,
    this.clientName,
    this.orderId,
    this.colorRequestId,
    this.type = 'pickup',
    required this.address,
    required this.scheduledTime,
    required this.contactName,
    required this.contactPhone,
    required this.carDescription,
    required this.status,
    this.courierId,
    this.photoProof,
    this.comment,
    this.courierComment,
    this.statusHistory = const [],
    this.attachments = const [],
    required this.createdAt,
  });
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

enum TicketStatus { open, aiAnswered, escalated, expertAnswered, closed }

class ExpertTicket {
  final String id;
  final String clientId;
  final String? clientName;
  final String question;
  final String category;
  final String risk;
  final String? aiDraftAnswer;
  final String? aiAnswer;
  final String? expertAnswer;
  final String? linkedKnowledgeCardId;
  final List<String> similarCases;
  final TicketStatus status;
  final List<Attachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExpertTicket({
    required this.id,
    required this.clientId,
    this.clientName,
    required this.question,
    required this.category,
    this.risk = 'low',
    this.aiDraftAnswer,
    this.aiAnswer,
    this.expertAnswer,
    this.linkedKnowledgeCardId,
    this.similarCases = const [],
    required this.status,
    this.attachments = const [],
    required this.createdAt,
    required this.updatedAt,
  });
}

class KnowledgeCard {
  final String id;
  final String title;
  final String category;
  final String problem;
  final String? causes;
  final String solution;
  final List<String> skus;
  final String? restrictions;
  final String status;
  final bool isApproved;
  final String? createdBy;
  final String? approvedBy;
  final List<Map<String, dynamic>> revisionHistory;
  final DateTime createdAt;
  final DateTime updatedAt;

  const KnowledgeCard({
    required this.id,
    required this.title,
    required this.category,
    required this.problem,
    this.causes,
    required this.solution,
    required this.skus,
    this.restrictions,
    this.status = 'draft',
    this.isApproved = false,
    this.createdBy,
    this.approvedBy,
    this.revisionHistory = const [],
    required this.createdAt,
    required this.updatedAt,
  });
}

class Notification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;

  const Notification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });
}

enum NotificationType { order, color, delivery, referral, ai, system }
