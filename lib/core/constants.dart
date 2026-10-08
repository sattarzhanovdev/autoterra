class AppConstants {
  // Кириллицей — как в логотипе, AndroidManifest и Info.plist.
  static const appName = 'АвтоТерра';
  static const appTagline = 'B2B платформа ЛКМ';

  /// Совпадает с applicationId в android/app/build.gradle.kts.
  static const androidApplicationId = 'com.autoterra.autoterra';

  /// Адрес опубликованной карточки RuStore задаётся при сборке.
  /// Пока карточки нет, приглашение содержит только ссылку регистрации.
  static const appStoreUrl = String.fromEnvironment('RUSTORE_APP_URL');

  static const regions = [
    'Москва', 'Санкт-Петербург', 'Новосибирск', 'Екатеринбург',
    'Казань', 'Нижний Новгород', 'Челябинск', 'Самара',
    'Омск', 'Ростов-на-Дону', 'Уфа', 'Красноярск',
    'Воронеж', 'Пермь', 'Волгоград', 'Краснодар',
    'Саратов', 'Тюмень', 'Тольятти', 'Иркутск',
  ];

  static const clientCategories = {
    'A': 'Дилерский салон',
    'B': 'Многопрофильный автосервис с кузовным цехом',
    'C': 'Гаражный сервис',
    'S': 'Магазин',
  };

  static const skuCategories = [
    'Грунтовки', 'Шпатлёвки', 'Лаки', 'Краски базовые',
    'Краски 2K', 'Растворители', 'Отвердители', 'Антикоры',
    'Герметики', 'Абразивы', 'Инструменты', 'Расходники',
  ];

  static const partnerStatuses = ['Silver', 'Gold', 'Platinum', 'Certified Partner'];
}

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const profile = '/profile';
  static const purchases = '/purchases';
  static const addPurchase = '/purchases/add';
  static const order = '/order';

  /// Заказ целиком: `/orders/{id}` — клиенту, `/orders/{id}/review` — оператору.
  /// Тот же путь приходит ссылкой в письмах и пушах по заказу.
  static const orders = '/orders';
  static const colorCenter = '/color';
  static const aiAssistant = '/ai';
  static const qa = '/qa';
  static const referral = '/referral';
  static const learning = '/learning';
  static const delivery = '/delivery';
  static const admin = '/admin';
  static const notifications = '/notifications';

  /// Правовые документы: политика конфиденциальности, условия использования и
  /// текст согласия на обработку персональных данных. Открываются и без входа —
  /// на них ведут ссылки с экранов входа и регистрации, поэтому роутер
  /// пропускает весь префикс [legal] мимо проверки токена.
  static const legal = '/legal';
  static const privacyPolicy = '$legal/privacy';
  static const termsOfUse = '$legal/terms';
  static const personalDataConsent = '$legal/consent';
  static const distributor = '/distributor';
  static const distributorClients = '/distributor/clients';
  static const distributorStock = '/distributor/stock';
  static const distributorIntegration = '/distributor/integration';
  static const distributorColorLab = '/distributor/color-lab';
  static const distributorDeliveries = '/distributor/deliveries';
  static const distributorOrders = '/distributor/orders';
  static const distributorPurchasesVerification = '/distributor/purchases-verification';
  static const managerClients = '/manager/clients';
  static const managerTasks = '/manager/tasks';
}
