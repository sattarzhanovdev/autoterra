class AppConstants {
  static const appName = 'AutoTerra';
  static const appTagline = 'B2B платформа ЛКМ';

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
  static const colorCenter = '/color';
  static const aiAssistant = '/ai';
  static const qa = '/qa';
  static const referral = '/referral';
  static const delivery = '/delivery';
  static const admin = '/admin';
  static const notifications = '/notifications';
  static const distributor = '/distributor';
}
