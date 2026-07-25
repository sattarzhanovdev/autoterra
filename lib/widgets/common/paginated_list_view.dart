import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../services/pagination_controller.dart';
import 'section_header.dart';

/// Список с бесконечной подгрузкой поверх [PaginationController].
///
/// Сам обрабатывает все состояния ленты: первую загрузку, пустой результат,
/// ошибку, подгрузку следующей страницы и «потянуть, чтобы обновить».
/// Экрану остаётся только описать, как рисуется одна карточка.
///
/// Следующая страница запрашивается заранее — когда до конца списка остаётся
/// [loadMoreThreshold] элементов, чтобы прокрутка не упиралась в спиннер.
class PaginatedListView<T> extends StatefulWidget {
  final PaginationController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Отступы вокруг списка.
  final EdgeInsetsGeometry padding;

  /// Текст, когда список пуст.
  final String emptyMessage;

  /// Своё оформление пустого состояния вместо [emptyMessage].
  final Widget? emptyBuilder;

  /// Шапка, прокручивающаяся вместе со списком (фильтры, сводка и т.п.).
  final Widget? header;

  /// Разделитель между карточками.
  final Widget? separator;

  /// За сколько элементов до конца начинать подгрузку.
  final int loadMoreThreshold;

  /// Показывать ли «Показано N из M» под последним элементом.
  final bool showCounter;

  final ScrollController? scrollController;

  const PaginatedListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.padding = const EdgeInsets.all(16),
    this.emptyMessage = 'НИЧЕГО НЕ НАЙДЕНО',
    this.emptyBuilder,
    this.header,
    this.separator,
    this.loadMoreThreshold = 5,
    this.showCounter = true,
    this.scrollController,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  late final ScrollController _scrollController;
  bool _ownsScrollController = false;

  @override
  void initState() {
    super.initState();
    _ownsScrollController = widget.scrollController == null;
    _scrollController = widget.scrollController ?? ScrollController();
    widget.controller.loadInitial();
  }

  @override
  void dispose() {
    if (_ownsScrollController) _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore(int visibleIndex) {
    final controller = widget.controller;
    if (!controller.hasMore || controller.isLoadingMore || controller.isLoading) {
      return;
    }
    if (visibleIndex >= controller.items.length - widget.loadMoreThreshold) {
      // Отложенный вызов: нельзя менять состояние прямо во время построения.
      WidgetsBinding.instance.addPostFrameCallback((_) => controller.loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;

        // Первая загрузка — показываем спиннер на весь экран.
        if (controller.isLoading && controller.items.isEmpty) {
          return _wrapWithHeader(
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.brandRed),
              ),
            ),
          );
        }

        // Ошибка и показывать пока нечего — предлагаем повторить.
        if (controller.error != null && controller.items.isEmpty) {
          return _wrapWithHeader(
            _ErrorState(
              error: controller.error!,
              onRetry: controller.refresh,
            ),
          );
        }

        if (controller.isEmpty) {
          return RefreshIndicator(
            color: AppColors.brandRed,
            onRefresh: controller.refresh,
            child: ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: widget.padding,
              children: [
                if (widget.header != null) widget.header!,
                const SizedBox(height: 48),
                widget.emptyBuilder ??
                    Center(
                      child: Text(
                        widget.emptyMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
              ],
            ),
          );
        }

        final items = controller.items;
        final hasHeader = widget.header != null;
        final headerCount = hasHeader ? 1 : 0;
        // Хвост: индикатор подгрузки, кнопка повтора или счётчик.
        final hasFooter = controller.isLoadingMore ||
            controller.error != null ||
            (widget.showCounter && controller.totalCount > 0);
        final footerCount = hasFooter ? 1 : 0;

        return RefreshIndicator(
          color: AppColors.brandRed,
          onRefresh: controller.refresh,
          child: ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: widget.padding,
            itemCount: headerCount + items.length + footerCount,
            separatorBuilder: (context, index) {
              if (widget.separator == null) return const SizedBox.shrink();
              // Между шапкой/подвалом и карточками разделитель не нужен.
              final isAroundHeader = hasHeader && index == 0;
              final isBeforeFooter = index == headerCount + items.length - 1;
              if (isAroundHeader || isBeforeFooter) return const SizedBox.shrink();
              return widget.separator!;
            },
            itemBuilder: (context, index) {
              if (hasHeader && index == 0) return widget.header!;

              final itemIndex = index - headerCount;
              if (itemIndex < items.length) {
                _maybeLoadMore(itemIndex);
                return widget.itemBuilder(context, items[itemIndex], itemIndex);
              }

              return _ListFooter(
                isLoadingMore: controller.isLoadingMore,
                error: controller.error,
                onRetry: controller.loadMore,
                loadedCount: items.length,
                totalCount: controller.totalCount,
                showCounter: widget.showCounter,
              );
            },
          ),
        );
      },
    );
  }

  Widget _wrapWithHeader(Widget child) {
    if (widget.header == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: widget.padding, child: widget.header!),
        Expanded(child: child),
      ],
    );
  }
}

/// Секция постраничного списка внутри общего скролла с другими секциями.
///
/// Нужна там, где на одном экране несколько независимых лент (заказы,
/// доставки, покупки). Бесконечная прокрутка тут не подходит — непонятно,
/// какую из секций продолжать, — поэтому подгрузка идёт по кнопке
/// «показать ещё» под каждой секцией.
///
/// [build] возвращает список слайверов для вставки в `CustomScrollView`.
class PaginatedSliverSection<T> {
  final PaginationController<T> controller;
  final String title;
  final String emptyMessage;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final EdgeInsets padding;

  const PaginatedSliverSection({
    required this.controller,
    required this.title,
    required this.emptyMessage,
    required this.itemBuilder,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  List<Widget> build() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: padding.copyWith(top: 16, bottom: 8),
          child: SectionHeader(title: title),
        ),
      ),
      SliverToBoxAdapter(
        child: _SectionBody<T>(
          controller: controller,
          emptyMessage: emptyMessage,
          itemBuilder: itemBuilder,
          padding: padding,
        ),
      ),
    ];
  }
}

/// Тело секции. Отдельный StatefulWidget нужен, чтобы первая загрузка
/// запускалась из initState: вызов из builder уведомлял бы слушателей прямо
/// во время build и падал бы с «setState called during build».
class _SectionBody<T> extends StatefulWidget {
  final PaginationController<T> controller;
  final String emptyMessage;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final EdgeInsets padding;

  const _SectionBody({
    required this.controller,
    required this.emptyMessage,
    required this.itemBuilder,
    required this.padding,
  });

  @override
  State<_SectionBody<T>> createState() => _SectionBodyState<T>();
}

class _SectionBodyState<T> extends State<_SectionBody<T>> {
  @override
  void initState() {
    super.initState();
    widget.controller.loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final padding = widget.padding;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
            if (controller.isLoading && controller.items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: AppColors.brandRed,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              );
            }

            if (controller.isEmpty) {
              return Padding(
                padding: padding.copyWith(top: 8, bottom: 16),
                child: Text(
                  widget.emptyMessage,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            return Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final item in controller.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: widget.itemBuilder(context, item),
                    ),
                  if (controller.hasMore)
                    Center(
                      child: controller.isLoadingMore
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: AppColors.brandRed,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : TextButton(
                              onPressed: controller.loadMore,
                              child: Text(
                                'ПОКАЗАТЬ ЕЩЁ (${controller.items.length} ИЗ ${controller.totalCount})',
                                style: const TextStyle(
                                  color: AppColors.brandRed,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            );
      },
    );
  }
}

/// Хвост списка: спиннер подгрузки, ошибка догрузки или счётчик записей.
class _ListFooter extends StatelessWidget {
  final bool isLoadingMore;
  final Object? error;
  final VoidCallback onRetry;
  final int loadedCount;
  final int totalCount;
  final bool showCounter;

  const _ListFooter({
    required this.isLoadingMore,
    required this.error,
    required this.onRetry,
    required this.loadedCount,
    required this.totalCount,
    required this.showCounter,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: AppColors.brandRed,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, color: AppColors.brandRed, size: 18),
            label: const Text(
              'НЕ УДАЛОСЬ ЗАГРУЗИТЬ. ПОВТОРИТЬ',
              style: TextStyle(
                color: AppColors.brandRed,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      );
    }

    if (!showCounter || totalCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          'ПОКАЗАНО $loadedCount ИЗ $totalCount',
          style: const TextStyle(
            color: AppColors.textHint,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object error;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.brandRed, size: 40),
            const SizedBox(height: 16),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandBlack,
              ),
              child: const Text(
                'ПОВТОРИТЬ',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
