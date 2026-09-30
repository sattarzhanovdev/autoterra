import 'package:flutter/material.dart';

/// Прямоугольник, из которого «вырастает» системный лист «Поделиться».
///
/// На iPhone лист выезжает снизу и якорь не нужен. На iPad это поповер, и
/// UIKit требует непустой sourceRect — без него share_plus бросает исключение
/// прямо в момент нажатия. Приложение уходит в стор как универсальное
/// (TARGETED_DEVICE_FAMILY = "1,2"), значит ревью Apple открывает его на iPad
/// и упирается в этот краш.
///
/// Возвращает null, если виджет ещё не смонтирован: share_plus сам подставит
/// разумное значение, а падать на пустом RenderBox мы не хотим.
Rect? shareOriginFrom(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
