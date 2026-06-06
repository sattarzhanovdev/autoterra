enum ClientStatus { newClient, pending, active, blocked, archived }

enum ClientCategory { a, b, c }

enum PurchaseStatus { newPurchase, pending, pendingVerification, underReview, duplicateReview, verified, rejected }

enum OrderStatus { newOrder, accepted, rejected, fulfilled }

enum StockStatus { inStock, low, onOrder, outOfStock }

enum CourierTaskStatus { created, assigned, inProgress, delivered, returned, cancelled }

enum ColorRequestStatus { created, inProgress, ready, delivered }

enum UserRole { client, distributor, manager, admin, courier, aiExpert }

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

class Order {
  final String id;
  final String clientId;
  final String clientName;
  final String distributorId;
  final String storeName;
  final String documentNumber;
  final DateTime date;
  final double totalAmount;
  final OrderStatus status;
  final List<PurchaseItem> items;
  final String? comment;
  final String? rejectionReason;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.distributorId,
    required this.storeName,
    required this.documentNumber,
    required this.date,
    required this.totalAmount,
    required this.status,
    required this.items,
    this.comment,
    this.rejectionReason,
    required this.createdAt,
  });
}

class Purchase {
  final String id;
  final String clientId;
  final String clientName;
  final String distributorId;
  final String documentNumber;
  final DateTime date;
  final double totalAmount;
  final PurchaseStatus status;
  final String? orderStatus;
  final List<PurchaseItem> items;
  final String? documentUrl;
  final DateTime createdAt;

  const Purchase({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.distributorId,
    required this.documentNumber,
    required this.date,
    required this.totalAmount,
    required this.status,
    this.orderStatus,
    required this.items,
    this.documentUrl,
    required this.createdAt,
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

class ColorRequest {
  final String id;
  final String clientId;
  final String carBrand;
  final String carModel;
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
  final DateTime createdAt;

  const ColorRequest({
    required this.id,
    required this.clientId,
    required this.carBrand,
    required this.carModel,
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
    required this.createdAt,
  });
}

class CourierTask {
  final String id;
  final String clientId;
  final String clientName;
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
  final String? aiAnswer;
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
    this.aiAnswer,
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
