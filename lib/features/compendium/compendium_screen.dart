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
      final response = await ref
          .read(gatewayClientProvider)
          .getHistory(_page, pageSize: _pageSize);
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final brand = ref.watch(brandProvider);

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
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _items[index];
                        return KeyedSubtree(
                          key: ValueKey(item['id'] ?? item['url'] ?? index),
                          child: _historyCard(brand, item),
                        );
                      },
                      childCount: _items.length,
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

  Widget _historyCard(AppBrand brand, Map<String, dynamic> item) {
    final imageUrl = item['url']?.toString();
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
                    Text(
                      item['action'] == 'generate'
                          ? brand.generateActionLabel
                          : brand.editActionLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      item['size']?.toString() ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
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
