import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/brand_background.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/providers.dart';
import 'image_preview_screen.dart';

class CompendiumScreen extends ConsumerStatefulWidget {
  const CompendiumScreen({
    super.key,
    this.refreshToken = 0,
  });

  final int refreshToken;

  @override
  ConsumerState<CompendiumScreen> createState() => _CompendiumScreenState();
}

class _CompendiumScreenState extends ConsumerState<CompendiumScreen>
    with AutomaticKeepAliveClientMixin {
  static const _pageSize = 30;
  static const _hiddenStorageKey = 'hidden_history_items';

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<Map<String, dynamic>> _items = [];
  final Set<String> _hiddenKeys = {};
  final Set<String> _deletingKeys = {};
  final Set<String> _publishingKeys = {};
  final Set<String> _retryingKeys = {};
  Timer? _searchDebounce;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isBulkDeleting = false;
  bool _pendingReset = false;
  String? _error;
  String _query = '';
  String? _statusFilter;
  String? _actionFilter;

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
    _searchFocusNode.dispose();
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CompendiumScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _refresh();
    }
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
    if (_isLoading) {
      if (reset) {
        _pendingReset = true;
      }
      return;
    }
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
          .getHistory(
            _page,
            pageSize: _pageSize,
            keyword: _query,
            action: _actionFilter,
            status: _statusFilter,
          );
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
      if (_pendingReset) {
        _pendingReset = false;
        unawaited(_load(reset: true));
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
    return _items
        .where((item) => !_hiddenKeys.contains(_historyKey(item)))
        .where(_matchesFilters)
        .toList();
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

  bool _matchesFilters(Map<String, dynamic> item) {
    final query = _query.toLowerCase();
    if (query.isNotEmpty && !_matchesQuery(item, query)) {
      return false;
    }
    if (_statusFilter != null && item['status']?.toString() != _statusFilter) {
      return false;
    }
    if (_actionFilter != null && item['action']?.toString() != _actionFilter) {
      return false;
    }
    return true;
  }

  void _dismissKeyboard() {
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  Future<void> _setStatusFilter(String? value) async {
    if (_statusFilter == value) return;
    _dismissKeyboard();
    setState(() => _statusFilter = value);
    await _load(reset: true);
  }

  Future<void> _setActionFilter(String? value) async {
    if (_actionFilter == value) return;
    _dismissKeyboard();
    setState(() => _actionFilter = value);
    await _load(reset: true);
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
    _dismissKeyboard();
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

    try {
      await _hideHistoryItems([item], deletingKeys: {key});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片记录已清理。')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '删除图片失败。'))),
      );
    }
  }

  Future<void> _hideHistoryItems(
    List<Map<String, dynamic>> items, {
    Set<String>? deletingKeys,
  }) async {
    final keys = items.map(_historyKey).toSet();
    try {
      if (deletingKeys != null && deletingKeys.isNotEmpty) {
        setState(() => _deletingKeys.addAll(deletingKeys));
      }
      for (final item in items) {
        try {
          final id = item['id']?.toString();
          if (id != null && id.isNotEmpty) {
            await ref.read(gatewayClientProvider).deleteHistoryItem(id);
          }
        } catch (_) {
          // Fall back to local hide if server-side delete is unavailable.
        }
        final url = item['url']?.toString();
        if (url != null && url.isNotEmpty) {
          await ref.read(imageCacheProvider).removeCachedFileFor(url);
        }
      }
      setState(() {
        _hiddenKeys.addAll(keys);
        _items.removeWhere((entry) => keys.contains(_historyKey(entry)));
        _deletingKeys.removeAll(keys);
      });
      await ref
          .read(sharedPrefsProvider)
          .setStringList(_hiddenStorageKey, _hiddenKeys.toList());
    } catch (_) {
      setState(() => _deletingKeys.removeAll(keys));
      rethrow;
    }
  }

  Future<void> _deleteFailedItems(List<Map<String, dynamic>> failedItems) async {
    if (failedItems.isEmpty || _isBulkDeleting) return;
    _dismissKeyboard();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量清理失败记录'),
        content: Text('将移除当前可见的 ${failedItems.length} 条失败记录，并清理对应缓存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('批量删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBulkDeleting = true);
    try {
      await _hideHistoryItems(failedItems);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已清理 ${failedItems.length} 条失败记录。')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '批量删除失败。'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isBulkDeleting = false);
      }
    }
  }

  Future<void> _retryFailedGenerate(Map<String, dynamic> item) async {
    final key = _historyKey(item);
    if (_retryingKeys.contains(key)) return;
    _dismissKeyboard();
    setState(() => _retryingKeys.add(key));
    try {
      final prompt = item['revised_prompt']?.toString().trim().isNotEmpty == true
          ? item['revised_prompt'].toString().trim()
          : item['prompt']?.toString().trim() ?? '';
      if (prompt.isEmpty) {
        throw const GatewayException('这条失败记录没有可重试的提示词。');
      }
      final response = await ref.read(gatewayClientProvider).materialize(
            prompt,
            1,
            item['size']?.toString().trim().isNotEmpty == true
                ? item['size'].toString().trim()
                : 'auto',
            'auto',
            'auto',
            'png',
          );
      ref.read(energyProvider.notifier).state =
          _quotaSummaryFromResponse(response['quota_summary']);
      if (!mounted) return;
      await _hideHistoryItems([item], deletingKeys: {key});
      await _refresh();
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
      final errors = (response['errors'] as List? ?? []).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errors > 0
                ? '已重新生成，新结果已替换旧失败记录，另有 $errors 次尝试未完成。'
                : '已重新生成，新结果已替换旧失败记录。',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '重新生成失败。'))),
      );
    } finally {
      if (mounted) {
        setState(() => _retryingKeys.remove(key));
      }
    }
  }

  Future<void> _copyPrompt(Map<String, dynamic> item) async {
    final prompt = item['prompt']?.toString().trim() ?? '';
    if (prompt.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('提示词已复制。')),
    );
  }

  Future<void> _publishToGallery(Map<String, dynamic> item) async {
    final key = _historyKey(item);
    if (_publishingKeys.contains(key)) return;
    final historyId = item['id']?.toString();
    if (historyId == null || historyId.isEmpty) return;
    setState(() => _publishingKeys.add(key));
    try {
      await ref.read(gatewayClientProvider).publishGalleryPost(historyId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已发布到画廊。')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _publishingKeys.remove(key));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final brand = ref.watch(brandProvider);
    final visibleItems = _visibleItems;
    final failedVisibleItems =
        visibleItems.where((item) => !_isSuccessful(item)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(brand.historyTitle),
        actions: [
          if (failedVisibleItems.isNotEmpty)
            _isBulkDeleting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: '批量删除失败记录',
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: () => _deleteFailedItems(failedVisibleItems),
                  ),
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _searchBar(brand),
                    _filterBar(brand),
                  ],
                ),
              ),
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
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        onTapOutside: (_) => _dismissKeyboard(),
        onSubmitted: (_) => _refresh(),
        decoration: InputDecoration(
          labelText: '搜索图片',
          hintText: '提示词、尺寸、状态、时间',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: '清空',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    _refresh();
                  },
                ),
        ),
      ),
    );
  }

  Widget _filterBar(AppBrand brand) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip(
              label: '全部状态',
              selected: _statusFilter == null,
              onSelected: () => _setStatusFilter(null),
            ),
            _filterChip(
              label: '成功',
              selected: _statusFilter == 'success',
              onSelected: () => _setStatusFilter('success'),
            ),
            _filterChip(
              label: '失败',
              selected: _statusFilter == 'failed',
              onSelected: () => _setStatusFilter('failed'),
            ),
            _filterChip(
              label: '全部操作',
              selected: _actionFilter == null,
              onSelected: () => _setActionFilter(null),
            ),
            _filterChip(
              label: brand.generateActionLabel,
              selected: _actionFilter == 'generate',
              onSelected: () => _setActionFilter('generate'),
            ),
            _filterChip(
              label: brand.editActionLabel,
              selected: _actionFilter == 'edit',
              onSelected: () => _setActionFilter('edit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    final width = label.length >= 5 ? 108.0 : 88.0;
    return SizedBox(
      width: width,
      child: ChoiceChip(
        showCheckmark: false,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.left,
          ),
        ),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }

  Widget _historyCard(AppBrand brand, Map<String, dynamic> item) {
    final imageUrl = item['url']?.toString();
    final key = _historyKey(item);
    final isDeleting = _deletingKeys.contains(key);
    final isPublishing = _publishingKeys.contains(key);
    final isRetrying = _retryingKeys.contains(key);
    final isSuccess = _isSuccessful(item);
    final previewItems = _previewItems(_visibleItems, brand);
    final previewIndex = previewItems.indexWhere((entry) => entry.url == imageUrl);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null && imageUrl.isNotEmpty)
            GestureDetector(
              onLongPress: _dismissKeyboard,
              onTap: () {
                _dismissKeyboard();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ImagePreviewScreen(
                      items: previewItems,
                      initialIndex: previewIndex,
                    ),
                  ),
                );
              },
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
                        color: isSuccess ? brand.successColor : brand.warningColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isSuccess ? '成功' : '失败',
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
                    if (isSuccess)
                      IconButton(
                        tooltip: '发布到画廊',
                        icon: isPublishing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.publish_outlined),
                        color: brand.primaryColor,
                        onPressed: isPublishing ? null : () => _publishToGallery(item),
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
                _promptPanel(brand, item['prompt']?.toString() ?? ''),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metaPill(
                      Icons.schedule_outlined,
                      _formatCreatedAt(item['created_at']?.toString()),
                    ),
                    if (_formatDuration(item['duration_ms']) != null)
                      _metaPill(
                        Icons.timelapse_outlined,
                        _formatDuration(item['duration_ms'])!,
                      ),
                  ],
                ),
                if (!isSuccess) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: brand.warningColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: brand.warningColor.withOpacity(0.26),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.auto_awesome_motion_outlined,
                          size: 18,
                          color: brand.warningColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _failureMessage(brand, item),
                            style: TextStyle(color: brand.warningColor),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_canRetryFailedGenerate(item))
                        OutlinedButton.icon(
                          onPressed: isRetrying
                              ? null
                              : () => _retryFailedGenerate(item),
                          icon: isRetrying
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          label: const Text('重新生成'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _copyPrompt(item),
                        icon: const Icon(Icons.content_copy_outlined),
                        label: const Text('复制提示词'),
                      ),
                    ],
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

  bool _isSuccessful(Map<String, dynamic> item) {
    final imageUrl = item['url']?.toString().trim() ?? '';
    if (imageUrl.isNotEmpty) {
      return true;
    }
    return item['status']?.toString() == 'success';
  }

  Widget _promptPanel(AppBrand brand, String prompt) {
    return SizedBox(
      height: 118,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: brand.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: brand.primaryColor.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notes_outlined,
                  size: 16,
                  color: brand.primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  '提示词',
                  style: TextStyle(
                    color: brand.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                prompt.isEmpty ? '未记录提示词' : prompt,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  String _formatCreatedAt(String? raw) {
    final parsed = raw == null ? null : DateTime.tryParse(raw);
    if (parsed == null) {
      return '时间未记录';
    }
    final local = parsed.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  String? _formatDuration(dynamic raw) {
    final value = int.tryParse(raw?.toString() ?? '');
    if (value == null || value <= 0) {
      return null;
    }
    if (value < 1000) {
      return '${value}ms';
    }
    final seconds = value / 1000;
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(1)} 秒';
    }
    final minutes = seconds ~/ 60;
    final remain = (seconds % 60).toStringAsFixed(1);
    return '$minutes 分 $remain 秒';
  }

  bool _canRetryFailedGenerate(Map<String, dynamic> item) {
    return !_isSuccessful(item) && item['action']?.toString() == 'generate';
  }

  String _failureMessage(AppBrand brand, Map<String, dynamic> item) {
    final action = item['action']?.toString();
    if (action == 'edit') {
      return '${brand.editActionLabel}未能稳定收束，这次回溯只留下残响。当前回廊没有归档原始底图，暂不支持一键回溯。';
    }
    return '${brand.generateActionLabel}在成像前中断，${brand.historyTabLabel}已经记下这次尝试。稍后可以直接重新生成。';
  }

  List<PreviewImageEntry> _previewItems(
    List<Map<String, dynamic>> items,
    AppBrand brand,
  ) {
    return items
        .map(
          (item) => PreviewImageEntry(
            url: item['url']?.toString() ?? '',
            title: item['action'] == 'generate'
                ? brand.generateActionLabel
                : brand.editActionLabel,
            caption: item['prompt']?.toString(),
          ),
        )
        .where((entry) => entry.url.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _quotaSummaryFromResponse(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {
      'generate': {'remaining': 0, 'total': 0, 'used': 0},
      'edit': {'remaining': 0, 'total': 0, 'used': 0},
    };
  }
}
