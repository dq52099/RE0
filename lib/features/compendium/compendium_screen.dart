import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/brand_background.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/providers.dart';
import 'image_preview_screen.dart';

class CompendiumScreen extends ConsumerStatefulWidget {
  const CompendiumScreen({super.key});

  @override
  ConsumerState<CompendiumScreen> createState() => _CompendiumScreenState();
}

class _CompendiumScreenState extends ConsumerState<CompendiumScreen>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 30;
  static const _hiddenStorageKey = 'hidden_history_items';

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
  final Set<String> _hiddenKeys = {};
  final Set<String> _deletingKeys = {};
  Timer? _searchDebounce;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = false;
  String? _error;
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _hiddenKeys.addAll(
      ref.read(sharedPrefsProvider).getStringList(_hiddenStorageKey) ?? [],
    );
    _scrollController.addListener(_maybeLoadMore);
    _searchController.addListener(_onSearchChanged);
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _query) return;
    setState(() => _query = next);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _load(reset: true),
    );
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
      final response = await ref
          .read(gatewayClientProvider)
          .getHistory(_page, pageSize: _pageSize, query: _query);
      final nextItems = (response['items'] as List? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final totalPages = int.tryParse(response['total_pages']?.toString() ?? '') ?? _page;
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(nextItems);
        _hasMore = _page < totalPages && nextItems.isNotEmpty;
        _page += 1;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = friendlyError(error, fallback: '无法读取记忆回廊。'));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _maybeLoadMore() {
    if (_scrollController.position.extentAfter < 700) {
      _load();
    }
  }

  Future<void> _refresh() async {
    await _load(reset: true);
  }

  List<Map<String, dynamic>> get _visibleItems {
    final visible = _items
        .where((item) => !_hiddenKeys.contains(_historyKey(item)))
        .toList();
    final query = _query.toLowerCase();
    if (query.isEmpty) {
      return visible;
    }
    return visible.where((item) => _matchesQuery(item, query)).toList();
  }

  bool _matchesQuery(Map<String, dynamic> item, String query) {
    final haystack = [
      item['prompt'],
      item['action'],
      item['status'],
      item['size'],
      item['quality'],
      item['background'],
      item['output_format'],
      item['error_message'],
      item['created_at'],
    ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
    return haystack.contains(query);
  }

  String _historyKey(Map<String, dynamic> item) {
    final id = item['id']?.toString();
    if (id != null && id.isNotEmpty) return id;
    final url = item['url']?.toString();
    if (url != null && url.isNotEmpty) return url;
    return '${item['created_at']}-${item['image_index']}-${item['prompt']}';
  }

  Future<void> _deleteHistoryItem(Map<String, dynamic> item) async {
    final key = _historyKey(item);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除图片记录'),
        content: const Text('删除后会从当前手机的记忆回廊中移除，并清理对应图片缓存。'),
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

    setState(() => _deletingKeys.add(key));
    var serverDeleted = false;
    try {
      final id = item['id']?.toString();
      if (id != null && id.isNotEmpty) {
        await ref.read(gatewayClientProvider).deleteHistoryItem(id);
        serverDeleted = true;
      }
    } catch (_) {
      serverDeleted = false;
    }

    try {
      final url = item['url']?.toString();
      if (url != null && url.isNotEmpty) {
        await ref.read(imageCacheProvider).removeCachedFileFor(url);
      }
      _hiddenKeys.add(key);
      await ref
          .read(sharedPrefsProvider)
          .setStringList(_hiddenStorageKey, _hiddenKeys.toList());
      if (!mounted) return;
      setState(() => _deletingKeys.remove(key));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(serverDeleted ? '图片记录已删除。' : '图片记录已从本机隐藏。'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _deletingKeys.remove(key));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '删除图片失败。'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final brand = ref.watch(brandProvider);
    final visibleItems = _visibleItems;

    return Scaffold(
      appBar: AppBar(
        title: Text(brand.historyTitle),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: BrandBackground(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            controller: _scrollController,
            cacheExtent: 1200,
            slivers: [
              SliverToBoxAdapter(child: _searchBar(brand)),
              if (_error != null && _items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _errorState(_error!),
                )
              else if (_items.isEmpty && _isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(brand.emptyHistoryText)),
                )
              else if (visibleItems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(_query.isEmpty ? brand.emptyHistoryText : '没有匹配的图片记录'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = visibleItems[index];
                        return KeyedSubtree(
                          key: ValueKey(item['id'] ?? item['url'] ?? index),
                          child: _historyCard(brand, item),
                        );
                      },
                      childCount: visibleItems.length,
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Center(
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : _hasMore
                            ? TextButton(
                                onPressed: () => _load(),
                                child: const Text('加载更多'),
                              )
                            : const Text('没有更多记录'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar(AppBrand brand) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          labelText: '搜索图片',
          hintText: '提示词、尺寸、状态、时间',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: '清空',
                  icon: const Icon(Icons.close),
                  onPressed: _searchController.clear,
                ),
        ),
      ),
    );
  }

  Widget _historyCard(AppBrand brand, Map<String, dynamic> item) {
    final imageUrl = item['url']?.toString();
    final key = _historyKey(item);
    final isDeleting = _deletingKeys.contains(key);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ImagePreviewScreen(
                    url: imageUrl,
                    title: item['action'] == 'generate'
                        ? brand.generateActionLabel
                        : brand.editActionLabel,
                  ),
                ),
              ),
              child: CachedGatewayImage(
                url: imageUrl,
                width: double.infinity,
                height: 238,
                borderRadius: brand.historyImageRadius,
                fit: BoxFit.cover,
                accentColor: brand.primaryColor,
                cacheWidth: 720,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: item['status'] == 'success'
                            ? brand.successColor
                            : brand.warningColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item['status'] == 'success' ? '成功' : '失败',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['action'] == 'generate'
                            ? brand.generateActionLabel
                            : brand.editActionLabel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item['size']?.toString() ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    IconButton(
                      tooltip: '删除',
                      icon: isDeleting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.delete_outline),
                      color: brand.warningColor,
                      onPressed: isDeleting ? null : () => _deleteHistoryItem(item),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item['prompt']?.toString() ?? ''),
                if (item['error_message'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    item['error_message'].toString(),
                    style: TextStyle(color: brand.warningColor),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
