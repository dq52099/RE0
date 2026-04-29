String utcMidnightLocalResetHint() {
  final nowUtc = DateTime.now().toUtc();
  final nextUtcMidnight = DateTime.utc(
    nowUtc.year,
    nowUtc.month,
    nowUtc.day + 1,
  );
  final local = nextUtcMidnight.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '今日按 UTC 00:00 重置，本地约 $hour:$minute';
}

String timezoneRequestHint() {
  final offset = DateTime.now().timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final absMinutes = offset.inMinutes.abs();
  final hours = (absMinutes ~/ 60).toString().padLeft(2, '0');
  final minutes = (absMinutes % 60).toString().padLeft(2, '0');
  return '已向接口传入本地时区 UTC$sign$hours:$minutes';
}

String resetHintFromResponse(Map<String, dynamic> data) {
  final nextReset = data['next_reset_at']?.toString().trim() ??
      data['next_reset_time']?.toString().trim() ??
      '';
  if (nextReset.isNotEmpty) {
    final parsed = DateTime.tryParse(nextReset);
    if (parsed != null) {
      final local = parsed.toLocal();
      final month = local.month.toString().padLeft(2, '0');
      final day = local.day.toString().padLeft(2, '0');
      final hour = local.hour.toString().padLeft(2, '0');
      final minute = local.minute.toString().padLeft(2, '0');
      return '下次重置：$month-$day $hour:$minute';
    }
    return '下次重置：$nextReset';
  }
  final mode = data['timezone_mode']?.toString().toLowerCase() ?? '';
  if (mode == 'local') {
    return '今日按本地日历日统计，${timezoneRequestHint()}';
  }
  return '${utcMidnightLocalResetHint()}，${timezoneRequestHint()}';
}
