import 'package:flutter/material.dart';

/// Иконки приложения.
///
/// Раньше здесь был фирменный иконпак из гайдбука (стр. 14): SVG собирались
/// скриптом `tool/build_icon_font.py` в `assets/fonts/AutoTerraIcons.ttf`, а
/// константы указывали на его глифы. Вернули Material — на экранах пак читался
/// хуже, чем стандартный набор.
///
/// Названия и сигнатуры не изменились: везде это по-прежнему [IconData], и
/// 25 экранов, которые их используют, править не потребовалось.
///
/// Чтобы вернуть фирменный пак, замените значения обратно на глифы — сам
/// шрифт и скрипт сборки на месте, в pubspec.yaml он тоже остался
/// зарегистрирован:
///
///     static const _family = 'AutoTerraIcons';
///     static const arrowDown = IconData(0xe900, fontFamily: _family);
///     static const arrowLeft = IconData(0xe901, fontFamily: _family);
///     static const arrowRight = IconData(0xe902, fontFamily: _family);
///     static const arrowUp = IconData(0xe903, fontFamily: _family);
///     static const bolt = IconData(0xe904, fontFamily: _family);
///     static const cart = IconData(0xe905, fontFamily: _family);
///     static const document = IconData(0xe906, fontFamily: _family);
///     static const heart = IconData(0xe907, fontFamily: _family);
///     static const list = IconData(0xe908, fontFamily: _family);
///     static const location = IconData(0xe909, fontFamily: _family);
///     static const person = IconData(0xe90a, fontFamily: _family);
///     static const star = IconData(0xe90b, fontFamily: _family);
///     static const tools = IconData(0xe90c, fontFamily: _family);
abstract final class BrandIcons {
  static const arrowDown = Icons.arrow_downward;
  static const arrowLeft = Icons.arrow_back;
  static const arrowRight = Icons.arrow_forward;
  static const arrowUp = Icons.arrow_upward;
  static const bolt = Icons.bolt;
  static const cart = Icons.shopping_cart_outlined;
  static const document = Icons.description_outlined;
  static const heart = Icons.favorite_border;
  static const list = Icons.list;
  static const location = Icons.location_on_outlined;
  static const person = Icons.person_outline;
  static const star = Icons.star_border;
  static const tools = Icons.build_outlined;
}
