String cleanAiAnswer(String text) {
  text = text
      .split(
        RegExp(
          r'^\s*#{0,6}\s*\*{0,2}(?:Источники|Sources|References)\*{0,2}\s*:?.*$',
          multiLine: true,
          caseSensitive: false,
        ),
      )
      .first;
  text = text.replaceAll(RegExp(r'\[\^?\d+(?:\s*[,;–-]\s*\d+)*\]|【[^】]*】'), '');
  text = text.replaceAllMapped(
    RegExp(r'\[([^]]+)\]\(https?://[^)]+\)'),
    (m) => m[1]!,
  );
  return text
      .replaceAll(RegExp(r'https?://\S+'), '')
      .replaceAllMapped(RegExp(r'[ \t]+([.,;:!?])'), (m) => m[1]!)
      .trim();
}
