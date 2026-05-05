String formatLocalTime(dynamic raw, {String fallback = '-'}) {
  final parsed = raw == null ? null : DateTime.tryParse(raw.toString());
  if (parsed == null) return fallback;
  final local = parsed.toLocal();
  final now = DateTime.now();
  final date = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final hour = _two(local.hour);
  final minute = _two(local.minute);
  if (date == today) return '今天 $hour:$minute';
  if (date == yesterday) return '昨天 $hour:$minute';
  if (local.year == now.year) {
    return '${_two(local.month)}-${_two(local.day)} $hour:$minute';
  }
  return '${local.year}-${_two(local.month)}-${_two(local.day)} $hour:$minute';
}

String _two(int value) => value.toString().padLeft(2, '0');
