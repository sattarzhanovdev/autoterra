String cleanAiAnswer(String text, {List<dynamic> sources = const []}) {
  text = text
      .split(
        RegExp(
          r'^\s*#{0,6}\s*\*{0,2}(?:Источники|Sources|References)\*{0,2}\s*:?.*$',
          multiLine: true,
          caseSensitive: false,
        ),
      )
      .first;
  text = text.replaceAll(
    RegExp(r'\[\^?\d+(?:\s*[,;–-]\s*\d+)*\]\(https?://[^)]+\)'),
    '',
  );
  text = text.replaceAll(RegExp(r'\[\^?\d+(?:\s*[,;–-]\s*\d+)*\]|【[^】]*】'), '');
  for (final source in sources.whereType<Map>()) {
    if (source['type'] == 'product') continue;
    for (final key in ['url', 'fileUrl', 'downloadUrl', 'filename', 'title']) {
      final value = source[key];
      if (value is String && value.isNotEmpty) {
        if (key.endsWith('Url') || key == 'url') {
          text = text.replaceAll(
            RegExp(r'\[[^]]*\]\(' + RegExp.escape(value) + r'\)'),
            '',
          );
        }
        text = text.replaceAll(value, '');
      }
    }
  }
  return text
      .replaceAllMapped(RegExp(r'[ \t]+([.,;:!?])'), (m) => m[1]!)
      .trim();
}
