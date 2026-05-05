import 'package:flutter/material.dart';

import '../../core/local_time_format.dart';

const feedbackStatuses = [
  'collected',
  'accepted',
  'rejected',
  'resolved',
  'closed',
];

const feedbackTypes = ['feedback', 'wish'];

const feedbackCategories = [
  'gallery',
  'generate',
  'edit',
  'system',
  'feature',
  'account',
  'other',
];

String feedbackTypeLabel(String? type) {
  switch (type) {
    case 'wish':
      return '许愿';
    case 'feedback':
      return '反馈';
    default:
      return '全部类型';
  }
}

String feedbackCategoryLabel(String? category) {
  switch (category) {
    case 'gallery':
      return '画廊';
    case 'generate':
      return '生图';
    case 'edit':
      return '改图';
    case 'system':
      return '系统相关';
    case 'feature':
      return '功能相关';
    case 'account':
      return '账号相关';
    case 'other':
      return '其他';
    default:
      return '未分类';
  }
}

String feedbackStatusLabel(String? status) {
  switch (status) {
    case 'collected':
      return '已收集';
    case 'accepted':
      return '已接收';
    case 'rejected':
      return '已拒绝';
    case 'resolved':
      return '已解决';
    case 'closed':
      return '已关闭';
    default:
      return '全部状态';
  }
}

Color feedbackStatusColor(BuildContext context, String? status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case 'accepted':
      return scheme.primary;
    case 'resolved':
      return Colors.green;
    case 'rejected':
      return scheme.error;
    case 'closed':
      return Colors.grey;
    case 'collected':
    default:
      return Colors.orange;
  }
}

List<Map<String, dynamic>> feedbackItems(dynamic data) {
  dynamic raw = data;
  if (raw is Map) {
    raw = raw['items'] ?? raw['data'] ?? raw['list'] ?? raw['results'] ?? [];
  }
  return (raw as List? ?? [])
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, dynamic> feedbackItem(dynamic data) {
  if (data is Map) {
    final inner = data['item'] ?? data['data'] ?? data['feedback'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return Map<String, dynamic>.from(data);
  }
  return <String, dynamic>{};
}

String feedbackText(dynamic value, {String fallback = '-'}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String feedbackDate(dynamic raw) {
  return formatLocalTime(raw);
}

List<String> feedbackTags(dynamic raw) {
  if (raw is List) {
    return raw
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty) return const [];
  return text
      .split(RegExp(r'[,，、\s]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

String aiField(Map<String, dynamic> item, List<String> keys) {
  for (final key in keys) {
    final text = item[key]?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  final ai = item['ai'] ?? item['ai_summary'];
  if (ai is Map) {
    final map = Map<String, dynamic>.from(ai);
    for (final key in keys) {
      final text = map[key]?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
  }
  return '';
}
