import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme.dart';

/// Фирменный иконпак — гайдбук, стр. 14.
///
/// Иконки построены на толстых линиях с характерными разрезами, поэтому рядом
/// с Material-набором они заметно выбиваются. Там, где нужная иконка есть
/// в паке, берём её; для остального Material остаётся допустимым запасом.
///
/// Исходники — [assets/icons], сняты со стр. 14 гайдбука (там чистый вектор).
/// Когда придёт архив бренда с Яндекс.Диска, файлы нужно заменить
/// на официальные — имена и viewBox 24×24 менять не потребуется.
abstract final class BrandIcons {
  static const person = 'assets/icons/person.svg';
  static const location = 'assets/icons/location.svg';
  static const cart = 'assets/icons/cart.svg';
  static const heart = 'assets/icons/heart.svg';
  static const tools = 'assets/icons/tools.svg';
  static const bolt = 'assets/icons/bolt.svg';
  static const arrowUp = 'assets/icons/arrow-up.svg';
  static const arrowDown = 'assets/icons/arrow-down.svg';
  static const arrowLeft = 'assets/icons/arrow-left.svg';
  static const arrowRight = 'assets/icons/arrow-right.svg';
  static const document = 'assets/icons/document.svg';
  static const list = 'assets/icons/list.svg';
  static const star = 'assets/icons/star.svg';
}

/// Рисует иконку из фирменного пака. По умолчанию наследует цвет и размер
/// от [IconTheme], как это делает обычный [Icon].
class BrandIcon extends StatelessWidget {
  final String asset;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  const BrandIcon(
    this.asset, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolved = color ?? iconTheme.color ?? AppColors.brandBlack;
    final side = size ?? iconTheme.size ?? 24;

    return SvgPicture.asset(
      asset,
      width: side,
      height: side,
      colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
      semanticsLabel: semanticLabel,
    );
  }
}
