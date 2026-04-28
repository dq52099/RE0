import 'package:flutter/material.dart';

Future<void> showPointsSheet(
  BuildContext context,
  Future<Map<String, dynamic>> summaryFuture, {
  Color? accentColor,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final highlight = accentColor ?? theme.colorScheme.primary;
      return SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.72,
          child: FutureBuilder<Map<String, dynamic>>(
            future: summaryFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      snapshot.error?.toString() ?? '读取积分明细失败。',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return _PointsSheetContent(
                data: snapshot.data ?? const <String, dynamic>{},
                highlight: highlight,
              );
            },
          ),
        ),
      );
    },
  );
}

class _PointsSheetContent extends StatelessWidget {
  const _PointsSheetContent({
    required this.data,
    required this.highlight,
  });

  final Map<String, dynamic> data;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = _intValue(data['points']);
    final todayDelta = _intValue(data['today_delta']);
    final rules = _maps(data['rules']);
    final events = _maps(data['today_events']);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Row(
          children: [
            Icon(Icons.toll_outlined, color: highlight),
            const SizedBox(width: 8),
            Text('积分明细', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: highlight.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: highlight.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _metric(
                  context,
                  label: '当前积分',
                  value: points.toString(),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: highlight.withOpacity(0.2),
              ),
              Expanded(
                child: _metric(
                  context,
                  label: '今日变化',
                  value: _signed(todayDelta),
                  color: todayDelta >= 0
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('积分规则', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...rules.map((item) => _ruleTile(context, item)),
        const SizedBox(height: 16),
        Text('今日变化', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (events.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '今天还没有积分变化',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          ...events.map((item) => _eventTile(context, item)),
      ],
    );
  }

  Widget _metric(
    BuildContext context, {
    required String label,
    required String value,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _ruleTile(BuildContext context, Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final delta = _intValue(item['points_delta']);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlight.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: highlight.withOpacity(0.14),
            child: Icon(Icons.add, size: 17, color: highlight),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['label']?.toString() ?? '-',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item['description']?.toString() ?? '',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _signed(delta),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: highlight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventTile(BuildContext context, Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final delta = _intValue(item['points_delta']);
    final color = delta >= 0 ? highlight : theme.colorScheme.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Icon(Icons.history, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['label']?.toString() ?? '-',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _formatTime(item['created_at']?.toString()),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            _signed(delta),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) {
    return [];
  }
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

int _intValue(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

String _signed(int value) => value > 0 ? '+$value' : value.toString();

String _formatTime(String? raw) {
  final parsed = raw == null ? null : DateTime.tryParse(raw);
  if (parsed == null) return '';
  final local = parsed.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
