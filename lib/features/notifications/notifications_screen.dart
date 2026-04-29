import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/brand_background.dart';
import '../../core/compact_save_notice.dart';
import '../../core/providers.dart';
import '../feedback/feedback_screen.dart';
import '../gallery/gallery_detail_screen.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Future<Map<String, dynamic>>? _future;
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ref.read(gatewayClientProvider).getMyNotifications();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(gatewayClientProvider).markAllNotificationsRead();
      if (!mounted) return;
      setState(_reload);
      showCenterNotice(context, '通知已全部标记为已读');
    } catch (error) {
      if (!mounted) return;
      _showError(error, '标记通知失败。');
    }
  }

  Future<void> _openNotification(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isNotEmpty && item['is_read'] != true) {
      setState(() => _busyIds.add(id));
      try {
        await ref.read(gatewayClientProvider).markNotificationRead(id);
      } catch (_) {
        // Opening the target is still useful if read marking fails.
      } finally {
        if (mounted) setState(() => _busyIds.remove(id));
      }
    }
    if (!mounted) return;
    final resourceType = item['resource_type']?.toString();
    final resourceId = item['resource_id']?.toString() ?? '';
    if (resourceType == 'gallery_post' && resourceId.isNotEmpty) {
      try {
        final post =
            await ref.read(gatewayClientProvider).getGalleryPost(resourceId);
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GalleryDetailScreen(initialPost: post),
          ),
        );
      } catch (error) {
        if (!mounted) return;
        _showError(error, '打开画廊作品失败。');
      }
    } else if (resourceType == 'feedback') {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FeedbackScreen()),
      );
    }
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知'),
        actions: [
          IconButton(
            tooltip: '全部已读',
            icon: const Icon(Icons.done_all_outlined),
            onPressed: _markAllRead,
          ),
        ],
      ),
      body: BrandBackground(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            final items = (snapshot.data?['items'] as List? ?? [])
                .whereType<Map>()
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (snapshot.connectionState != ConnectionState.done)
                    const Padding(
                      padding: EdgeInsets.only(top: 120),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    _errorState(snapshot.error)
                  else if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 120),
                      child: Center(child: Text('暂时没有通知')),
                    )
                  else
                    ...items.map(_notificationCard),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _notificationCard(Map<String, dynamic> item) {
    final unread = item['is_read'] != true;
    final actorName = item['actor_display_name']?.toString().trim();
    final actorAvatar = item['actor_avatar_url']?.toString().trim() ?? '';
    final id = item['id']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context)
          .colorScheme
          .surface
          .withValues(alpha: unread ? 0.78 : 0.58),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _busyIds.contains(id) ? null : () => _openNotification(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage:
                    actorAvatar.isNotEmpty ? NetworkImage(actorAvatar) : null,
                child: actorAvatar.isEmpty
                    ? Text(_initial(actorName ?? item['type']?.toString()))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['title']?.toString() ?? '通知',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _bodyText(item, actorName),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(item['created_at']?.toString()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorState(Object? error) {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 42),
          const SizedBox(height: 12),
          Text(
            friendlyError(error ?? '读取通知失败。', fallback: '读取通知失败。'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }

  String _bodyText(Map<String, dynamic> item, String? actorName) {
    final body = item['body']?.toString().trim() ?? '';
    if (actorName == null || actorName.isEmpty) return body;
    final type = item['type']?.toString();
    if (type == 'gallery_comment') return '$actorName 评论了你：$body';
    if (type == 'gallery_like') return '$actorName 点赞了你的作品';
    if (type == 'gallery_favorite') return '$actorName 收藏了你的作品';
    return body;
  }

  String _initial(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '通' : text.substring(0, 1);
  }

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

  void _showError(Object error, String fallback) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(friendlyError(error, fallback: fallback))),
    );
  }
}
