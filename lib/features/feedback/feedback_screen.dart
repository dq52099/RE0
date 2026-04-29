import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/brand_background.dart';
import '../../core/compact_dropdown_field.dart';
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

  Future<void> _submitFeedback() async {
    final title = TextEditingController();
    final content = TextEditingController();
    var type = 'feedback';
    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('反馈与许愿'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: '类型'),
                      items: feedbackTypes
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(feedbackTypeLabel(item)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => type = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: title,
                      maxLength: 80,
                      decoration: const InputDecoration(labelText: '标题'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: content,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 1200,
                      decoration: const InputDecoration(
                        labelText: '内容',
                        hintText: '描述遇到的问题、建议，或想新增的功能、模型、主题、参数',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final nextTitle = title.text.trim();
                    final nextContent = content.text.trim();
                    if (nextTitle.isEmpty || nextContent.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请填写标题和内容。')),
                      );
                      return;
                    }
                    Navigator.pop(context, {
                      'type': type,
                      'title': nextTitle,
                      'content': nextContent,
                    });
                  },
                  child: const Text('提交'),
                ),
              ],
            );
          },
        );
      },
    );
    title.dispose();
    content.dispose();
    if (payload == null) return;

    try {
      await ref.read(gatewayClientProvider).createMyFeedback(
            type: payload['type']!,
            title: payload['title']!,
            content: payload['content']!,
          );
      if (!mounted) return;
      setState(() {
        _page = 1;
        _reload();
      });
      showCenterNotice(context, '已提交，管理员处理后会在这里显示状态和回复');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '提交反馈失败。'))),
      );
    }
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
                '${feedbackTypeLabel(item['type']?.toString())} · ${feedbackDate(item['created_at'])}',
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
        onPressed: _submitFeedback,
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('提交'),
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
                children: [
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
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: Text('还没有提交记录')),
                    )
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
    return Column(
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
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            return Row(
              children: [
                Expanded(
                  child: CompactDropdownField<String>(
                    label: '类型',
                    value: _type,
                    width: width,
                    menuWidth: width,
                    selectedLabels: const ['全部类型', '反馈', '许愿'],
                    items: [
                      CompactDropdownField.centeredItem<String>(
                        '',
                        '全部类型',
                        context,
                      ),
                      ...feedbackTypes.map(
                        (item) => CompactDropdownField.centeredItem<String>(
                          item,
                          feedbackTypeLabel(item),
                          context,
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _type = value;
                        _page = 1;
                        _reload();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CompactDropdownField<String>(
                    label: '状态',
                    value: _status,
                    width: width,
                    menuWidth: width,
                    selectedLabels: [
                      '全部状态',
                      ...feedbackStatuses.map(feedbackStatusLabel),
                    ],
                    items: [
                      CompactDropdownField.centeredItem<String>(
                        '',
                        '全部状态',
                        context,
                      ),
                      ...feedbackStatuses.map(
                        (item) => CompactDropdownField.centeredItem<String>(
                          item,
                          feedbackStatusLabel(item),
                          context,
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _status = value;
                        _page = 1;
                        _reload();
                      });
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

  Widget _feedbackCard(Map<String, dynamic> item) {
    final status = item['status']?.toString();
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
                  _metaPill(Icons.schedule_outlined,
                      feedbackDate(item['created_at'])),
                  if (feedbackText(item['admin_reply'] ?? item['reply'],
                          fallback: '')
                      .isNotEmpty)
                    _metaPill(Icons.mark_chat_read_outlined, '已回复'),
                ],
              ),
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
