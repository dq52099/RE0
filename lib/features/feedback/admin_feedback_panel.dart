import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/compact_dropdown_field.dart';
import '../../core/compact_save_notice.dart';
import '../../core/providers.dart';
import 'feedback_utils.dart';

enum AdminFeedbackPanelMode { list, automation, insights }

class AdminFeedbackPanel extends ConsumerStatefulWidget {
  const AdminFeedbackPanel({
    super.key,
    this.mode = AdminFeedbackPanelMode.list,
    required this.canManage,
    required this.canReply,
    required this.canAi,
  });

  final AdminFeedbackPanelMode mode;
  final bool canManage;
  final bool canReply;
  final bool canAi;

  @override
  ConsumerState<AdminFeedbackPanel> createState() => _AdminFeedbackPanelState();
}

class _AdminFeedbackPanelState extends ConsumerState<AdminFeedbackPanel> {
  static const _pageSize = 30;

  final TextEditingController _keywordController = TextEditingController();
  Future<Map<String, dynamic>>? _future;
  Future<Map<String, dynamic>>? _automationFuture;
  Future<Map<String, dynamic>>? _insightsFuture;
  String _type = '';
  String _status = '';
  String _insightPeriod = 'day';
  DateTimeRange? _range;
  int _page = 1;
  final Set<String> _busyIds = {};
  bool _isSavingAutomation = false;
  bool _isExportingInsights = false;
  bool _isRunningAutomation = false;
  bool _isRunningAutoReply = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == AdminFeedbackPanelMode.list) {
      _reload();
    }
    if (widget.mode == AdminFeedbackPanelMode.automation) {
      _reloadAutomation();
      _reloadInsights();
    }
    if (widget.mode == AdminFeedbackPanelMode.insights) {
      _reloadInsights();
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  void _reload() {
    _future = ref.read(gatewayClientProvider).getAdminFeedback(
          type: _type,
          status: _status,
          keyword: _keywordController.text,
          startAt: _range?.start,
          endAt: _range == null
              ? null
              : DateTime(
                  _range!.end.year,
                  _range!.end.month,
                  _range!.end.day,
                  23,
                  59,
                  59,
                ),
          page: _page,
          pageSize: _pageSize,
        );
  }

  void _reloadAutomation() {
    if (!widget.canAi) return;
    _automationFuture =
        ref.read(gatewayClientProvider).getAdminFeedbackAutomation();
  }

  void _reloadInsights() {
    _insightsFuture = ref
        .read(gatewayClientProvider)
        .getAdminFeedbackInsights(_insightPeriod);
  }

  Future<void> _refresh() async {
    setState(() {
      if (widget.mode == AdminFeedbackPanelMode.list) {
        _reload();
      }
      if (widget.mode == AdminFeedbackPanelMode.automation) {
        _reloadAutomation();
        _reloadInsights();
      }
      if (widget.mode == AdminFeedbackPanelMode.insights) {
        _reloadInsights();
      }
    });
    await Future.wait([
      if (widget.mode == AdminFeedbackPanelMode.list && _future != null)
        _future!,
      if (widget.mode == AdminFeedbackPanelMode.automation &&
          _automationFuture != null)
        _automationFuture!,
      if (widget.mode == AdminFeedbackPanelMode.automation &&
          _insightsFuture != null)
        _insightsFuture!,
      if (widget.mode == AdminFeedbackPanelMode.insights &&
          _insightsFuture != null)
        _insightsFuture!,
    ]);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() {
      _range = picked;
      _page = 1;
      _reload();
    });
  }

  Future<Map<String, dynamic>> _detail(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return item;
    try {
      return feedbackItem(
        await ref.read(gatewayClientProvider).getAdminFeedbackDetail(id),
      );
    } catch (_) {
      return item;
    }
  }

  Future<void> _openDetail(Map<String, dynamic> item) async {
    final detail = await _detail(item);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.86,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                _detailHeader(detail),
                const SizedBox(height: 14),
                _contentBlock('用户诉求', feedbackText(detail['content'])),
                const SizedBox(height: 12),
                _aiBlock(detail),
                const SizedBox(height: 12),
                _contentBlock(
                  '管理员回复',
                  feedbackText(
                    detail['admin_reply'] ?? detail['reply'],
                    fallback: '尚未回复',
                  ),
                ),
                const SizedBox(height: 16),
                _detailActions(detail),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailHeader(Map<String, dynamic> item) {
    final user = feedbackText(
      item['user_display_name'],
      fallback: feedbackText(item['username'], fallback: '未知用户'),
    );
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
                '$user · ${feedbackTypeLabel(item['type']?.toString())} · ${feedbackCategoryLabel(item['category']?.toString())} · ${feedbackDate(item['created_at'])}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _statusPill(item['status']?.toString()),
      ],
    );
  }

  Widget _detailActions(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final busy = _busyIds.contains(id);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (widget.canReply)
          FilledButton.icon(
            onPressed: busy ? null : () => _reply(item),
            icon: const Icon(Icons.reply_outlined),
            label: const Text('回复'),
          ),
        if (widget.canAi)
          OutlinedButton.icon(
            onPressed: busy ? null : () => _summarize(item),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: const Text('AI 整理'),
          ),
        if (widget.canManage)
          ...feedbackStatuses.map(
            (status) => OutlinedButton(
              onPressed: busy || item['status']?.toString() == status
                  ? null
                  : () => _changeStatus(item, status),
              child: Text(feedbackStatusLabel(status)),
            ),
          ),
      ],
    );
  }

  Widget _contentBlock(String title, String text) {
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

  Widget _aiBlock(Map<String, dynamic> item) {
    final summary = aiField(item, ['summary', 'ai_summary', 'summary_text']);
    final priority = aiField(item, ['priority', 'ai_priority']);
    final suggested = aiField(
      item,
      ['suggested_status', 'ai_suggested_status', 'status_suggestion'],
    );
    final draft = aiField(item, ['reply_draft', 'ai_reply_draft']);
    final tags = [
      ...feedbackTags(item['ai_tags']),
      if (feedbackTags(item['tags']).isNotEmpty) ...feedbackTags(item['tags']),
      ...feedbackTags(aiField(item, ['tags', 'ai_tags'])),
    ].toSet().toList();
    final hasAi = summary.isNotEmpty ||
        priority.isNotEmpty ||
        suggested.isNotEmpty ||
        draft.isNotEmpty ||
        tags.isNotEmpty;
    if (!hasAi) {
      return _contentBlock('AI 整理', '尚未整理');
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI 整理', style: TextStyle(fontWeight: FontWeight.w700)),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            SelectableText(summary),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (priority.isNotEmpty)
                _metaPill(Icons.priority_high, '优先级 $priority'),
              if (suggested.isNotEmpty)
                _metaPill(
                  Icons.route_outlined,
                  '建议 ${feedbackStatusLabel(suggested)}',
                ),
              ...tags.map((tag) => _metaPill(Icons.sell_outlined, tag)),
            ],
          ),
          if (draft.isNotEmpty) ...[
            const SizedBox(height: 12),
            _contentBlock('回复草稿', draft),
          ],
        ],
      ),
    );
  }

  Future<void> _changeStatus(Map<String, dynamic> item, String status) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() => _busyIds.add(id));
    try {
      await ref
          .read(gatewayClientProvider)
          .updateAdminFeedbackStatus(id, status);
      if (!mounted) return;
      Navigator.of(context).maybePop();
      showCenterNotice(context, '状态已更新为 ${feedbackStatusLabel(status)}');
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      _showError(error, '更新反馈状态失败。');
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(id));
      }
    }
  }

  Future<void> _reply(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final controller = TextEditingController(
      text: feedbackText(
        item['admin_reply'] ?? item['reply'],
        fallback: aiField(item, ['reply_draft', 'ai_reply_draft']),
      ),
    );
    final reply = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('管理员回复'),
        content: TextField(
          controller: controller,
          minLines: 4,
          maxLines: 8,
          decoration: const InputDecoration(hintText: '写给用户的处理说明'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存回复'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reply == null) return;
    if (reply.isEmpty) {
      _showError('回复内容不能为空。', '回复内容不能为空。');
      return;
    }
    setState(() => _busyIds.add(id));
    try {
      await ref.read(gatewayClientProvider).replyAdminFeedback(id, reply);
      if (!mounted) return;
      Navigator.of(context).maybePop();
      showCenterNotice(context, '回复已保存');
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      _showError(error, '回复反馈失败。');
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(id));
      }
    }
  }

  Future<void> _summarize(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() => _busyIds.add(id));
    try {
      await ref.read(gatewayClientProvider).summarizeAdminFeedback(id);
      if (!mounted) return;
      Navigator.of(context).maybePop();
      showCenterNotice(context, 'AI 整理已完成');
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      _showError(error, 'AI 整理反馈失败。');
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(id));
      }
    }
  }

  Future<void> _saveAutomation(
    Map<String, dynamic> current, {
    bool? autoEnabled,
    String? automationLimit,
    int? intervalMinutes,
    bool? autoReplyEnabled,
    bool? autoExportEnabled,
  }) async {
    setState(() => _isSavingAutomation = true);
    try {
      await ref.read(gatewayClientProvider).saveAdminFeedbackAutomation(
            autoEnabled: autoEnabled ?? (current['auto_enabled'] == true),
            automationLimit: automationLimit ?? _automationLimitValue(current),
            intervalMinutes:
                intervalMinutes ?? _automationIntervalValue(current),
            autoReplyEnabled:
                autoReplyEnabled ?? (current['auto_reply_enabled'] == true),
            autoExportEnabled:
                autoExportEnabled ?? (current['auto_export_enabled'] == true),
          );
      if (!mounted) return;
      showCenterNotice(context, '反馈 AI 自动整理设置已保存');
      setState(_reloadAutomation);
    } catch (error) {
      if (!mounted) return;
      _showError(error, '保存反馈 AI 自动整理设置失败。');
    } finally {
      if (mounted) setState(() => _isSavingAutomation = false);
    }
  }

  Future<void> _runAutoReplyNow() async {
    setState(() => _isRunningAutoReply = true);
    try {
      final result =
          await ref.read(gatewayClientProvider).runAdminFeedbackAutoReply();
      if (!mounted) return;
      showCenterNotice(context, '已自动回复 ${result['replied'] ?? 0} 条');
      setState(() {
        _reload();
        _reloadInsights();
        _reloadAutomation();
      });
    } catch (error) {
      if (!mounted) return;
      _showError(error, '执行反馈 AI 自动回复失败。');
    } finally {
      if (mounted) setState(() => _isRunningAutoReply = false);
    }
  }

  Future<void> _runAutomationNow() async {
    setState(() => _isRunningAutomation = true);
    try {
      final result =
          await ref.read(gatewayClientProvider).runAdminFeedbackAutomation();
      if (!mounted) return;
      showCenterNotice(
        context,
        '已整理 ${result['summarized'] ?? 0} 条，回复 ${result['replied'] ?? 0} 条',
      );
      setState(() {
        _reload();
        _reloadInsights();
        _reloadAutomation();
      });
    } catch (error) {
      if (!mounted) return;
      _showError(error, '执行反馈 AI 自动整理失败。');
    } finally {
      if (mounted) setState(() => _isRunningAutomation = false);
    }
  }

  Future<void> _exportInsights() async {
    setState(() => _isExportingInsights = true);
    try {
      final result = await ref
          .read(gatewayClientProvider)
          .exportAdminFeedbackInsights(_insightPeriod);
      if (!mounted) return;
      showCenterNotice(context, '已导出：${feedbackText(result['file_path'])}');
      setState(() {
        _reloadAutomation();
        _reloadInsights();
      });
    } catch (error) {
      if (!mounted) return;
      _showError(error, '导出反馈需求清单失败。');
    } finally {
      if (mounted) setState(() => _isExportingInsights = false);
    }
  }

  String _automationLimitValue(Map<String, dynamic> data) {
    final value = feedbackText(data['automation_limit']).toLowerCase();
    return const {'5', '10', '15', 'all'}.contains(value) ? value : '5';
  }

  String _automationLimitLabel(String value) {
    if (value == 'all') return '所有';
    return '$value 条';
  }

  int _automationIntervalValue(Map<String, dynamic> data) {
    final raw = data['interval_minutes'];
    final parsed = raw is num ? raw.toInt() : int.tryParse(feedbackText(raw));
    if (parsed == null) return 5;
    return parsed.clamp(1, 1440).toInt();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == AdminFeedbackPanelMode.automation) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.canAi) ...[
              _automationPanel(),
              const SizedBox(height: 12),
              _insightsPanel(),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: Text('当前账号没有反馈 AI 权限')),
              ),
          ],
        ),
      );
    }
    if (widget.mode == AdminFeedbackPanelMode.insights) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [_insightsPanel()],
        ),
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snapshot) {
        final items = feedbackItems(snapshot.data);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
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
                  child: Center(child: Text('暂无用户反馈')),
                )
              else
                ...items.map(_feedbackCard),
              if (items.isNotEmpty) _pager(snapshot.data ?? const {}),
            ],
          ),
        );
      },
    );
  }

  Widget _automationPanel() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _automationFuture,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const <String, dynamic>{};
        return Card(
          margin: EdgeInsets.zero,
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.58),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_outlined,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '反馈 AI 自动整理',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (snapshot.connectionState != ConnectionState.done ||
                        _isSavingAutomation)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final fieldWidth = constraints.maxWidth >= 430
                        ? (constraints.maxWidth - 8) / 2
                        : constraints.maxWidth;
                    final interval = _automationIntervalValue(data);
                    final intervals =
                        <int>{1, 5, 10, 15, 30, 60, interval}.toList()..sort();
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        CompactDropdownField<String>(
                          label: '单次整理数量',
                          value: _automationLimitValue(data),
                          width: fieldWidth,
                          menuWidth: fieldWidth,
                          selectedLabels: const ['5 条', '10 条', '15 条', '所有'],
                          items: [
                            for (final value in const ['5', '10', '15', 'all'])
                              CompactDropdownField.centeredItem<String>(
                                value,
                                _automationLimitLabel(value),
                                context,
                              ),
                          ],
                          onChanged: snapshot.hasData && !_isSavingAutomation
                              ? (value) {
                                  if (value == null) return;
                                  _saveAutomation(data, automationLimit: value);
                                }
                              : (_) {},
                        ),
                        CompactDropdownField<int>(
                          label: '整理间隔',
                          value: interval,
                          width: fieldWidth,
                          menuWidth: fieldWidth,
                          selectedLabels: [
                            for (final value in intervals) '$value 分钟',
                          ],
                          items: [
                            for (final value in intervals)
                              CompactDropdownField.centeredItem<int>(
                                value,
                                '$value 分钟',
                                context,
                              ),
                          ],
                          onChanged: snapshot.hasData && !_isSavingAutomation
                              ? (value) {
                                  if (value == null) return;
                                  _saveAutomation(data, intervalMinutes: value);
                                }
                              : (_) {},
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      '自动整理新反馈，每次 ${_automationLimitLabel(_automationLimitValue(data))}'),
                  subtitle: Text('间隔 ${_automationIntervalValue(data)} 分钟'),
                  value: data['auto_enabled'] == true,
                  onChanged: snapshot.hasData && !_isSavingAutomation
                      ? (value) => _saveAutomation(data, autoEnabled: value)
                      : null,
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('自动回复已整理内容'),
                  value: data['auto_reply_enabled'] == true,
                  onChanged: snapshot.hasData && !_isSavingAutomation
                      ? (value) =>
                          _saveAutomation(data, autoReplyEnabled: value)
                      : null,
                ),
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('每日导出反馈清单'),
                  value: data['auto_export_enabled'] != false,
                  onChanged: snapshot.hasData && !_isSavingAutomation
                      ? (value) =>
                          _saveAutomation(data, autoExportEnabled: value)
                      : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _isRunningAutoReply ? null : _runAutoReplyNow,
                        icon: _isRunningAutoReply
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.reply_all_outlined),
                        label: const Text('立即回复'),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _isRunningAutomation ? null : _runAutomationNow,
                        icon: _isRunningAutomation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.play_arrow_outlined),
                        label: const Text('立即整理'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _insightsPanel() {
    return Card(
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.58),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.leaderboard_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '反馈需求清单',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.canAi && !_isExportingInsights
                      ? _exportInsights
                      : null,
                  icon: _isExportingInsights
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_download_outlined),
                  label: const Text('导出'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _periodChip('day', '最近一天'),
                _periodChip('week', '最近7天'),
                _periodChip('month', '最近一月'),
              ],
            ),
            const SizedBox(height: 10),
            FutureBuilder<Map<String, dynamic>>(
              future: _insightsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Text(
                    friendlyError(snapshot.error ?? '读取反馈需求清单失败。',
                        fallback: '读取反馈需求清单失败。'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  );
                }
                final data = snapshot.data ?? const <String, dynamic>{};
                final rankings = (data['rankings'] as List? ?? [])
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .take(5)
                    .toList();
                if (rankings.isEmpty) {
                  return const Text('当前周期暂无反馈。');
                }
                return Column(
                  children: rankings.map(_rankingTile).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(String value, String label) {
    return ChoiceChip(
      showCheckmark: false,
      label: Text(label),
      selected: _insightPeriod == value,
      onSelected: (_) {
        setState(() {
          _insightPeriod = value;
          _reloadInsights();
        });
      },
    );
  }

  Widget _rankingTile(Map<String, dynamic> item) {
    final tags = (item['tags'] as List? ?? [])
        .map((tag) => tag.toString())
        .where((tag) => tag.trim().isNotEmpty)
        .take(4)
        .toList();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${item['rank'] ?? '-'} ${feedbackText(item['title'])}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            feedbackText(item['summary'], fallback: ''),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _metaPill(Icons.repeat, '${item['count'] ?? 0} 次'),
              _metaPill(Icons.priority_high, '${item['priority'] ?? 'medium'}'),
              ...tags.map((tag) => _metaPill(Icons.sell_outlined, tag)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    final rangeText = _range == null
        ? '全部时间'
        : '${feedbackDate(_range!.start)} - ${feedbackDate(_range!.end)}';
    return Column(
      children: [
        TextField(
          controller: _keywordController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: '关键词',
            hintText: '标题、内容、用户',
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
                Expanded(child: _typeDropdown(width)),
                const SizedBox(width: 12),
                Expanded(child: _statusDropdown(width)),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  rangeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: '清空时间',
              onPressed: _range == null
                  ? null
                  : () {
                      setState(() {
                        _range = null;
                        _page = 1;
                        _reload();
                      });
                    },
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ],
    );
  }

  Widget _typeDropdown(double width) {
    return CompactDropdownField<String>(
      label: '类型',
      value: _type,
      width: width,
      menuWidth: width,
      selectedLabels: const ['全部类型', '反馈', '许愿'],
      items: [
        CompactDropdownField.centeredItem<String>('', '全部类型', context),
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
    );
  }

  Widget _statusDropdown(double width) {
    return CompactDropdownField<String>(
      label: '状态',
      value: _status,
      width: width,
      menuWidth: width,
      selectedLabels: [
        '全部状态',
        ...feedbackStatuses.map(feedbackStatusLabel),
      ],
      items: [
        CompactDropdownField.centeredItem<String>('', '全部状态', context),
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
    );
  }

  Widget _feedbackCard(Map<String, dynamic> item) {
    final status = item['status']?.toString();
    final user = feedbackText(
      item['user_display_name'],
      fallback: feedbackText(item['username'], fallback: '未知用户'),
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
                  _metaPill(Icons.person_outline, user),
                  _metaPill(Icons.category_outlined,
                      feedbackTypeLabel(item['type']?.toString())),
                  if (feedbackText(item['category'], fallback: '').isNotEmpty)
                    _metaPill(
                      Icons.sell_outlined,
                      feedbackCategoryLabel(item['category']?.toString()),
                    ),
                  _metaPill(Icons.schedule_outlined,
                      feedbackDate(item['created_at'])),
                  if (aiField(item, ['summary', 'ai_summary']).isNotEmpty)
                    _metaPill(Icons.auto_awesome_outlined, '已整理'),
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
            friendlyError(error ?? '加载失败', fallback: '用户反馈接口暂不可用。'),
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

  void _showError(Object error, String fallback) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(friendlyError(error, fallback: fallback))),
    );
  }
}
