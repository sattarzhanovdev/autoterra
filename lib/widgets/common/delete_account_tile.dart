import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';

/// Пункт «Удалить аккаунт» для экранов профиля.
///
/// App Store (Guideline 5.1.1(v)) и Google Play не пропускают приложение с
/// регистрацией, если удалить аккаунт нельзя изнутри. Экранов профиля у нас
/// два — общий и экспертный, поэтому пункт вынесен в общий виджет: разойдись
/// они, у одной из ролей удаление молча пропало бы, а ревью проверяет именно
/// ту роль, которую вы дали демо-аккаунтом.
class DeleteAccountTile extends StatelessWidget {
  const DeleteAccountTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: AppShapes.cut(AppShapes.chamferSm),
        ),
        child: const Icon(Icons.delete_forever_outlined, color: AppColors.error, size: 20),
      ),
      title: const Text(
        'Удалить аккаунт',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.error),
      ),
      onTap: () => _confirmAndDelete(context),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  /// Текст диалога обязан совпадать с тем, что реально делает сервер: профиль
  /// обезличивается, вход отключается навсегда, документы по оплаченным
  /// заказам остаются. Ревью сверяет обещание с поведением.
  Future<void> _confirmAndDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: const BeveledRectangleBorder(
          side: BorderSide(color: AppColors.brandBlack, width: 2),
        ),
        title: const Text(
          'УДАЛИТЬ АККАУНТ?',
          style: TextStyle(
            fontFamily: 'TTOctosquares',
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 0.8,
            color: AppColors.brandBlack,
          ),
        ),
        content: const Text(
          'Аккаунт и личные данные будут удалены безвозвратно. Пропадёт доступ '
          'к истории заказов, бонусам и реферальной программе, войти этим '
          'телефоном больше не получится.\n\n'
          'Документы по уже оплаченным заказам сохранятся в обезличенном виде — '
          'этого требует закон.',
          style: TextStyle(
            fontFamily: 'TTNeoris',
            fontSize: 13,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'ОТМЕНА',
              style: TextStyle(
                fontFamily: 'TTOctosquares',
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'УДАЛИТЬ',
              style: TextStyle(
                fontFamily: 'TTOctosquares',
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ApiClient().deleteAccount();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось удалить аккаунт: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Токен на сервере уже погашен — чистим локальную сессию и уводим на вход.
    await authService.logout();
    if (context.mounted) context.go(AppRoutes.login);
  }
}
