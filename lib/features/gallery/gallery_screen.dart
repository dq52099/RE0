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
    return Scaffold(
      appBar: AppBar(
        title: Text(brand.galleryTitle),
      ),
      body: BrandBackground(
        child: GalleryFeedView(
          key: ValueKey('gallery-$refreshToken'),
          view: 'all',
          emptyText: '画廊还没有公开作品',
        ),
      ),
    );
  }
}

class GalleryFeedView extends ConsumerStatefulWidget {
  const GalleryFeedView({
    super.key,
    required this.view,
    required this.emptyText,
  });

  final String view;
  final String emptyText;

  @override
  ConsumerState<GalleryFeedView> createState() => _GalleryFeedViewState();
}

class _GalleryFeedViewState extends ConsumerState<GalleryFeedView>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
  int _page = 1;
  int _totalPages = 1;
  int _pageSize = 12;
  int _columns = 2;
  bool _isLoading = false;
  String? _error;
  String _sort = 'time';
  String? _actionFilter;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (reset) {
        _page = 1;
        _error = null;
      }
    });
    try {
      final response = await ref.read(gatewayClientProvider).getGalleryPosts(
            view: widget.view,
            keyword: _searchController.text.trim(),
            action: _actionFilter,
            sort: _sort,
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
        _items
          ..clear()
          ..addAll(nextItems);
        _totalPages = totalPages;
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _toolbar(brand),
          const SizedBox(height: 16),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 120),
              child: Center(child: Text(widget.emptyText)),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.76,
              ),
              itemBuilder: (context, index) {
                final item = _items[index];
                return _galleryCard(brand, item, index);
              },
            ),
          const SizedBox(height: 16),
          _paginationBar(),
        ],
      ),
    );
  }

  Widget _toolbar(AppBrand brand) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _load(reset: true),
          decoration: const InputDecoration(
            labelText: '搜索画廊',
            hintText: '按提示词或作者搜索',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('全部', _actionFilter == null, () {
              setState(() => _actionFilter = null);
              _load(reset: true);
            }),
            _chip(brand.generateActionLabel, _actionFilter == 'generate', () {
              setState(() => _actionFilter = 'generate');
              _load(reset: true);
            }),
            _chip(brand.editActionLabel, _actionFilter == 'edit', () {
              setState(() => _actionFilter = 'edit');
              _load(reset: true);
            }),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _smallDropdown(
              label: '排序',
              value: _sort,
              width: 132,
              items: const {
                'time': '时间',
                'popular': '最受欢迎',
                'comments': '评论最多',
                'downloads': '下载最多',
              },
              onChanged: (value) {
                setState(() => _sort = value!);
                _load(reset: true);
              },
            ),
            _smallDropdown(
              label: '每页',
              value: _pageSize,
              width: 112,
              items: const {
                12: '12张',
                24: '24张',
                36: '36张',
              },
              onChanged: (value) {
                setState(() => _pageSize = value!);
                _load(reset: true);
              },
            ),
            _smallDropdown(
              label: '列数',
              value: _columns,
              width: 96,
              items: const {
                2: '两列',
                3: '三列',
              },
              onChanged: (value) {
                setState(() => _columns = value!);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      showCheckmark: false,
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  Widget _smallDropdown<T>({
    required String label,
    required T value,
    required double width,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        icon: const Icon(Icons.expand_more, size: 18),
        menuMaxHeight: 280,
        borderRadius: BorderRadius.circular(16),
        alignment: Alignment.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w400,
            ),
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: items.entries
            .map(
              (entry) => DropdownMenuItem<T>(
                value: entry.key,
                child: Center(
                  child: Text(
                    entry.value,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                  ),
                ),
              ),
            )
            .toList(),
        selectedItemBuilder: (context) => items.values
            .map(
              (label) => Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _paginationBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _page <= 1 || _isLoading
              ? null
              : () {
                  setState(() => _page -= 1);
                  _load();
                },
          icon: const Icon(Icons.chevron_left),
        ),
        Text('第 $_page / $_totalPages 页'),
        IconButton(
          onPressed: _page >= _totalPages || _isLoading
              ? null
              : () {
                  setState(() => _page += 1);
                  _load();
                },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
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
                    initialIndex: previewItems
                        .indexWhere((entry) => entry.url == imageUrl)
                        .clamp(0, previewItems.length - 1),
                    showDownload: false,
                  ),
                ),
              ),
              child: CachedGatewayImage(
                url: imageUrl,
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                showDownload: false,
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
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                item['display_name']?.toString() ?? '-',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              _levelBadge(item['level_info'] as Map?),
                            ],
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
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                      icon: Icons.download_outlined,
                      label: '${item['download_count'] ?? 0}',
                      onTap: () => _openDetails(item),
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

  Widget _levelBadge(Map? levelInfo) {
    final label = levelInfo?['label']?.toString();
    if (label == null || label.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _badgeColor(levelInfo?['badge_color']?.toString()).withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: _badgeColor(levelInfo?['badge_color']?.toString()),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _badgeColor(String? value) {
    if (value == null || value.isEmpty) {
      return Theme.of(context).colorScheme.primary;
    }
    final hex = value.replaceFirst('#', '');
    final normalized = hex.length == 6 ? 'FF$hex' : hex;
    return Color(int.parse(normalized, radix: 16));
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
    if (item['can_view_prompt'] == true) {
      return item['prompt']?.toString() ?? '';
    }
    return '评论后可解锁提示词';
  }
}
