/// Загрузчик одной страницы — принимает номер страницы (с единицы).
typedef PageFetcher<T> = Future<Paginated<T>> Function(int page);

/// Последовательно вычитывает все страницы в один список.
///
/// Нужно для справочников, которые целиком уходят в выпадающие списки
/// (регионы, дистрибьюторы, курьеры). Для длинных лент используйте
/// постраничную подгрузку, а не эту функцию.
///
/// [maxPages] — предохранитель от бесконечного цикла, если бэкенд вернёт
/// некорректные метаданные.
Future<List<T>> fetchAllPages<T>(
  PageFetcher<T> fetch, {
  int maxPages = 50,
}) async {
  final all = <T>[];
  for (var page = 1; page <= maxPages; page++) {
    final result = await fetch(page);
    all.addAll(result.items);
    if (!result.hasNext || result.items.isEmpty) break;
  }
  return all;
}

/// Метаданные страницы, приходящие с бэкенда в блоке `pagination`.
class PageInfo {
  final int page;
  final int pageSize;
  final int count;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;

  const PageInfo({
    required this.page,
    required this.pageSize,
    required this.count,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  /// Разбирает блок `pagination`. Если бэкенд его не прислал (старый эндпоинт
  /// или неожиданный формат), считаем, что пришёл единственный полный список —
  /// так экран продолжит работать без подгрузки.
  factory PageInfo.fromJson(Map<String, dynamic>? json, {int fallbackCount = 0}) {
    if (json == null) return PageInfo.single(fallbackCount);
    final count = (json['count'] as num?)?.toInt() ?? fallbackCount;
    final pageSize = (json['pageSize'] as num?)?.toInt() ?? (fallbackCount > 0 ? fallbackCount : 1);
    return PageInfo(
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: pageSize,
      count: count,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      hasNext: json['hasNext'] as bool? ?? false,
      hasPrevious: json['hasPrevious'] as bool? ?? false,
    );
  }

  /// Единственная страница, вмещающая весь список.
  factory PageInfo.single(int count) => PageInfo(
        page: 1,
        pageSize: count > 0 ? count : 1,
        count: count,
        totalPages: 1,
        hasNext: false,
        hasPrevious: false,
      );

  static const PageInfo empty = PageInfo(
    page: 1,
    pageSize: 0,
    count: 0,
    totalPages: 1,
    hasNext: false,
    hasPrevious: false,
  );
}

/// Страница списка вместе с метаданными пагинации.
class Paginated<T> {
  final List<T> items;
  final PageInfo pageInfo;

  const Paginated({required this.items, required this.pageInfo});

  const Paginated.empty()
      : items = const [],
        pageInfo = PageInfo.empty;

  int get page => pageInfo.page;
  int get count => pageInfo.count;
  bool get hasNext => pageInfo.hasNext;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// Преобразует элементы страницы, сохраняя метаданные.
  Paginated<R> map<R>(R Function(T item) convert) => Paginated<R>(
        items: items.map(convert).toList(),
        pageInfo: pageInfo,
      );

  /// Собирает страницу из ответа API вида
  /// `{"results": [...], "pagination": {...}}`.
  static Paginated<Map<String, dynamic>> fromResponse(Map<String, dynamic> json) {
    final raw = (json['results'] as List?) ?? const [];
    final items = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    return Paginated<Map<String, dynamic>>(
      items: items,
      pageInfo: PageInfo.fromJson(
        json['pagination'] as Map<String, dynamic>?,
        fallbackCount: items.length,
      ),
    );
  }
}
