import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'services/api_client.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/purchases/purchases_screen.dart';
import 'screens/purchases/add_purchase_screen.dart';
import 'screens/color/color_center_screen.dart';
import 'screens/ai/ai_assistant_screen.dart';
import 'screens/qa/qa_screen.dart';
import 'screens/referral/referral_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/distributor/distributor_screen.dart';
import 'screens/orders/order_screen.dart';
import 'screens/delivery/delivery_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: ApiClient.isAuthorized ? AppRoutes.home : AppRoutes.login,
  redirect: (context, state) {
    final isAuthRoute =
        state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.register;
    if (!ApiClient.isAuthorized && !isAuthRoute) {
      return AppRoutes.login;
    }
    if (ApiClient.isAuthorized && state.matchedLocation == AppRoutes.login) {
      return AppRoutes.home;
    }
    return null;
  },
  routes: [
    GoRoute(path: AppRoutes.login, builder: (ctx, _) => const LoginScreen()),
    GoRoute(path: AppRoutes.register, builder: (ctx, _) => const RegisterScreen()),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => _MainShell(child: child, location: state.fullPath ?? ''),
      routes: [
        GoRoute(path: AppRoutes.home, builder: (ctx, _) => const HomeScreen()),
        GoRoute(path: AppRoutes.purchases, builder: (ctx, _) => const PurchasesScreen()),
        GoRoute(path: AppRoutes.colorCenter, builder: (ctx, _) => const ColorCenterScreen()),
        GoRoute(path: AppRoutes.aiAssistant, builder: (ctx, _) => const AiAssistantScreen()),
        GoRoute(path: AppRoutes.profile, builder: (ctx, _) => const ProfileScreen()),
      ],
    ),
    GoRoute(path: AppRoutes.addPurchase, builder: (ctx, _) => const AddPurchaseScreen()),
    GoRoute(path: AppRoutes.qa, builder: (ctx, _) => const QaScreen()),
    GoRoute(path: AppRoutes.referral, builder: (ctx, _) => const ReferralScreen()),
    GoRoute(path: AppRoutes.notifications, builder: (ctx, _) => const NotificationsScreen()),
    GoRoute(path: AppRoutes.distributor, builder: (ctx, _) => const DistributorScreen()),
    GoRoute(path: AppRoutes.order, builder: (ctx, _) => const OrderScreen()),
    GoRoute(path: AppRoutes.delivery, builder: (ctx, _) => const DeliveryScreen()),
  ],
);

class AutoterraApp extends StatelessWidget {
  const AutoterraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class _MainShell extends StatelessWidget {
  final Widget child;
  final String location;

  const _MainShell({required this.child, required this.location});

  int get _currentIndex {
    if (location.startsWith(AppRoutes.purchases)) return 1;
    if (location.startsWith(AppRoutes.colorCenter)) return 2;
    if (location.startsWith(AppRoutes.aiAssistant)) return 3;
    if (location.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderDark, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) {
            switch (i) {
              case 0: context.go(AppRoutes.home);
              case 1: context.go(AppRoutes.purchases);
              case 2: context.go(AppRoutes.colorCenter);
              case 3: context.go(AppRoutes.aiAssistant);
              case 4: context.go(AppRoutes.profile);
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Главная'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'Покупки'),
            BottomNavigationBarItem(icon: Icon(Icons.palette_outlined), activeIcon: Icon(Icons.palette), label: 'Цвет'),
            BottomNavigationBarItem(icon: Icon(Icons.smart_toy_outlined), activeIcon: Icon(Icons.smart_toy), label: 'AI'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Профиль'),
          ],
        ),
      ),
    );
  }
}
