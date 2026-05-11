import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/brand_background.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/compact_save_notice.dart';
import '../../core/image_capabilities.dart';
import '../../core/local_time_format.dart';
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
  static const _historyPageSizeOptions = [10, 20, 30, 50];
  static const _historyPageSizeStorageKey = 'history_page_size';
  static const _hiddenStorageKey = 'hidden_history_items';
  static const MethodChannel _shareChannel = MethodChannel('re0/downloads');

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final List<Map<String, dynamic>> _items = [];
  final Set<String> _hiddenKeys = {};
  final Set<String> _deletingKeys = {};
  final Set<String> _publishingKeys = {};
  final Set<String> _sharingKeys = {};
  final Set<String> _retryingKeys = {};
  Timer? _searchDebounce;
  int _page = 1;
  int _pageSize = 10;
  int _total = 0;
  int _totalPages = 1;
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
    final storedPageSize =
        ref.read(sharedPrefsProvider).getInt(_historyPageSizeStorageKey);
    if (storedPageSize != null &&
        _historyPageSizeOptions.contains(storedPageSize)) {
      _pageSize = storedPageSize;
    }
    _searchController.addListener(_onSearchChanged);
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CompendiumScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _resetFiltersAndReload();
    }
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _query) return;
    setState(() {
      _query = next;
      _page = 1;
    });
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
        _hasMore = true;
        _error = null;
      }
    });

    try {
      final response = await ref.read(gatewayClientProvider).getHistory(
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
      final totalPages =
          int.tryParse(response['total_pages']?.toString() ?? '') ?? _page;
      final total =
          int.tryParse(response['total']?.toString() ?? '') ?? nextItems.length;
      if (!mounted) return;
      setState(() {
        _items.clear();
        _items.addAll(nextItems);
        _total = total;
        _totalPages = totalPages < 1 ? 1 : totalPages;
        _hasMore = _page < _totalPages;
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

  Future<void> _goToPage(int page) async {
    final next = page.clamp(1, _totalPages).toInt();
    if (_isLoading || next == _page) return;
    _dismissKeyboard();
    setState(() {
      _page = next;
      _error = null;
    });
    await _load(reset: true);
    _scrollToTop();
  }

  Future<void> _refresh() async {
    await _load(reset: true);
  }

  Future<void> _setPageSize(int value) async {
    if (_pageSize == value || _isLoading) return;
    _dismissKeyboard();
    setState(() {
      _pageSize = value;
      _page = 1;
      _error = null;
    });
    await ref.read(sharedPrefsProvider).setInt(
          _historyPageSizeStorageKey,
          value,
        );
    await _load(reset: true);
    _scrollToTop();
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _resetFiltersAndReload() async {
    _dismissKeyboard();
    _searchDebounce?.cancel();
    setState(() {
      _query = '';
      _statusFilter = null;
      _actionFilter = null;
      _page = 1;
      _total = 0;
      _totalPages = 1;
      _hasMore = true;
      _error = null;
    });
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
    }
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
    setState(() {
      _statusFilter = value;
      _page = 1;
    });
    await _load(reset: true);
  }

  Future<void> _setActionFilter(String? value) async {
    if (_actionFilter == value) return;
    _dismissKeyboard();
    setState(() {
      _actionFilter = value;
      _page = 1;
    });
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
      await _refresh();
      if (!mounted) return;
      showCenterNotice(context, '图片记录已清理');
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
            final result =
                await ref.read(gatewayClientProvider).deleteHistoryItem(id);
            _updateRetentionIfPresent(
                result['history_retention_quota_summary']);
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
        _total = (_total - keys.length).clamp(0, _total).toInt();
        _totalPages = (_total + _pageSize - 1) ~/ _pageSize;
        if (_totalPages < 1) _totalPages = 1;
        if (_page > _totalPages) _page = _totalPages;
      });
      await ref
          .read(sharedPrefsProvider)
          .setStringList(_hiddenStorageKey, _hiddenKeys.toList());
    } catch (_) {
      setState(() => _deletingKeys.removeAll(keys));
      rethrow;
    }
  }

  Future<void> _deleteFailedItems(
      List<Map<String, dynamic>> failedItems) async {
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
      await _refresh();
      if (!mounted) return;
      showCenterNotice(context, '已清理 ${failedItems.length} 条失败记录');
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
      final prompt =
          item['revised_prompt']?.toString().trim().isNotEmpty == true
              ? item['revised_prompt'].toString().trim()
              : item['prompt']?.toString().trim() ?? '';
      if (prompt.isEmpty) {
        throw const GatewayException('这条失败记录没有可重试的提示词。');
      }
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty) {
        throw const GatewayException('这条失败记录缺少历史 ID，无法重试。');
      }
      final response =
          await ref.read(gatewayClientProvider).retryHistoryGenerate(id);
      ref.read(energyProvider.notifier).state =
          _quotaSummaryFromResponse(response['quota_summary']);
      _updateRetentionIfPresent(response['history_retention_quota_summary']);
      if (!mounted) return;
      final updatedItem = response['history_item'];
      if (updatedItem is Map) {
        final next = Map<String, dynamic>.from(updatedItem);
        setState(() {
          final index = _items.indexWhere((entry) => _historyKey(entry) == key);
          if (index >= 0) {
            _items[index] = next;
          }
        });
      } else {
        await _refresh();
      }
      final errors = (response['errors'] as List? ?? []).length;
      showCenterNotice(
        context,
        errors > 0 ? '已重新生成，另有 $errors 次未完成' : '已重新生成',
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

  Future<void> _copyPrompt(Map<String, dynamic> item) {
    final prompt = item['prompt']?.toString().trim() ?? '';
    return _copyPromptText(prompt);
  }

  Future<void> _copyPromptText(String prompt) async {
    if (prompt.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: prompt));
    if (!mounted) return;
    showCenterNotice(context, '提示词已复制');
  }

  Future<void> _showPromptDetails(Map<String, dynamic> item) async {
    final brand = ref.read(brandProvider);
    final prompt = item['prompt']?.toString().trim() ?? '';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.notes_outlined, color: brand.primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '提示词详情',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: '复制提示词',
                        onPressed: prompt.isEmpty
                            ? null
                            : () => _copyPromptText(prompt),
                        icon: const Icon(Icons.content_copy_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: brand.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: brand.primaryColor.withValues(alpha: 0.18),
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          prompt.isEmpty ? '未记录提示词' : prompt,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleGalleryPublish(Map<String, dynamic> item) async {
    final key = _historyKey(item);
    if (_publishingKeys.contains(key)) return;
    final historyId = item['id']?.toString();
    if (historyId == null || historyId.isEmpty) return;
    final postId = item['gallery_post_id']?.toString() ?? '';
    final isPublished = _isPublished(item);
    setState(() => _publishingKeys.add(key));
    try {
      Map<String, dynamic>? quotaSource;
      if (isPublished) {
        quotaSource = postId.isNotEmpty
            ? await ref.read(gatewayClientProvider).unpublishGalleryPost(postId)
            : await ref
                .read(gatewayClientProvider)
                .unpublishGalleryPostByHistory(historyId);
        if (mounted) {
          setState(() {
            item['is_published'] = false;
            item['gallery_post_id'] = null;
          });
        }
      } else {
        final post =
            await ref.read(gatewayClientProvider).publishGalleryPost(historyId);
        if (mounted) {
          setState(() {
            item['is_published'] = true;
            item['gallery_post_id'] = post['id'];
          });
        }
        quotaSource = post;
      }
      final retentionSummary = quotaSource['history_retention_quota_summary'];
      _updateRetentionIfPresent(retentionSummary);
      if (!mounted) return;
      showCenterNotice(
        context,
        isPublished ? '已取消发布' : '已发布到画廊，发布作品不占记忆保留上限',
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

  Future<void> _shareHistoryItem(Map<String, dynamic> item) async {
    final key = _historyKey(item);
    if (_sharingKeys.contains(key)) return;
    final historyId = item['id']?.toString();
    final imageUrl = item['url']?.toString();
    if ((historyId == null || historyId.isEmpty) &&
        (imageUrl == null || imageUrl.isEmpty)) {
      showCenterNotice(context, '这张图片暂时不能分享');
      return;
    }
    _dismissKeyboard();
    setState(() => _sharingKeys.add(key));
    try {
      final result = await ref.read(gatewayClientProvider).createImageShareLink(
            historyId: historyId,
            url: imageUrl,
          );
      final shareUrl =
          result['share_url']?.toString() ?? result['url']?.toString() ?? '';
      if (shareUrl.isEmpty) {
        throw const GatewayException('后端没有返回分享链接。');
      }
      await Clipboard.setData(ClipboardData(text: shareUrl));
      String? cachedImagePath;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        try {
          cachedImagePath =
              (await ref.read(imageCacheProvider).cachedFileFor(imageUrl)).path;
        } catch (_) {
          cachedImagePath = null;
        }
      }
      var openedShareSheet = false;
      if (cachedImagePath != null) {
        try {
          openedShareSheet = await _shareChannel.invokeMethod<bool>(
                'shareImage',
                {
                  'path': cachedImagePath,
                  'text': shareUrl,
                  'subject': '分享图片',
                },
              ) ??
              false;
        } on MissingPluginException {
          openedShareSheet = false;
        } on PlatformException {
          openedShareSheet = false;
        }
      }
      if (!openedShareSheet) {
        try {
          openedShareSheet = await _shareChannel.invokeMethod<bool>(
                'shareText',
                {
                  'text': shareUrl,
                  'subject': '分享图片链接',
                },
              ) ??
              false;
        } on MissingPluginException {
          openedShareSheet = false;
        } on PlatformException {
          openedShareSheet = false;
        }
      }
      if (!mounted) return;
      showCenterNotice(
        context,
        openedShareSheet ? '已复制链接，可选择应用分享图片' : '分享链接已复制',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '分享失败。'))),
      );
    } finally {
      if (mounted) {
        setState(() => _sharingKeys.remove(key));
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
                    child: Text(
                        _query.isEmpty ? brand.emptyHistoryText : '没有匹配的图片记录'),
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
                  child: _pageControls(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pageControls() {
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.normal,
        );
    final pageText = _total == 0 ? '第0/0页' : '第$_page/$_totalPages页';
    final totalText = '共$_total张';
    return Column(
      children: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  _pageButton(
                    icon: Icons.chevron_left,
                    label: '上一页',
                    filled: false,
                    onPressed: _isLoading || _page <= 1
                        ? null
                        : () => _goToPage(_page - 1),
                  ),
                  Text(pageText, style: textStyle),
                  Text(totalText, style: textStyle),
                  _pageButton(
                    icon: Icons.chevron_right,
                    label: '下一页',
                    filled: true,
                    onPressed: _isLoading || !_hasMore
                        ? null
                        : () => _goToPage(_page + 1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<int>(
              enabled: !_isLoading,
              tooltip: '调整每页数量',
              initialValue: _pageSize,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 72),
              position: PopupMenuPosition.under,
              onSelected: (value) => unawaited(_setPageSize(value)),
              itemBuilder: (context) => _historyPageSizeOptions
                  .map(
                    (value) => PopupMenuItem<int>(
                      value: value,
                      height: 34,
                      child: Text(
                        '$value张',
                        style: textStyle,
                      ),
                    ),
                  )
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('每页$_pageSize张', style: textStyle),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pageButton({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback? onPressed,
  }) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 2),
        Text(label),
      ],
    );
    final style = ButtonStyle(
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),
      textStyle: WidgetStateProperty.all(
        Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
      ),
      minimumSize: WidgetStateProperty.all(const Size(0, 28)),
    );
    if (filled) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: style,
      child: child,
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
    final isSharing = _sharingKeys.contains(key);
    final isRetrying = _retryingKeys.contains(key);
    final isSuccess = _isSuccessful(item);
    final isPublished = _isPublished(item);
    final action = item['action']?.toString() == 'edit' ? 'edit' : 'generate';
    final actionColor =
        action == 'edit' ? brand.warningColor : brand.primaryColor;
    final previewItems = _previewItems(_visibleItems, brand);
    final previewIndex =
        previewItems.indexWhere((entry) => entry.url == imageUrl);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
          if (imageUrl != null && imageUrl.isNotEmpty)
            _imageWithSourcePreview(
              brand: brand,
              imageUrl: imageUrl,
              sourceUrl: item['source_image_url']?.toString() ?? '',
              height: _historyImageHeight(),
              badge: _qualityModeLabel(item),
              onMainTap: () {
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
              onLongPress: _dismissKeyboard,
              caption: item['prompt']?.toString(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            isSuccess ? brand.successColor : brand.warningColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isSuccess ? '成功' : '失败',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _actionPill(
                              label: action == 'generate'
                                  ? brand.generateActionLabel
                                  : brand.editActionLabel,
                              color: actionColor,
                              icon: action == 'generate'
                                  ? Icons.auto_awesome_outlined
                                  : Icons.brush_outlined,
                            ),
                            if (isSuccess)
                              _metaActionButton(
                                brand: brand,
                                tooltip: isPublished ? '取消发布' : '发布到画廊',
                                icon: isPublished
                                    ? Icons.remove_circle_outline
                                    : Icons.publish_outlined,
                                label: isPublished ? '取消发布' : '发布',
                                color: isPublished
                                    ? brand.warningColor
                                    : brand.primaryColor,
                                filled: isPublished,
                                isBusy: isPublishing,
                                onPressed: () => _toggleGalleryPublish(item),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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
                      onPressed:
                          isDeleting ? null : () => _deleteHistoryItem(item),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _promptPanel(brand, item),
                const SizedBox(height: 8),
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
                    if (isSuccess)
                      _metaActionButton(
                        brand: brand,
                        tooltip: '图片分享',
                        icon: Icons.image_outlined,
                        label: '图片分享',
                        color: brand.primaryColor,
                        filled: false,
                        isBusy: isSharing,
                        onPressed: () => _shareHistoryItem(item),
                      ),
                  ],
                ),
                if (!isSuccess) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: brand.warningColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: brand.warningColor.withValues(alpha: 0.26),
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

  Widget _promptPanel(AppBrand brand, Map<String, dynamic> item) {
    final prompt = item['prompt']?.toString().trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: brand.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brand.primaryColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notes_outlined,
            size: 16,
            color: brand.primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: prompt.isEmpty ? null : () => _showPromptDetails(item),
                onLongPress:
                    prompt.isEmpty ? null : () => _copyPromptText(prompt),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    prompt.isEmpty ? '未记录提示词' : prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.28,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '复制提示词',
            constraints: const BoxConstraints.tightFor(
              width: 28,
              height: 28,
            ),
            padding: EdgeInsets.zero,
            onPressed: prompt.isEmpty ? null : () => _copyPromptText(prompt),
            icon: const Icon(Icons.content_copy_outlined, size: 16),
            color: brand.primaryColor,
          ),
        ],
      ),
    );
  }

  double _historyImageHeight() {
    final width = MediaQuery.sizeOf(context).width;
    return (width * 0.8).clamp(280.0, 420.0).toDouble();
  }

  Widget _metaPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
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

  Widget _metaActionButton({
    required AppBrand brand,
    required String tooltip,
    required IconData icon,
    required String label,
    required Color color,
    bool filled = false,
    required bool isBusy,
    required VoidCallback onPressed,
  }) {
    final foreground = filled ? Colors.white : color;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled
            ? color
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        shape: StadiumBorder(
          side: BorderSide(color: color.withValues(alpha: 0.62)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: isBusy ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isBusy)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 14,
                    color: foreground,
                  ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
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
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
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

  String _formatCreatedAt(String? raw) {
    return formatLocalTime(raw, fallback: '时间未记录');
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

  String _qualityLabel(Map<String, dynamic> item) {
    final explicit = item['quality_mode_label']?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final actualTier = _actualSizeTierLabel(item);
    if (actualTier != null) return actualTier;
    final size = item['size']?.toString().trim().toLowerCase();
    final sizeTier = _sizeTierLabel(size);
    if (sizeTier != null) return sizeTier;
    final quality = item['quality']?.toString().trim().toLowerCase();
    if (quality == '1k') return '1K';
    if (quality == '2k') return '2K';
    if (quality == '4k') return '4K';
    return 'Auto';
  }

  String? _actualSizeTierLabel(Map<String, dynamic> item) {
    final width = int.tryParse(item['actual_width']?.toString() ?? '') ?? 0;
    final height = int.tryParse(item['actual_height']?.toString() ?? '') ?? 0;
    final longest = width > height ? width : height;
    if (longest <= 0) return null;
    if (longest >= 3840) return '4K';
    if (longest >= 2048) return '2K';
    return '1K';
  }

  String _qualityModeLabel(Map<String, dynamic> item) {
    final tier = _qualityLabel(item);
    final mode = imageModeLabelFromItem(item);
    return '$tier·$mode';
  }

  String? _sizeTierLabel(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value == 'auto') return 'Auto';
    if (value == '1k') return '1K';
    if (value == '2k') return '2K';
    if (value == '4k') return '4K';
    final match = RegExp(r'^(\d+)[x*×](\d+)$').firstMatch(value);
    if (match == null) return null;
    final width = int.tryParse(match.group(1) ?? '') ?? 0;
    final height = int.tryParse(match.group(2) ?? '') ?? 0;
    final longest = width > height ? width : height;
    if (longest <= 0) return null;
    if (longest >= 3840) return '4K';
    if (longest >= 2048) return '2K';
    return '1K';
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

  Widget _imageWithSourcePreview({
    required AppBrand brand,
    required String imageUrl,
    required String sourceUrl,
    required double height,
    required VoidCallback onMainTap,
    required VoidCallback onLongPress,
    String? caption,
    String? badge,
  }) {
    final hasSource = sourceUrl.isNotEmpty && sourceUrl != imageUrl;
    return Stack(
      children: [
        GestureDetector(
          onLongPress: onLongPress,
          onTap: onMainTap,
          child: CachedGatewayImage(
            url: imageUrl,
            width: double.infinity,
            height: height,
            borderRadius: brand.historyImageRadius,
            fit: BoxFit.cover,
            accentColor: brand.primaryColor,
            cacheWidth: 720,
          ),
        ),
        if (hasSource)
          Positioned(
            left: 10,
            top: 10,
            child: _sourceThumb(
              brand: brand,
              sourceUrl: sourceUrl,
              caption: caption,
            ),
          ),
        if (badge != null && badge.trim().isNotEmpty)
          Positioned(
            left: 10,
            bottom: 10,
            child: _imageBadge(badge.trim()),
          ),
      ],
    );
  }

  Widget _imageBadge(String text) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sourceThumb({
    required AppBrand brand,
    required String sourceUrl,
    String? caption,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _dismissKeyboard();
          Navigator.of(context).push(
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
          );
        },
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
    );
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

  bool _isPublished(Map<String, dynamic> item) {
    final postId = item['gallery_post_id']?.toString().trim() ?? '';
    return item['is_published'] == true || postId.isNotEmpty;
  }

  void _updateRetentionIfPresent(dynamic value) {
    if (value is! Map) return;
    final summary = Map<String, dynamic>.from(value);
    final generate = summary['generate'];
    final edit = summary['edit'];
    if (generate is! Map || edit is! Map) return;
    final hasTotals =
        generate.containsKey('total') && edit.containsKey('total');
    if (!hasTotals) return;
    ref.read(historyRetentionProvider.notifier).state = summary;
  }
}
