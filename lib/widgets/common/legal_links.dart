import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

/// Пункты профиля: Условия использования, Политика конфиденциальности и текст
/// Согласия на обработку персональных данных.
///
/// Экранов профиля два — общий и экспертный, поэтому блок общий: у одной из
/// ролей документы иначе потерялись бы. Тексты живут в самом приложении
/// (lib/core/legal_documents.dart), так что пункты не зависят от сайта.
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _tile(
          context,
          Icons.description_outlined,
          'Условия использования',
          AppRoutes.termsOfUse,
        ),
        const Divider(height: 1),
        _tile(
          context,
          Icons.privacy_tip_outlined,
          'Политика конфиденциальности',
          AppRoutes.privacyPolicy,
        ),
        const Divider(height: 1),
        _tile(
          context,
          Icons.fact_check_outlined,
          'Согласие на обработку персональных данных',
          AppRoutes.personalDataConsent,
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: AppShapes.cut(AppShapes.chamferSm),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
      onTap: () => context.push(route),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
