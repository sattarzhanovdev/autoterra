import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/models.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(
        color: filled ? color : color.withValues(alpha: 0.10),
        shape: BeveledRectangleBorder(
          side: BorderSide(color: filled ? color : color.withValues(alpha: 0.30)),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: filled ? Colors.white : color,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  static StatusBadge fromClientStatus(ClientStatus status) {
    switch (status) {
      case ClientStatus.active:
        return const StatusBadge(label: 'Активный', color: AppColors.success);
      case ClientStatus.pending:
        return const StatusBadge(label: 'На проверке', color: AppColors.warning);
      case ClientStatus.newClient:
        return const StatusBadge(label: 'Новый', color: AppColors.info);
      case ClientStatus.underReview:
        return const StatusBadge(label: 'На проверке', color: AppColors.warning);
      case ClientStatus.blocked:
        return const StatusBadge(label: 'Заблокирован', color: AppColors.error);
      case ClientStatus.archived:
        return const StatusBadge(label: 'Архивный', color: AppColors.textHint);
    }
  }

  static StatusBadge fromPurchaseStatus(PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.newPurchase:
        return const StatusBadge(label: 'Новая', color: AppColors.info);
      case PurchaseStatus.pending:
        return const StatusBadge(label: 'На проверке', color: AppColors.warning);
      case PurchaseStatus.pendingVerification:
        return const StatusBadge(label: 'Ожидает', color: AppColors.warning);
      case PurchaseStatus.underReview:
        return const StatusBadge(label: 'Проверка', color: AppColors.accent);
      case PurchaseStatus.duplicateReview:
        return const StatusBadge(label: 'Дубликат?', color: AppColors.brandRed);
      case PurchaseStatus.verified:
        return const StatusBadge(label: 'Подтверждена', color: AppColors.success);
      case PurchaseStatus.rejected:
        return const StatusBadge(label: 'Отклонена', color: AppColors.error);
    }
  }

  static StatusBadge fromStockStatus(StockStatus status) {
    switch (status) {
      case StockStatus.inStock:
        return const StatusBadge(label: 'В наличии', color: AppColors.success);
      case StockStatus.low:
        return const StatusBadge(label: 'Мало', color: AppColors.warning);
      case StockStatus.onOrder:
        return const StatusBadge(label: 'Под заказ', color: AppColors.info);
      case StockStatus.outOfStock:
        return const StatusBadge(label: 'Нет в наличии', color: AppColors.error);
    }
  }

  static StatusBadge fromColorStatus(ColorRequestStatus status) {
    switch (status) {
      case ColorRequestStatus.created:
        return const StatusBadge(label: 'СОЗДАНА', color: AppColors.info);
      case ColorRequestStatus.assigned:
        return const StatusBadge(label: 'НАЗНАЧЕНА', color: AppColors.brandBlack);
      case ColorRequestStatus.pickedUp:
        return const StatusBadge(label: 'ЗАБРАНО', color: AppColors.info);
      case ColorRequestStatus.inProgress:
        return const StatusBadge(label: 'В РАБОТЕ', color: AppColors.warning);
      case ColorRequestStatus.ready:
        return const StatusBadge(label: 'ГОТОВО', color: AppColors.success);
      case ColorRequestStatus.delivered:
        return const StatusBadge(label: 'ВЫДАНО', color: AppColors.textSecondary);
      case ColorRequestStatus.cancelled:
        return const StatusBadge(label: 'ОТМЕНЕНА', color: AppColors.error);
    }
  }

  static StatusBadge fromCourierStatus(CourierTaskStatus status) {
    switch (status) {
      case CourierTaskStatus.created:
        return const StatusBadge(label: 'СОЗДАНА', color: AppColors.info);
      case CourierTaskStatus.assigned:
        return const StatusBadge(label: 'КУРЬЕР НАЗНАЧЕН', color: AppColors.brandBlack);
      case CourierTaskStatus.inProgress:
        return const StatusBadge(label: 'В ПУТИ', color: AppColors.brandRed);
      case CourierTaskStatus.delivered:
        return const StatusBadge(label: 'ДОСТАВЛЕНО', color: AppColors.brandBlack, filled: true);
      case CourierTaskStatus.returned:
        return const StatusBadge(label: 'ВОЗВРАЩЕНО', color: AppColors.textSecondary);
      case CourierTaskStatus.cancelled:
        return const StatusBadge(label: 'ОТМЕНЕНА', color: AppColors.error);
    }
  }

  static StatusBadge fromTicketStatus(TicketStatus status) {
    switch (status) {
      case TicketStatus.open:
        return const StatusBadge(label: 'ОТКРЫТО', color: AppColors.info);
      case TicketStatus.aiAnswered:
        return const StatusBadge(label: 'ОТВЕТИЛ AI', color: AppColors.accent);
      case TicketStatus.escalated:
        return const StatusBadge(label: 'У ЭКСПЕРТА', color: AppColors.brandRed, filled: true);
      case TicketStatus.expertAnswered:
        return const StatusBadge(label: 'РЕШЕНО', color: AppColors.success, filled: true);
      case TicketStatus.closed:
        return const StatusBadge(label: 'ЗАКРЫТО', color: AppColors.textHint);
    }
  }

  static StatusBadge fromOrderStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.newOrder:
        return const StatusBadge(label: 'НОВЫЙ', color: AppColors.info);
      case OrderStatus.confirmed:
        return const StatusBadge(label: 'ПОДТВЕРЖДЁН', color: AppColors.success);
      case OrderStatus.adjusted:
        return const StatusBadge(label: 'СКОРРЕКТИРОВАН', color: AppColors.warning);
      case OrderStatus.accepted:
        return const StatusBadge(label: 'В РАБОТЕ', color: AppColors.warning);
      case OrderStatus.paid:
        return const StatusBadge(label: 'ОПЛАЧЕН', color: AppColors.info);
      case OrderStatus.shipped:
        return const StatusBadge(label: 'ОТПРАВЛЕН', color: AppColors.info);
      case OrderStatus.rejected:
        return const StatusBadge(label: 'ОТКЛОНЁН', color: AppColors.error);
      case OrderStatus.fulfilled:
        return const StatusBadge(label: 'ВЫПОЛНЕН', color: AppColors.success);
      case OrderStatus.cancelled:
        return const StatusBadge(label: 'ОТМЕНЁН', color: AppColors.error);
    }
  }

  static StatusBadge fromPartnerStatus(String status) {
    Color color;
    switch (status) {
      case 'Gold':
        color = AppColors.brandRed;
        break;
      case 'Platinum':
        color = AppColors.brandBlack;
        break;
      case 'Certified Partner':
        color = AppColors.brandBlack;
        break;
      default:
        color = AppColors.textHint;
    }
    return StatusBadge(label: status, color: color, filled: true);
  }
}

class CategoryBadge extends StatelessWidget {
  final String category;

  const CategoryBadge({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (category) {
      case 'A':
        color = AppColors.categoryA;
        break;
      case 'B':
        color = AppColors.categoryB;
        break;
      default:
        color = AppColors.categoryC;
    }
    return Container(
      width: 24,
      height: 24,
      decoration: ShapeDecoration(
        color: color,
        shape: const BeveledRectangleBorder(),
      ),
      child: Center(
        child: Text(
          category,
          style: const TextStyle(
            color: Colors.white, 
            fontSize: 11, 
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
