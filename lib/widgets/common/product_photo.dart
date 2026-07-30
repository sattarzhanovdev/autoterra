import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Фото товара по ссылке из карточки ассортимента.
///
/// Сами файлы нигде не хранятся: в базе лежат только ссылки (до 15 штук на
/// товар, приходят из Excel-шаблона WB), поэтому картинки грузятся напрямую с
/// CDN поставщика. Плейсхолдер и обработка ошибки обязательны — часть ссылок
/// может оказаться битой, и клиент не должен видеть «серый квадрат смерти».
class ProductThumb extends StatelessWidget {
  /// Ссылки на фото товара; показываем первую рабочую.
  final List<String> images;

  /// Сторона квадрата миниатюры.
  final double size;

  /// Нажатие — обычно открывает галерею.
  final VoidCallback? onTap;

  const ProductThumb({
    super.key,
    required this.images,
    this.size = 64,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = images.isEmpty ? null : images.first;

    final content = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: url == null
          ? const _NoPhoto()
          : Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  // Кэш декодированной картинки под реальный размер миниатюры —
                  // иначе каждая карточка держит в памяти полноразмерное фото.
                  cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : const _PhotoPlaceholder(),
                  errorBuilder: (context, error, stack) => const _NoPhoto(),
                ),
                // Счётчик, если фото несколько — подсказка, что есть галерея.
                if (images.length > 1)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      color: AppColors.brandBlack.withValues(alpha: 0.72),
                      child: Text(
                        '${images.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );

    if (onTap == null || url == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.canvas,
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.border),
        ),
      ),
    );
  }
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.canvas,
      child: const Center(
        child: Icon(Icons.photo_outlined, color: AppColors.textHint, size: 20),
      ),
    );
  }
}

/// Полноэкранный просмотр фото товара: свайп между кадрами и зум щипком.
Future<void> showProductGallery(
  BuildContext context, {
  required List<String> images,
  required String title,
  int initialIndex = 0,
}) {
  if (images.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    useSafeArea: false,
    builder: (_) => _ProductGallery(
      images: images,
      title: title,
      initialIndex: initialIndex,
    ),
  );
}

class _ProductGallery extends StatefulWidget {
  final List<String> images;
  final String title;
  final int initialIndex;

  const _ProductGallery({
    required this.images,
    required this.title,
    required this.initialIndex,
  });

  @override
  State<_ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<_ProductGallery> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_index + 1} / ${widget.images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    widget.images[index],
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(color: Colors.white24),
                          ),
                    errorBuilder: (context, error, stack) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined, color: Colors.white38, size: 40),
                          SizedBox(height: 8),
                          Text(
                            'ФОТО НЕДОСТУПНО',
                            style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Лента миниатюр — при 15 фото листать свайпом по одному неудобно.
          if (widget.images.length > 1)
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: widget.images.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = index == _index;
                  return GestureDetector(
                    onTap: () => _controller.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    ),
                    child: Container(
                      width: 56,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected ? AppColors.brandRed : Colors.white24,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: Image.network(
                        widget.images[index],
                        fit: BoxFit.cover,
                        cacheWidth: (56 * MediaQuery.devicePixelRatioOf(context)).round(),
                        errorBuilder: (context, error, stack) => const ColoredBox(
                          color: Colors.white10,
                          child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 18),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
