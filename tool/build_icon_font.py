#!/usr/bin/env python3
"""Собирает иконочный шрифт из фирменного иконпака.

Иконки живут в assets/icons/*.svg (сняты со стр. 14 гайдбука). Шрифт нужен,
чтобы фирменные иконки подставлялись везде, где Flutter ждёт IconData —
в Icon(), в BottomNavigationBarItem, в прочих виджетах и в наших хелперах,
которые принимают IconData. Иначе пришлось бы менять их сигнатуры на Widget.

Запуск (после замены SVG на файлы из архива бренда):
    python3 tool/build_icon_font.py

Скрипт печатает карту кодпоинтов — её нужно перенести в BrandIcons
(lib/widgets/common/brand_icon.dart), если состав пака изменился.
"""

import pathlib
import re
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.misc.transform import Transform
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.svgLib.path import parse_path

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'assets' / 'icons'
DEST = ROOT / 'assets' / 'fonts' / 'AutoTerraIcons.ttf'

UPM = 1000
VIEWBOX = 24          # все иконки нормализованы в 24×24
ASCENT = 800          # 800 вверх + 200 вниз = ровно кегль, как у Material
DESCENT = -200
FIRST_CODEPOINT = 0xE900
CURVE_ERROR = 1.0     # в единицах em, на 1000 upm незаметно

FAMILY = 'AutoTerraIcons'


def dart_name(stem: str) -> str:
    head, *rest = stem.split('-')
    return head + ''.join(w.capitalize() for w in rest)


def glyph_from_svg(path: pathlib.Path):
    d = re.search(r'\sd="([^"]+)"', path.read_text())
    if not d:
        raise SystemExit(f'{path}: не нашёл атрибут d у <path>')

    scale = UPM / VIEWBOX
    # SVG считает y вниз, шрифт — вверх, поэтому переворачиваем и сажаем
    # верх иконки на ASCENT
    transform = Transform(scale, 0, 0, -scale, 0, ASCENT)

    ttPen = TTGlyphPen(None)
    parse_path(d.group(1), TransformPen(Cu2QuPen(ttPen, CURVE_ERROR), transform))
    return ttPen.glyph()


def main():
    files = sorted(SRC.glob('*.svg'))
    if not files:
        raise SystemExit(f'в {SRC} нет ни одного svg')

    glyphs = {'.notdef': TTGlyphPen(None).glyph()}
    metrics = {'.notdef': (UPM, 0)}
    cmap = {}
    mapping = []

    for i, f in enumerate(files):
        name = dart_name(f.stem)
        code = FIRST_CODEPOINT + i
        glyphs[name] = glyph_from_svg(f)
        metrics[name] = (UPM, 0)
        cmap[code] = name
        mapping.append((name, code))

    fb = FontBuilder(UPM, isTTF=True)
    fb.setupGlyphOrder(list(glyphs))
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASCENT, descent=DESCENT)
    fb.setupNameTable({
        'familyName': FAMILY,
        'styleName': 'Regular',
        'psName': f'{FAMILY}-Regular',
        'version': '1.0',
    })
    fb.setupOS2(sTypoAscender=ASCENT, sTypoDescender=DESCENT,
                usWinAscent=ASCENT, usWinDescent=-DESCENT)
    fb.setupPost()
    DEST.parent.mkdir(parents=True, exist_ok=True)
    fb.save(DEST)

    print(f'{DEST.relative_to(ROOT)} — {len(mapping)} глифов\n')
    for name, code in mapping:
        print(f"  static const {name} = "
              f"IconData(0x{code:x}, fontFamily: _family);")
    return 0


if __name__ == '__main__':
    sys.exit(main())
