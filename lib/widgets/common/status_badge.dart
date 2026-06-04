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
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.10),
        border: Border.all(color: filled ? color : color.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? Colors.white : color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static StatusBadge fromClientStatus(ClientStatus status) {
    switch (status) {
      case ClientStatus.active:
        return const StatusBadge(label: 'Активный', color: AppColors.brandBlack);
      case ClientStatus.pending:
      case ClientStatus.underReview:
        return const StatusBadge(label: 'На проверке', color: AppColors.warning);
      case ClientStatus.newClient:
      case ClientStatus.newStatus:
        return const StatusBadge(label: 'Новый', color: AppColors.brandBlack);
      case ClientStatus.approved:
        return const StatusBadge(label: 'Одобрен', color: AppColors.success);
      case ClientStatus.rejected:
        return const StatusBadge(label: 'Отклонён', color: AppColors.error);
      case ClientStatus.blocked:
        return const StatusBadge(label: 'Заблокирован', color: AppColors.error);
      case ClientStatus.archived:
        return const StatusBadge(label: 'Архивный', color: AppColors.textHint);
    }
  }

  static StatusBadge fromPurchaseStatus(PurchaseStatus status) {
    switch (status) {
      case PurchaseStatus.verified:
        return const StatusBadge(label: 'Подтверждена', color: AppColors.success);
      case PurchaseStatus.pending:
      case PurchaseStatus.pendingVerification:
        return const StatusBadge(label: 'На проверке', color: AppColors.warning);
      case PurchaseStatus.underReview:
        return const StatusBadge(label: 'Ручная проверка', color: AppColors.brandBlack);
      case PurchaseStatus.duplicateReview:
        return const StatusBadge(label: 'Проверка дубля', color: AppColors.brandRed);
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
        return const StatusBadge(label: 'Под заказ', color: AppColors.brandBlack);
      case StockStatus.outOfStock:
        return const StatusBadge(label: 'Нет в наличии', color: AppColors.error);
    }
  }

  static StatusBadge fromColorStatus(ColorRequestStatus status) {
    switch (status) {
      case ColorRequestStatus.created:
        return const StatusBadge(label: 'СОЗДАНА', color: AppColors.brandBlack);
      case ColorRequestStatus.inProgress:
        return const StatusBadge(label: 'В РАБОТЕ', color: AppColors.warning);
      case ColorRequestStatus.ready:
        return const StatusBadge(label: 'ГОТОВО', color: AppColors.success);
      case ColorRequestStatus.delivered:
        return const StatusBadge(label: 'ВЫДАНО', color: AppColors.textSecondary);
    }
  }

  static StatusBadge fromCourierStatus(CourierTaskStatus status) {
    switch (status) {
      case CourierTaskStatus.created:
        return const StatusBadge(label: 'СОЗДАНА', color: AppColors.brandBlack);
      case CourierTaskStatus.assigned:
        return const StatusBadge(label: 'КУРЬЕР НАЗНАЧЕН', color: AppColors.warning);
      case CourierTaskStatus.pickedUp:
        return const StatusBadge(label: 'ЗАБРАНО', color: AppColors.brandBlack);
      case CourierTaskStatus.inProgress:
        return const StatusBadge(label: 'В ПУТИ', color: AppColors.brandRed);
      case CourierTaskStatus.delivered:
        return const StatusBadge(label: 'ДОСТАВЛЕНО', color: AppColors.success, filled: true);
      case CourierTaskStatus.returned:
        return const StatusBadge(label: 'ВОЗВРАЩЕНО', color: AppColors.textSecondary);
      case CourierTaskStatus.cancelled:
        return const StatusBadge(label: 'ОТМЕНЕНО', color: AppColors.error);
    }
  }

  static StatusBadge fromPartnerStatus(String status) {
    Color color;
    switch (status) {
      case 'Gold':
        color = AppColors.brandBlack;
        break;
      case 'Platinum':
        color = const Color(0xFF4A4A4A);
        break;
      case 'Certified Partner':
        color = AppColors.brandBlack;
        break;
      default:
        color = AppColors.textHint;
    }
    return StatusBadge(label: status.toUpperCase(), color: color, filled: true);
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
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.zero,
      ),
      child: Center(
        child: Text(
          category,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
