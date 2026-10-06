import 'api_error.dart';

Map<String, dynamic> normalizeAdminSettingsValues(Map<String, dynamic> values) {
  return values.map((key, value) {
    if (value is! String) return MapEntry(key, value);
    var text = value.trim();
    if (key.endsWith('_base_url') ||
        key.endsWith('_webdav_url') ||
        key.endsWith('_public_url')) {
      text = text.replaceFirst(RegExp(r'/+$'), '');
    }
    if (key.startsWith('openlist_backup_') && key.endsWith('_path')) {
      text = text.isEmpty
          ? '/'
          : text.startsWith('/')
              ? text
              : '/$text';
    }
    return MapEntry(key, text);
  });
}

bool _sameSettingValue(dynamic actual, dynamic expected) {
  if (expected is bool) {
    final normalized = actual.toString().trim().toLowerCase();
    return expected
        ? const {'true', '1', 'yes', 'on'}.contains(normalized)
        : const {'false', '0', 'no', 'off'}.contains(normalized);
  }
  if (expected is num) {
    return num.tryParse(actual.toString()) == expected;
  }
  return actual?.toString().trim() == expected?.toString().trim();
}

/// Send only edits made in this dialog, preserving changes from other clients.
Map<String, dynamic> buildAdminSettingsPatch({
  required Map<String, dynamic> initialValues,
  required Map<String, dynamic> values,
}) {
  final initial = normalizeAdminSettingsValues(initialValues);
  final normalized = normalizeAdminSettingsValues(values);
  return {
    for (final entry in normalized.entries)
      if (entry.value != null &&
          (!initial.containsKey(entry.key) ||
              !_sameSettingValue(initial[entry.key], entry.value)))
        entry.key: entry.value,
  };
}

/// A successful HTTP response must also confirm the persisted settings.
void verifyAdminSettingsSaved(
  Map<String, dynamic> changes,
  Map<String, dynamic> response,
) {
  final saved = {
    for (final item in (response['settings'] as List? ?? const []))
      if (item is Map) item['key'].toString(): item,
  };
  final unconfirmed = <String>[];
  for (final entry in normalizeAdminSettingsValues(changes).entries) {
    final item = saved[entry.key];
    if (item == null ||
        (item['is_sensitive'] != true &&
            !_sameSettingValue(item['value'], entry.value))) {
      unconfirmed.add(entry.key);
    }
  }
  if (unconfirmed.isNotEmpty) {
    throw GatewayException('服务器未确认保存部分设置，请刷新后核对：${unconfirmed.join('、')}');
  }
}
