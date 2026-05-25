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
        return const StatusBadge(label: 'Активный', color: AppColors.success);
      case ClientStatus.pending:
        return const StatusBadge(label: 'На проверке', color: AppColors.warning);
      case ClientStatus.newClient:
        return const StatusBadge(label: 'Новый', color: AppColors.info);
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
        return const StatusBadge(label: 'На проверке', color: AppColors.warning);
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
        return const StatusBadge(label: 'СОЗДАНА', color: AppColors.info);
      case CourierTaskStatus.assigned:
        return const StatusBadge(label: 'КУРЬЕР НАЗНАЧЕН', color: AppColors.warning);
      case CourierTaskStatus.inProgress:
        return const StatusBadge(label: 'В ПУТИ', color: AppColors.brandRed);
      case CourierTaskStatus.delivered:
        return const StatusBadge(label: 'ДОСТАВЛЕНО', color: AppColors.success, filled: true);
      case CourierTaskStatus.returned:
        return const StatusBadge(label: 'ВОЗВРАЩЕНО', color: AppColors.textSecondary);
    }
  }

  static StatusBadge fromPartnerStatus(String status) {
    Color color;
    switch (status) {
      case 'Gold':
        color = const Color(0xFFD4920A);
        break;
      case 'Platinum':
        color = const Color(0xFF5A5A5A);
        break;
      case 'Certified Partner':
        color = AppColors.brandBlack;
        break;
      default:
        color = const Color(0xFF9A9A9A);
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
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
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
