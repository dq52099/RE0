import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/brand_background.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/compact_dropdown_field.dart';
import '../../core/compact_save_notice.dart';
import '../../core/gateway_avatar.dart';
import '../../core/local_time_format.dart';
import '../../core/providers.dart';
import '../../core/value_parsers.dart';
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
    if (widget.view == 'liked' && !boolish(updated['liked']) && mounted) {
      setState(() {
        _items.removeWhere((entry) => entry['id'] == updated['id']);
      });
    }
  }

  Future<void> _toggleFavorite(Map<String, dynamic> item) async {
    final updated = await ref
        .read(gatewayClientProvider)
        .toggleGalleryFavorite(item['id'].toString());
    _replaceItem(updated);
    if (widget.view == 'favorites' &&
        !boolish(updated['favorited']) &&
        mounted) {
      setState(() {
        _items.removeWhere((entry) => entry['id'] == updated['id']);
      });
    }
  }

  Future<void> _deletePost(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除画廊作品'),
        content: const Text('删除后会从画廊移除该作品，并撤销该作品产生的积分。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(gatewayClientProvider)
          .deleteGalleryPost(item['id'].toString());
      if (!mounted) return;
      setState(() {
        _items.removeWhere(
            (entry) => entry['id']?.toString() == item['id']?.toString());
      });
      showCenterNotice(context, '作品已删除');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    }
  }

  // Kept for the detail/comment sheet flow when re-enabled from card actions.
  // ignore: unused_element
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
                          separatorBuilder: (_, __) =>
                              const Divider(height: 16),
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  comment['display_name']?.toString() ?? '-'),
                              subtitle:
                                  Text(comment['content']?.toString() ?? ''),
                              trailing: Text(
                                _formatGalleryTime(
                                    comment['created_at']?.toString()),
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
      final index = _items.indexWhere(
          (item) => item['id']?.toString() == updated['id']?.toString());
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
            Column(
              children: [
                for (var index = 0; index < _items.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _items.length - 1 ? 0 : 12,
                    ),
                    child: _galleryCard(brand, _items[index]),
                  ),
              ],
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
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          onSubmitted: (_) => _load(reset: true),
          decoration: const InputDecoration(
            labelText: '搜索画廊',
            hintText: '按提示词或作者搜索',
            prefixIcon: Icon(Icons.search),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            prefixIconConstraints: BoxConstraints(minWidth: 38, minHeight: 38),
          ),
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final fieldWidth = (constraints.maxWidth - 8) / 2;
            return Row(
              children: [
                Expanded(
                  child: _smallDropdown(
                    label: '排序',
                    value: _sort,
                    width: fieldWidth,
                    menuWidth: fieldWidth,
                    items: const {
                      'time': '最近时间',
                      'popular': '最受欢迎',
                      'comments': '评论最多',
                      'downloads': '下载最多',
                    },
                    onChanged: (value) {
                      setState(() => _sort = value!);
                      _load(reset: true);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _smallDropdown(
                    label: '每页',
                    value: _pageSize,
                    width: fieldWidth,
                    menuWidth: fieldWidth,
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
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return ChoiceChip(
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  Widget _smallDropdown<T>({
    required String label,
    required T value,
    required double width,
    double? menuWidth,
    required Map<T, String> items,
    required ValueChanged<T?> onChanged,
  }) {
    return CompactDropdownField<T>(
      label: label,
      value: value,
      width: width,
      menuWidth: menuWidth,
      items: items.entries
          .map(
            (entry) => CompactDropdownField.centeredItem<T>(
              entry.key,
              entry.value,
              context,
            ),
          )
          .toList(),
      selectedLabels: items.values.toList(),
      onChanged: onChanged,
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

  Widget _galleryCard(AppBrand brand, Map<String, dynamic> item) {
    const imageHeight = 288.0;
    const cardPadding = 12.0;
    const avatarRadius = 21.0;
    const nameFontSize = 14.0;
    const actionFontSize = 12.0;
    const actionIconSize = 16.0;
    const actionSpacing = 8.0;
    const buttonPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 8);
    final liked = boolish(item['liked']);
    final favorited = boolish(item['favorited']);
    final action = item['action']?.toString() == 'edit' ? 'edit' : 'generate';
    final actionColor = _actionAccent(brand, action);
    final currentUser = ref.read(authStateProvider);
    final isOwner =
        currentUser?['id']?.toString() == item['user_id']?.toString();
    final canDelete = boolish(item['can_delete']) || isOwner;
    final imageUrl = item['image_url']?.toString() ?? '';
    final previewItems = _items
        .map(
          (entry) => PreviewImageEntry(
            url: entry['image_url']?.toString() ?? '',
            title: entry['display_name']?.toString(),
            caption: _promptSummary(entry),
          ),
        )
        .where((entry) => entry.url.isNotEmpty)
        .toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: actionColor.withValues(alpha: 0.45),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            _imageWithSourcePreview(
              brand: brand,
              imageUrl: imageUrl,
              sourceUrl: item['source_image_url']?.toString() ?? '',
              height: imageHeight,
              onMainTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ImagePreviewScreen(
                    items: previewItems,
                    initialIndex: previewItems
                        .indexWhere((entry) => entry.url == imageUrl)
                        .clamp(0, previewItems.length - 1)
                        .toInt(),
                    showDownload: false,
                  ),
                ),
              ),
              caption: _promptSummary(item),
            ),
          Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _authorAvatar(
                      brand: brand,
                      item: item,
                      radius: avatarRadius,
                      fontSize: nameFontSize,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                item['display_name']?.toString() ?? '-',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: nameFontSize,
                                ),
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
                    _actionPill(
                      label: action == 'generate'
                          ? brand.generateActionLabel
                          : brand.editActionLabel,
                      color: actionColor,
                      icon: action == 'generate'
                          ? Icons.auto_awesome_outlined
                          : Icons.brush_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _promptSummary(item),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                        fontSize: 13,
                        height: 1.35,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: actionSpacing,
                  runSpacing: actionSpacing,
                  children: [
                    _actionButton(
                      icon: liked ? Icons.favorite : Icons.favorite_border,
                      label: '${item['like_count'] ?? 0}',
                      color: liked ? brand.warningColor : null,
                      onTap: () => _toggleLike(item),
                      iconSize: actionIconSize,
                      fontSize: actionFontSize,
                      padding: buttonPadding,
                    ),
                    _actionButton(
                      icon: favorited ? Icons.bookmark : Icons.bookmark_border,
                      label: '${item['favorite_count'] ?? 0}',
                      color: favorited ? brand.primaryColor : null,
                      onTap: () => _toggleFavorite(item),
                      iconSize: actionIconSize,
                      fontSize: actionFontSize,
                      padding: buttonPadding,
                    ),
                    _actionButton(
                      icon: Icons.download_outlined,
                      label: '${item['download_count'] ?? 0}',
                      onTap: () => _openDetails(item),
                      iconSize: actionIconSize,
                      fontSize: actionFontSize,
                      padding: buttonPadding,
                    ),
                    _actionButton(
                      icon: Icons.chat_bubble_outline,
                      label: '${item['comment_count'] ?? 0}',
                      onTap: () => _openDetails(item),
                      iconSize: actionIconSize,
                      fontSize: actionFontSize,
                      padding: buttonPadding,
                    ),
                    _actionButton(
                      icon: Icons.open_in_full,
                      label: '详情',
                      onTap: () => _openDetails(item),
                      iconSize: actionIconSize,
                      fontSize: actionFontSize,
                      padding: buttonPadding,
                    ),
                    if (canDelete)
                      _actionButton(
                        icon: Icons.delete_outline,
                        label: '删除',
                        color: brand.warningColor,
                        onTap: () => _deletePost(item),
                        iconSize: actionIconSize,
                        fontSize: actionFontSize,
                        padding: buttonPadding,
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
    required double iconSize,
    required double fontSize,
    required EdgeInsets padding,
  }) {
    final gap = fontSize <= 10 ? 4.0 : 6.0;
    final activeColor = color;
    final foregroundColor = activeColor != null
        ? Colors.white
        : Theme.of(context).textTheme.bodySmall?.color;
    final surface = Theme.of(context).colorScheme.surface;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: activeColor != null
              ? activeColor
              : surface.withValues(alpha: 0.5),
          border: Border.all(
            color: activeColor != null ? activeColor : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: activeColor != null
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.16),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: foregroundColor,
            ),
            SizedBox(width: gap),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: fontSize,
                    color: foregroundColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Color _actionAccent(AppBrand brand, String action) {
    return action == 'edit' ? brand.warningColor : brand.primaryColor;
  }

  Widget _imageWithSourcePreview({
    required AppBrand brand,
    required String imageUrl,
    required String sourceUrl,
    required double height,
    required VoidCallback onMainTap,
    String? caption,
  }) {
    final hasSource = sourceUrl.isNotEmpty && sourceUrl != imageUrl;
    return Stack(
      children: [
        GestureDetector(
          onTap: onMainTap,
          child: CachedGatewayImage(
            url: imageUrl,
            width: double.infinity,
            height: height,
            fit: BoxFit.cover,
            showDownload: false,
            accentColor: brand.primaryColor,
          ),
        ),
        if (hasSource)
          Positioned(
            left: 10,
            top: 10,
            child: Material(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ImagePreviewScreen(
                      showDownload: false,
                      items: [
                        PreviewImageEntry(
                          url: sourceUrl,
                          title: '原图',
                          caption: caption,
                        ),
                      ],
                    ),
                  ),
                ),
                child: SizedBox(
                  width: 70,
                  height: 70,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedGatewayImage(
                        url: sourceUrl,
                        fit: BoxFit.cover,
                        showDownload: false,
                        accentColor: brand.warningColor,
                        cacheWidth: 180,
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          color: Colors.black.withValues(alpha: 0.58),
                          alignment: Alignment.center,
                          child: const Text(
                            '原图',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _actionPill({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _levelBadge(Map? levelInfo) {
    final label = levelInfo?['label']?.toString();
    if (label == null || label.isEmpty) {
      return const SizedBox.shrink();
    }
    final color = _badgeColor(levelInfo?['badge_color']?.toString());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _authorAvatar({
    required AppBrand brand,
    required Map<String, dynamic> item,
    required double radius,
    required double fontSize,
  }) {
    final avatarUrl = item['author_avatar_url']?.toString().trim() ?? '';
    final displayName = item['display_name']?.toString() ?? '画';
    final avatar = GatewayAvatar(
      avatarUrl: avatarUrl,
      displayName: displayName,
      radius: radius,
      backgroundColor: brand.primaryColor.withValues(alpha: 0.14),
      fallback: '画',
      textStyle: TextStyle(fontSize: fontSize),
    );
    if (avatarUrl.isEmpty) return avatar;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => _openAvatarPreview(avatarUrl, displayName),
      child: avatar,
    );
  }

  void _openAvatarPreview(String avatarUrl, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImagePreviewScreen(
          showDownload: false,
          items: [
            PreviewImageEntry(
              url: avatarUrl,
              title: title.isEmpty ? '头像' : '$title 的头像',
            ),
          ],
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
    return formatLocalTime(raw, fallback: '');
  }

  String _promptSummary(Map<String, dynamic> item) {
    if (boolish(item['can_view_prompt'])) {
      return item['prompt']?.toString() ?? '';
    }
    return '评论后可解锁提示词';
  }
}
