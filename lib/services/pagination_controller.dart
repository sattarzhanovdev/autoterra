import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/paginated.dart';
import 'api_client.dart';

/// Состояние постраничного списка: накопленные элементы, флаги загрузки и
/// ошибка последней попытки.
///
/// Контроллер отвечает за три сценария:
/// * [refresh] — первая загрузка и «потянуть вниз»: список заменяется;
/// * [loadMore] — подгрузка следующей страницы в конец списка;
/// * [setFilters] — смена фильтров/поиска: сбрасывает список и грузит заново.
///
/// Гонки исключены: у каждого запроса есть номер поколения, и результат
/// применяется только если поколение всё ещё актуально. Благодаря этому
/// быстрый набор в поиске не «схлопывает» список устаревшим ответом.
class PaginationController<T> extends ChangeNotifier {
  /// Загружает страницу. Номер страницы начинается с единицы.
  final PageFetcher<T> fetchPage;

  final int pageSize;

  /// Задержка перед запросом после изменения строки поиска.
  final Duration searchDebounce;

  PaginationController({
    required this.fetchPage,
    this.pageSize = ApiClient.defaultPageSize,
    this.searchDebounce = const Duration(milliseconds: 350),
  });

  final List<T> _items = [];
  PageInfo _pageInfo = PageInfo.empty;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasLoadedOnce = false;
  Object? _error;

  int _generation = 0;
  Timer? _debounceTimer;
  bool _disposed = false;

  /// Уже загруженные элементы всех подгруженных страниц.
  List<T> get items => List.unmodifiable(_items);

  /// Идёт первая загрузка или перезагрузка списка.
  bool get isLoading => _isLoading;

  /// Идёт подгрузка следующей страницы.
  bool get isLoadingMore => _isLoadingMore;

  /// Есть ли ещё страницы на сервере.
  bool get hasMore => _pageInfo.hasNext;

  /// Общее количество записей на сервере (не только загруженных).
  int get totalCount => _pageInfo.count;

  /// Ошибка последней попытки загрузки, если она была.
  Object? get error => _error;

  /// Список пуст и загрузка уже завершилась — можно показать «ничего нет».
  bool get isEmpty => _hasLoadedOnce && _items.isEmpty && !_isLoading;

  /// Была ли хотя бы одна успешная загрузка.
  bool get hasLoadedOnce => _hasLoadedOnce;

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  /// Первая загрузка. Повторные вызовы игнорируются — удобно дёргать из
  /// `initState` без дополнительных проверок.
  Future<void> loadInitial() {
    if (_hasLoadedOnce || _isLoading) return Future.value();
    return refresh();
  }

  /// Перезагружает список с первой страницы.
  Future<void> refresh() async {
    _debounceTimer?.cancel();
    final generation = ++_generation;

    _isLoading = true;
    _error = null;
    _safeNotify();

    try {
      final result = await fetchPage(1);
      if (_disposed || generation != _generation) return;
      _items
        ..clear()
        ..addAll(result.items);
      _pageInfo = result.pageInfo;
      _hasLoadedOnce = true;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      _error = e;
      _hasLoadedOnce = true;
    } finally {
      if (!_disposed && generation == _generation) {
        _isLoading = false;
        _safeNotify();
      }
    }
  }

  /// Догружает следующую страницу в конец списка.
  ///
  /// Ничего не делает, если страниц больше нет или загрузка уже идёт.
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_pageInfo.hasNext) return;

    final generation = _generation;
    final nextPage = _pageInfo.page + 1;

    _isLoadingMore = true;
    _safeNotify();

    try {
      final result = await fetchPage(nextPage);
      if (_disposed || generation != _generation) return;
      _items.addAll(result.items);
      _pageInfo = result.pageInfo;
      _error = null;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      // Ошибку подгрузки показываем отдельно, уже загруженное не теряем.
      _error = e;
    } finally {
      if (!_disposed && generation == _generation) {
        _isLoadingMore = false;
        _safeNotify();
      }
    }
  }

  /// Применяет новые фильтры: [apply] должен обновить внешнее состояние,
  /// на которое опирается [fetchPage], после чего список грузится заново.
  Future<void> setFilters(VoidCallback apply) {
    apply();
    return refresh();
  }

  /// Перезагрузка с задержкой — для поля поиска, чтобы не слать запрос
  /// на каждое нажатие клавиши.
  void refreshDebounced() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(searchDebounce, refresh);
  }

  /// Убирает элемент из списка без перезапроса — например после удаления.
  void removeWhere(bool Function(T item) test) {
    final before = _items.length;
    _items.removeWhere(test);
    if (_items.length != before) {
      final removed = before - _items.length;
      _pageInfo = PageInfo(
        page: _pageInfo.page,
        pageSize: _pageInfo.pageSize,
        count: (_pageInfo.count - removed).clamp(0, 1 << 31),
        totalPages: _pageInfo.totalPages,
        hasNext: _pageInfo.hasNext,
        hasPrevious: _pageInfo.hasPrevious,
      );
      _safeNotify();
    }
  }

  /// Заменяет элемент на месте — например после смены статуса,
  /// чтобы не перезагружать всю ленту.
  void replaceWhere(bool Function(T item) test, T replacement) {
    final index = _items.indexWhere(test);
    if (index == -1) return;
    _items[index] = replacement;
    _safeNotify();
  }
}
