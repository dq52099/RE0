import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/brand_background.dart';
import '../../core/compact_save_notice.dart';
import '../../core/providers.dart';
import 'feedback_utils.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  static const _pageSize = 30;

  final TextEditingController _keywordController = TextEditingController();
  Future<Map<String, dynamic>>? _future;
  String _type = '';
  String _status = '';
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  void _reload() {
    _future = ref.read(gatewayClientProvider).getMyFeedback(
          type: _type,
          status: _status,
          keyword: _keywordController.text,
          page: _page,
          pageSize: _pageSize,
        );
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  bool get _hasActiveFilters =>
      _type.isNotEmpty ||
      _status.isNotEmpty ||
      _keywordController.text.trim().isNotEmpty;

  Future<void> _openCompose({String initialType = 'feedback'}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _FeedbackComposeScreen(initialType: initialType),
      ),
    );
    if (created != true || !mounted) return;
    setState(() {
      _type = '';
      _status = '';
      _keywordController.clear();
      _page = 1;
      _reload();
    });
    showCenterNotice(context, '已提交，处理进度会在这里更新');
  }

  Future<void> _openDetail(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    Map<String, dynamic> detail = item;
    if (id.isNotEmpty) {
      try {
        detail = feedbackItem(
          await ref.read(gatewayClientProvider).getMyFeedbackDetail(id),
        );
      } catch (_) {
        detail = item;
      }
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.78,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                _detailHeader(detail),
                const SizedBox(height: 14),
                _section('内容', feedbackText(detail['content'])),
                if (feedbackText(detail['category'], fallback: '')
                    .isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _section(
                    '分类',
                    feedbackCategoryLabel(detail['category']?.toString()),
                  ),
                ],
                const SizedBox(height: 12),
                _section(
                  '管理员回复',
                  feedbackText(
                    detail['admin_reply'] ?? detail['reply'],
                    fallback: '管理员还没有回复',
                  ),
                ),
                if (feedbackText(detail['updated_at'], fallback: '')
                    .isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _section('更新时间', feedbackDate(detail['updated_at'])),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailHeader(Map<String, dynamic> item) {
    final status = item['status']?.toString();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.forum_outlined,
            color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feedbackText(item['title']),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '${feedbackTypeLabel(item['type']?.toString())} · ${feedbackCategoryLabel(item['category']?.toString())} · ${feedbackDate(item['created_at'])}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _statusPill(status),
      ],
    );
  }

  Widget _section(String title, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SelectableText(text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('反馈与许愿'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCompose(),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('提交反馈'),
      ),
      body: BrandBackground(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            final items = feedbackItems(snapshot.data);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _quickSubmitPanel(),
                  const SizedBox(height: 12),
                  _filters(),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState != ConnectionState.done)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (snapshot.hasError)
                    _errorState(snapshot.error)
                  else if (items.isEmpty)
                    _emptyState()
                  else
                    ...items.map(_feedbackCard),
                  if (items.isNotEmpty) _pager(snapshot.data ?? const {}),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _filters() {
    final activeFilterText = _hasActiveFilters ? '重置筛选' : '全部记录';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _keywordController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: '搜索',
            hintText: '标题或内容关键词',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _keywordController.text.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: '清空',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _keywordController.clear();
                      setState(() {
                        _page = 1;
                        _reload();
                      });
                    },
                  ),
          ),
          onSubmitted: (_) {
            setState(() {
              _page = 1;
              _reload();
            });
          },
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(
                activeFilterText,
                !_hasActiveFilters,
                () {
                  if (!_hasActiveFilters) return;
                  FocusManager.instance.primaryFocus?.unfocus();
                  setState(() {
                    _type = '';
                    _status = '';
                    _keywordController.clear();
                    _page = 1;
                    _reload();
                  });
                },
              ),
              const SizedBox(width: 8),
              ...feedbackTypes.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _filterChip(
                    feedbackTypeLabel(item),
                    _type == item,
                    () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() {
                        _type = _type == item ? '' : item;
                        _page = 1;
                        _reload();
                      });
                    },
                  ),
                ),
              ),
              ...feedbackStatuses.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _filterChip(
                    feedbackStatusLabel(item),
                    _status == item,
                    () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      setState(() {
                        _status = _status == item ? '' : item;
                        _page = 1;
                        _reload();
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quickSubmitPanel() {
    final brand = ref.watch(brandProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: brand.panelColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brand.primaryColor.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forum_outlined, color: brand.primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '告诉管理员你遇到的问题或想要的能力',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openCompose(initialType: 'feedback'),
                  icon: const Icon(Icons.feedback_outlined),
                  label: const Text('提交反馈'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openCompose(initialType: 'wish'),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('提交许愿'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  Widget _emptyState() {
    final message = _hasActiveFilters ? '没有匹配的提交记录' : '还没有提交记录';
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          const Icon(Icons.chat_bubble_outline, size: 42),
          const SizedBox(height: 12),
          Text(message),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openCompose(),
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('写一条反馈'),
          ),
        ],
      ),
    );
  }

  Widget _feedbackCard(Map<String, dynamic> item) {
    final status = item['status']?.toString();
    final reply = feedbackText(
      item['admin_reply'] ?? item['reply'],
      fallback: '',
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openDetail(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      feedbackText(item['title']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _statusPill(status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                feedbackText(item['content'], fallback: ''),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metaPill(Icons.category_outlined,
                      feedbackTypeLabel(item['type']?.toString())),
                  if (feedbackText(item['category'], fallback: '').isNotEmpty)
                    _metaPill(
                      Icons.sell_outlined,
                      feedbackCategoryLabel(item['category']?.toString()),
                    ),
                  _metaPill(Icons.schedule_outlined,
                      feedbackDate(item['created_at'])),
                  if (reply.isNotEmpty)
                    _metaPill(Icons.mark_chat_read_outlined, '已回复'),
                ],
              ),
              if (reply.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '管理员回复：$reply',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(String? status) {
    final color = feedbackStatusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        feedbackStatusLabel(status),
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _metaPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _pager(Map<String, dynamic> data) {
    final totalPages =
        int.tryParse(data['total_pages']?.toString() ?? '') ?? _page;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: _page <= 1
              ? null
              : () {
                  setState(() {
                    _page -= 1;
                    _reload();
                  });
                },
          child: const Text('上一页'),
        ),
        Text('$_page / $totalPages'),
        TextButton(
          onPressed: _page >= totalPages
              ? null
              : () {
                  setState(() {
                    _page += 1;
                    _reload();
                  });
                },
          child: const Text('下一页'),
        ),
      ],
    );
  }

  Widget _errorState(Object? error) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 42),
          const SizedBox(height: 12),
          Text(
            friendlyError(error ?? '加载失败', fallback: '反馈接口暂不可用。'),
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
}

class _FeedbackComposeScreen extends ConsumerStatefulWidget {
  const _FeedbackComposeScreen({
    required this.initialType,
  });

  final String initialType;

  @override
  ConsumerState<_FeedbackComposeScreen> createState() =>
      _FeedbackComposeScreenState();
}

class _FeedbackComposeScreenState
    extends ConsumerState<_FeedbackComposeScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _contentFocusNode = FocusNode();
  final GlobalKey _titleFieldKey = GlobalKey();
  final GlobalKey _contentFieldKey = GlobalKey();
  String _type = 'feedback';
  String _category = 'feature';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType == 'wish' ? 'wish' : 'feedback';
    _titleFocusNode.addListener(() => _ensureFieldVisible(_titleFieldKey));
    _contentFocusNode.addListener(() => _ensureFieldVisible(_contentFieldKey));
  }

  @override
  void dispose() {
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    _scrollController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _ensureFieldVisible(GlobalKey key) {
    if (!mounted) return;
    if (!(_titleFocusNode.hasFocus || _contentFocusNode.hasFocus)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 260));
      final context = key.currentContext;
      if (!mounted || context == null) return;
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        alignment: 0.72,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.length < 2) {
      showCenterNotice(context, '标题至少 2 个字');
      return;
    }
    if (content.length < 3) {
      showCenterNotice(context, '内容至少 3 个字');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(gatewayClientProvider).createMyFeedback(
            type: _type,
            category: _category,
            title: title,
            content: content,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      showCenterNotice(
        context,
        friendlyError(error, fallback: '提交失败，请稍后重试。'),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('提交反馈与许愿')),
      body: BrandBackground(
        child: SafeArea(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              _composeHeader(brand),
              const SizedBox(height: 14),
              _composePanel(
                brand,
                title: '类型',
                child: Row(
                  children: [
                    Expanded(
                      child: _typeCard(
                        brand,
                        type: 'feedback',
                        icon: Icons.feedback_outlined,
                        title: '反馈',
                        subtitle: '问题、建议、体验',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _typeCard(
                        brand,
                        type: 'wish',
                        icon: Icons.auto_awesome_outlined,
                        title: '许愿',
                        subtitle: '功能、模型、主题',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _composePanel(
                brand,
                title: '分类',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in feedbackCategories) _categoryChip(item),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _composePanel(
                brand,
                title: '内容',
                child: Column(
                  children: [
                    TextField(
                      key: _titleFieldKey,
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      maxLength: 80,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '标题',
                        hintText: '一句话说明重点',
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      key: _contentFieldKey,
                      controller: _contentController,
                      focusNode: _contentFocusNode,
                      minLines: 7,
                      maxLines: 12,
                      maxLength: 1200,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: '详细内容',
                        hintText: '写下现象、期望效果，或希望新增的能力',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 126),
                          child: Icon(Icons.notes_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_submitting ? '提交中' : '提交'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed:
                    _submitting ? null : () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composeHeader(AppBrand brand) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: brand.panelColor.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: brand.primaryColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.forum_outlined, color: brand.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _type == 'wish' ? '写下你希望新增的能力' : '写下你遇到的问题或建议',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _composePanel(
    AppBrand brand, {
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: brand.primaryColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _typeCard(
    AppBrand brand, {
    required String type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _type == type;
    return Material(
      color: selected
          ? brand.primaryColor.withValues(alpha: 0.14)
          : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          setState(() => _type = type);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? brand.primaryColor
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: selected ? brand.primaryColor : null),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: selected ? brand.primaryColor : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String category) {
    return ChoiceChip(
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      label: Text(feedbackCategoryLabel(category)),
      selected: _category == category,
      onSelected: (_) {
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => _category = category);
      },
    );
  }
}
