import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/brand_background.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/providers.dart';
import '../compendium/image_preview_screen.dart';
import 'gallery_detail_screen.dart';

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({
    super.key,
    this.refreshToken = 0,
  });

  final int refreshToken;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(brand.galleryTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: brand.galleryTabLabel),
              Tab(text: brand.favoriteTabLabel),
            ],
          ),
        ),
        body: BrandBackground(
          child: TabBarView(
            children: [
              _GalleryTabList(
                key: ValueKey('gallery-$refreshToken'),
                view: 'all',
                emptyText: '画廊还没有公开作品',
              ),
              _GalleryTabList(
                key: ValueKey('favorites-$refreshToken'),
                view: 'favorites',
                emptyText: '还没有收藏的作品',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GalleryTabList extends ConsumerStatefulWidget {
  const _GalleryTabList({
    super.key,
    required this.view,
    required this.emptyText,
  });

  final String view;
  final String emptyText;

  @override
  ConsumerState<_GalleryTabList> createState() => _GalleryTabListState();
}

class _GalleryTabListState extends ConsumerState<_GalleryTabList>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 30;

  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_isLoading) return;
    if (!reset && !_hasMore) return;
    setState(() {
      _isLoading = true;
      if (reset) {
        _page = 1;
        _hasMore = true;
        _error = null;
      }
    });
    try {
      final response = await ref.read(gatewayClientProvider).getGalleryPosts(
            view: widget.view,
            page: _page,
            pageSize: _pageSize,
          );
      final nextItems = (response['items'] as List? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final totalPages =
          int.tryParse(response['total_pages']?.toString() ?? '') ?? _page;
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(nextItems);
        _hasMore = _page < totalPages && nextItems.isNotEmpty;
        _page += 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error, fallback: '读取画廊失败。'));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _maybeLoadMore() {
    if (_scrollController.position.extentAfter < 600) {
      _load();
    }
  }

  Future<void> _refresh() => _load(reset: true);

  Future<void> _toggleLike(Map<String, dynamic> item) async {
    final updated = await ref
        .read(gatewayClientProvider)
        .toggleGalleryLike(item['id'].toString());
    _replaceItem(updated);
  }

  Future<void> _toggleFavorite(Map<String, dynamic> item) async {
    final updated = await ref
        .read(gatewayClientProvider)
        .toggleGalleryFavorite(item['id'].toString());
    _replaceItem(updated);
    if (widget.view == 'favorites' && updated['favorited'] != true && mounted) {
      setState(() {
        _items.removeWhere((entry) => entry['id'] == updated['id']);
      });
    }
  }

  Future<void> _openComments(Map<String, dynamic> item) async {
    final controller = TextEditingController();
    final comments = await ref
        .read(gatewayClientProvider)
        .getGalleryComments(item['id'].toString());
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 320,
                  child: comments.isEmpty
                      ? const Center(child: Text('还没有评论'))
                      : ListView.separated(
                          itemCount: comments.length,
                          separatorBuilder: (_, __) => const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(comment['display_name']?.toString() ?? '-'),
                              subtitle: Text(comment['content']?.toString() ?? ''),
                              trailing: Text(
                                _formatGalleryTime(comment['created_at']?.toString()),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            );
                          },
                        ),
                ),
                TextField(
                  controller: controller,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '评论',
                    hintText: '写下你对这张图的看法',
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;
                      try {
                        await ref.read(gatewayClientProvider).addGalleryComment(
                              item['id'].toString(),
                              text,
                            );
                        if (!mounted) return;
                        Navigator.pop(context);
                        await _refresh();
                      } catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(friendlyError(error))),
                        );
                      }
                    },
                    child: const Text('发表评论'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    controller.dispose();
  }

  void _replaceItem(Map<String, dynamic> updated) {
    if (!mounted) return;
    setState(() {
      final index =
          _items.indexWhere((item) => item['id']?.toString() == updated['id']?.toString());
      if (index >= 0) {
        _items[index] = updated;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final brand = ref.watch(brandProvider);
    if (_error != null && _items.isEmpty) {
      return Center(child: Text(_error!));
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _items.isEmpty ? 1 : _items.length + 1,
        itemBuilder: (context, index) {
          if (_items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 120),
              child: Center(child: Text(widget.emptyText)),
            );
          }
          if (index == _items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _hasMore
                        ? TextButton(
                            onPressed: _load,
                            child: const Text('加载更多'),
                          )
                        : const Text('没有更多作品'),
              ),
            );
          }
          final item = _items[index];
          return _galleryCard(brand, item, index);
        },
      ),
    );
  }

  Widget _galleryCard(AppBrand brand, Map<String, dynamic> item, int index) {
    final imageUrl = item['image_url']?.toString() ?? '';
    final previewItems = _items
        .map(
          (entry) => PreviewImageEntry(
            url: entry['image_url']?.toString() ?? '',
            title: entry['prompt']?.toString(),
            caption: entry['display_name']?.toString(),
          ),
        )
        .where((entry) => entry.url.isNotEmpty)
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
          if (imageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ImagePreviewScreen(
                    items: previewItems,
                    initialIndex: index,
                  ),
                ),
              ),
              child: CachedGatewayImage(
                url: imageUrl,
                width: double.infinity,
                height: 240,
                fit: BoxFit.cover,
                accentColor: brand.primaryColor,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: brand.primaryColor.withOpacity(0.14),
                      backgroundImage: (item['author_avatar_url']?.toString() ?? '').isNotEmpty
                          ? NetworkImage(item['author_avatar_url'].toString())
                          : null,
                      child: (item['author_avatar_url']?.toString() ?? '').isEmpty
                          ? Text(
                              (item['display_name']?.toString() ?? '画').substring(0, 1),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['display_name']?.toString() ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _formatGalleryTime(item['created_at']?.toString()),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item['action']?.toString() == 'generate'
                          ? brand.generateActionLabel
                          : brand.editActionLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _promptSummary(item),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _actionButton(
                      icon: item['liked'] == true
                          ? Icons.favorite
                          : Icons.favorite_border,
                      label: '${item['like_count'] ?? 0}',
                      color: item['liked'] == true ? brand.warningColor : null,
                      onTap: () => _toggleLike(item),
                    ),
                    const SizedBox(width: 8),
                    _actionButton(
                      icon: item['favorited'] == true
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      label: '${item['favorite_count'] ?? 0}',
                      color: item['favorited'] == true ? brand.primaryColor : null,
                      onTap: () => _toggleFavorite(item),
                    ),
                    const SizedBox(width: 8),
                    _actionButton(
                      icon: Icons.chat_bubble_outline,
                      label: '${item['comment_count'] ?? 0}',
                      onTap: () => _openDetails(item),
                    ),
                    const SizedBox(width: 8),
                    _actionButton(
                      icon: Icons.open_in_full,
                      label: '详情',
                      onTap: () => _openDetails(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetails(Map<String, dynamic> item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GalleryDetailScreen(initialPost: item),
      ),
    );
    await _refresh();
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  String _formatGalleryTime(String? raw) {
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  String _promptSummary(Map<String, dynamic> item) {
    if (item['viewer_has_commented'] == true) {
      return item['prompt']?.toString() ?? '';
    }
    return '评论后可解锁提示词';
  }
}
