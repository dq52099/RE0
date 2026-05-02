import 'dart:convert';

List<String> parsePromptCandidates(dynamic data, {int limit = 3}) {
  final values = <String>[];

  void collect(dynamic value) {
    if (value == null || values.length >= limit) return;
    if (value is String) {
      values.addAll(_splitCandidateText(value, limit: limit - values.length));
      return;
    }
    if (value is List) {
      for (final item in value) {
        collect(item);
        if (values.length >= limit) return;
      }
      return;
    }
    if (value is Map) {
      for (final key in [
        'prompt',
        'text',
        'content',
        'message',
        'candidates',
        'prompts',
        'data',
        'items',
        'results',
        'choices',
        'output',
      ]) {
        final raw = value[key];
        if (raw == null) continue;
        if (key == 'message' && raw is Map) {
          collect(raw['content']);
        } else {
          collect(raw);
        }
        if (values.length >= limit) return;
      }
    }
  }

  collect(data);
  final seen = <String>{};
  return values
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .where((item) => seen.add(item))
      .take(limit)
      .toList();
}

List<String> _splitCandidateText(String text, {required int limit}) {
  final normalized = text.trim();
  if (normalized.isEmpty || limit <= 0) return const [];
  final decoded = _tryDecodeCandidateJson(normalized);
  if (decoded != null) {
    final values = parsePromptCandidates(decoded, limit: limit);
    if (values.isNotEmpty) return values;
  }
  if (_looksLikeCandidateJson(normalized)) {
    return const [];
  }
  final lines = normalized
      .split(RegExp(r'\n+'))
      .map((line) =>
          line.replaceFirst(RegExp(r'^\s*(?:[-*]|\d+[.)、])\s*'), '').trim())
      .where((line) => line.isNotEmpty)
      .toList();
  if (lines.length >= limit) {
    return lines.take(limit).toList();
  }
  return [normalized];
}

dynamic _tryDecodeCandidateJson(String text) {
  var raw = text.trim();
  if (raw.startsWith('```')) {
    raw = raw.replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
    raw = raw.replaceAll(RegExp(r'\s*```$'), '').trim();
  }
  raw = raw.replaceFirst(RegExp(r'^json\s*', caseSensitive: false), '').trim();
  for (final candidate in [
    raw,
    _substringBetween(raw, '{', '}'),
    _substringBetween(raw, '[', ']'),
  ]) {
    if (candidate == null || candidate.trim().isEmpty) continue;
    try {
      return jsonDecode(candidate);
    } catch (_) {
      continue;
    }
  }
  return null;
}

String? _substringBetween(String text, String startToken, String endToken) {
  final start = text.indexOf(startToken);
  final end = text.lastIndexOf(endToken);
  if (start < 0 || end <= start) return null;
  return text.substring(start, end + 1);
}

bool _looksLikeCandidateJson(String text) {
  final normalized = text.trimLeft();
  if (!normalized.startsWith('{') && !normalized.startsWith('[')) return false;
  return normalized.contains('"candidates"') ||
      normalized.contains('"prompts"') ||
      normalized.contains('"choices"');
}
