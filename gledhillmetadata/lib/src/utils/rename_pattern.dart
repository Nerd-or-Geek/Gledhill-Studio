String applyRenamePattern({
  required String pattern,
  required DateTime date,
  required int sequence,
  String title = 'untitled',
  Map<String, String> metadata = const {},
  String extension = '',
}) {
  final paddedSequence = RegExp(r'\{sequence:(\d+)}');
  final plainSequence = RegExp(r'\{sequence}');
  final metadataToken = RegExp(r'\{metadata:([^}]+)}', caseSensitive: false);

  var value = pattern
      .replaceAll('{year}', date.year.toString().padLeft(4, '0'))
      .replaceAll('{month}', date.month.toString().padLeft(2, '0'))
      .replaceAll('{hour}', date.hour.toString().padLeft(2, '0'))
      .replaceAll('{minute}', date.minute.toString().padLeft(2, '0'))
      .replaceAll('{second}', date.second.toString().padLeft(2, '0'))
      .replaceAll('{day}', date.day.toString().padLeft(2, '0'))
      .replaceAll('{title}', _sanitize(title));

  value = value.replaceAllMapped(paddedSequence, (match) {
    final width = int.tryParse(match.group(1) ?? '') ?? 3;
    return sequence.toString().padLeft(width, '0');
  });

  value = value.replaceAllMapped(plainSequence, (_) => sequence.toString());

  value = value.replaceAllMapped(metadataToken, (match) {
    final requestedKey = (match.group(1) ?? '').trim().toLowerCase();
    if (requestedKey.isEmpty) {
      return '';
    }

    String? value;
    for (final entry in metadata.entries) {
      final key = entry.key.toLowerCase();
      if (key == requestedKey || key.endsWith(' $requestedKey') || key.contains(requestedKey)) {
        value = entry.value;
        break;
      }
    }

    return _sanitize(value ?? requestedKey);
  });

  final safeExtension = extension.startsWith('.') || extension.isEmpty ? extension : '.$extension';
  return '$value$safeExtension';
}

String _sanitize(String input) {
  return input
      .trim()
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(' ', '_');
}
