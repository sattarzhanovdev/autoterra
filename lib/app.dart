import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/constants.dart';
import 'core/theme.dart';
import 'models/models.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
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
import 'screens/distributor/distributor_cabinet_screen.dart';
import 'screens/orders/order_screen.dart';
import 'screens/delivery/delivery_screen.dart';
import 'screens/courier/courier_screen.dart';
import 'screens/admin/unified_client_card_screen.dart';
import 'widgets/common/role_switcher_wrapper.dart';
import 'services/push_notification_manager.dart';

import 'widgets/layouts/admin_layout.dart';
import 'widgets/layouts/courier_layout.dart';
import 'widgets/layouts/expert_layout.dart';
import 'widgets/layouts/manager_layout.dart';
import 'screens/expert/expert_knowledge_base_screen.dart';

import 'screens/distributor/distributor_clients_screen.dart';
import 'screens/distributor/distributor_stock_screen.dart';
import 'screens/distributor/distributor_integration_screen.dart';
import 'screens/distributor/distributor_color_lab_screen.dart';
import 'screens/distributor/distributor_deliveries_screen.dart';
import 'screens/distributor/distributor_orders_screen.dart';
import 'screens/distributor/distributor_purchases_screen.dart';
import 'screens/manager/manager_client_detail_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: ApiClient.isAuthorized ? AppRoutes.home : AppRoutes.login,
  refreshListenable: authService,
  redirect: (context, state) {
    final isAuthRoute =
        state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.register;
    if (!ApiClient.isAuthorized && !isAuthRoute) {
      return AppRoutes.login;
    }
    if (ApiClient.isAuthorized && isAuthRoute) {
      return AppRoutes.home;
    }

    final role = authService.currentRole;
    final loc = state.matchedLocation;

    if (loc.startsWith('/distributor/') && role != UserRole.distributor) {
      return AppRoutes.home;
    }
    if (loc.startsWith(AppRoutes.admin) && role != UserRole.admin) {
      return AppRoutes.home;
    }
    if (loc.startsWith('/manager/') && role != UserRole.manager && role != UserRole.admin) {
      return AppRoutes.home;
    }

    return null;
  },
  routes: [
    GoRoute(path: AppRoutes.login, builder: (ctx, _) => const LoginScreen()),
    GoRoute(path: AppRoutes.register, builder: (ctx, _) => const RegisterScreen()),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => _MainShell(
        location: state.fullPath ?? '',
        child: child,
      ),
      routes: [
        GoRoute(path: AppRoutes.home, builder: (ctx, _) => const HomeScreen()),
        GoRoute(path: AppRoutes.purchases, builder: (ctx, _) => const PurchasesScreen()),
        GoRoute(path: AppRoutes.colorCenter, builder: (ctx, _) => const ColorCenterScreen()),
        GoRoute(path: AppRoutes.aiAssistant, builder: (ctx, _) => const AiAssistantScreen()),
        GoRoute(path: AppRoutes.profile, builder: (ctx, _) => const ProfileScreen()),
        GoRoute(path: AppRoutes.distributorClients, builder: (ctx, _) => const DistributorClientsScreen()),
        GoRoute(path: AppRoutes.distributorStock, builder: (ctx, _) => const DistributorStockScreen()),
        GoRoute(path: AppRoutes.distributorIntegration, builder: (ctx, _) => const DistributorIntegrationScreen()),
        GoRoute(path: AppRoutes.distributorColorLab, builder: (ctx, _) => const DistributorColorLabScreen()),
        GoRoute(path: AppRoutes.distributorDeliveries, builder: (ctx, _) => const DistributorDeliveriesScreen()),
        GoRoute(path: AppRoutes.distributorOrders, builder: (ctx, _) => const DistributorOrdersScreen()),
        GoRoute(path: AppRoutes.distributorPurchasesVerification, builder: (ctx, _) => const DistributorPurchasesScreen()),

        GoRoute(path: '/distributor-cabinet', builder: (ctx, _) => const DistributorCabinetScreen()),
        GoRoute(path: '/courier-cabinet', builder: (ctx, _) => const CourierScreen()),
        GoRoute(path: AppRoutes.admin, builder: (ctx, _) => AdminLayout()),
        GoRoute(path: '/unified-client/:id', builder: (ctx, state) => UnifiedClientCardScreen(clientId: state.pathParameters['id']!)),
      ],
    ),
    GoRoute(
      path: '${AppRoutes.managerClients}/:clientId',
      builder: (ctx, state) => ManagerClientDetailScreen(clientId: state.pathParameters['clientId']!),
    ),
    GoRoute(path: AppRoutes.addPurchase, builder: (ctx, _) => const AddPurchaseScreen()),
    GoRoute(path: AppRoutes.qa, builder: (ctx, _) => const QaScreen()),
    GoRoute(path: '/knowledge-base', builder: (ctx, _) => const KnowledgeBaseScreen()),
    GoRoute(path: AppRoutes.referral, builder: (ctx, _) => const ReferralScreen()),
    GoRoute(path: AppRoutes.notifications, builder: (ctx, _) => const NotificationsScreen()),
    GoRoute(path: AppRoutes.distributor, builder: (ctx, _) => const DistributorScreen()),
    GoRoute(path: AppRoutes.order, builder: (ctx, state) => OrderScreen(initialOrder: state.extra as Order?)),
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
      builder: (context, child) => RoleSwitcherWrapper(child: child!),
    );
  }
}

class _MainShell extends StatefulWidget {
  final Widget child;
  final String location;

  const _MainShell({required this.child, required this.location});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  @override
  void initState() {
    super.initState();
    // FCM is mobile-only: FirebaseMessaging.instance crashes on web.
    if (!kIsWeb) {
      PushNotificationManager().init(_router);
    }
  }

  int get _currentIndex {
    final role = authService.currentRole;
    if (role == UserRole.distributor) {
      if (widget.location.startsWith(AppRoutes.distributorOrders)) return 1;
      if (widget.location.startsWith(AppRoutes.distributorDeliveries)) return 2;
      if (widget.location.startsWith(AppRoutes.distributorPurchasesVerification)) return 3;
      if (widget.location.startsWith(AppRoutes.profile)) return 4;
      return 0;
    }
    if (widget.location.startsWith(AppRoutes.purchases)) return 1;
    if (widget.location.startsWith(AppRoutes.colorCenter)) return 2;
    if (widget.location.startsWith(AppRoutes.aiAssistant)) return 3;
    if (widget.location.startsWith(AppRoutes.profile)) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authService,
      builder: (context, _) {
        final role = authService.currentRole;

        if (role == UserRole.courier) {
          return const CourierLayout(child: SizedBox());
        }
        if (role == UserRole.admin) {
          return AdminLayout();
        }
        if (role == UserRole.manager) {
          return const ManagerLayout();
        }
        if (role == UserRole.aiExpert) {
          return const ExpertLayout();
        }

        final isDistributor = role == UserRole.distributor;

        return Scaffold(
          body: widget.child,
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.borderDark, width: 1),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (i) {
                if (isDistributor) {
                  switch (i) {
                    case 0:
                      context.go(AppRoutes.home);
                    case 1:
                      context.go(AppRoutes.distributorOrders);
                    case 2:
                      context.go(AppRoutes.distributorDeliveries);
                    case 3:
                      context.go(AppRoutes.distributorPurchasesVerification);
                    case 4:
                      context.go(AppRoutes.profile);
                  }
                } else {
                  switch (i) {
                    case 0:
                      context.go(AppRoutes.home);
                    case 1:
                      context.go(AppRoutes.purchases);
                    case 2:
                      context.go(AppRoutes.colorCenter);
                    case 3:
                      context.go(AppRoutes.aiAssistant);
                    case 4:
                      context.go(AppRoutes.profile);
                  }
                }
              },
              items: isDistributor
                  ? const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.dashboard_outlined),
                        activeIcon: Icon(Icons.dashboard),
                        label: 'Панель',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.shopping_bag_outlined),
                        activeIcon: Icon(Icons.shopping_bag),
                        label: 'Заказы',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.local_shipping_outlined),
                        activeIcon: Icon(Icons.local_shipping),
                        label: 'Доставки',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.verified_outlined),
                        activeIcon: Icon(Icons.verified),
                        label: 'Проверка',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.person_outline),
                        activeIcon: Icon(Icons.person),
                        label: 'Профиль',
                      ),
                    ]
                  : const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home_outlined),
                        activeIcon: Icon(Icons.home),
                        label: 'Главная',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.receipt_long_outlined),
                        activeIcon: Icon(Icons.receipt_long),
                        label: 'Покупки',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.palette_outlined),
                        activeIcon: Icon(Icons.palette),
                        label: 'Цвет',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.smart_toy_outlined),
                        activeIcon: Icon(Icons.smart_toy),
                        label: 'AI',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.person_outline),
                        activeIcon: Icon(Icons.person),
                        label: 'Профиль',
                      ),
                    ],
            ),
          ),
        );
      },
    );
  }
}
