enum ClientStatus { newClient, pending, active, blocked, archived }

enum ClientCategory { a, b, c }

enum PurchaseStatus { pending, verified, rejected }

enum StockStatus { inStock, low, onOrder, outOfStock }

enum CourierTaskStatus { created, assigned, inProgress, delivered, returned }

enum ColorRequestStatus { created, inProgress, ready, delivered }

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

enum UserRole { superAdmin, importerManager, distributor, autoservice, courier }

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
    this.recipe,
    required this.createdAt,
  });
}

class CourierTask {
  final String id;
  final String clientId;
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
  final DateTime createdAt;

  const CourierTask({
    required this.id,
    required this.clientId,
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

class ExpertTicket {
  final String id;
  final String clientId;
  final String question;
  final String category;
  final String? aiAnswer;
  final String? expertAnswer;
  final TicketStatus status;
  final DateTime createdAt;

  const ExpertTicket({
    required this.id,
    required this.clientId,
    required this.question,
    required this.category,
    this.aiAnswer,
    this.expertAnswer,
    required this.status,
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
