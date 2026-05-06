import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/brand_background.dart';
import '../../core/compact_dropdown_field.dart';
import '../../core/compact_save_notice.dart';
import '../../core/local_time_format.dart';
import '../../core/providers.dart';
import '../feedback/admin_feedback_panel.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key, this.initialView});

  final String? initialView;

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  static const _defaultAiBaseUrl = 'https://2c2ch1u11-share-api-0.hf.space/v1';
  static const _feedbackAiModel = 'deepseek-v4-flash';
  static const _promptAiModel = 'gpt-5.4-mini';
  static const _generalProviderBaseUrl = 'http://10.0.1.70:18088/v1';
  static const _generalProviderModel = 'gpt-5.4-mini';
  static const _generalProviderImageModel = 'codex-gpt-image-2';
  static const _usersPageSize = 20;
  static const _invitesPageSize = 30;
  static const _backupRecordsPageSize = 5;
  static const _mailProviderLabels = {
    'claw163': '163 邮箱通道',
    'resend': 'Resend 备用通道',
    'smtp': 'SMTP 兼容通道',
    'none': '关闭',
  };
  static const _mailSlotLabels = {
    'primary': '主用线路',
    'backup': '备用线路',
  };
  static const _providerSlotLabels = {
    'primary': '主用线路',
    'backup': '备用线路',
  };

  int _revision = 0;
  int _usersPageIndex = 1;
  int _invitesPageIndex = 1;
  int _backupRecordsPageIndex = 1;
  String _inviteStatusFilter = '';
  bool _isProviderHealthChecking = false;
  bool _isRunningBackup = false;
  bool _isPublishingAnnouncement = false;
  bool _isGrantingWelfare = false;

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    final user = ref.watch(authStateProvider);
    final sections = _sectionsFor(user);
    if (sections.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('系统管理')),
        body: const BrandBackground(
          child: Center(child: Text('当前账号没有系统管理权限')),
        ),
      );
    }

    final initialIndex =
        sections.indexWhere((item) => item.key == widget.initialView);
    return DefaultTabController(
      key: ValueKey(sections.map((item) => item.key).join('|')),
      length: sections.length,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      child: Builder(
        builder: (tabContext) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('系统管理'),
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: sections.map((item) => Tab(text: item.label)).toList(),
              ),
            ),
            body: BrandBackground(
              child: TabBarView(
                children: sections
                    .map(
                      (item) => KeyedSubtree(
                        key: ValueKey('${item.key}-$_revision'),
                        child: _sectionBody(
                            tabContext, brand, item, user, sections),
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  List<_AdminSection> _sectionsFor(Map<String, dynamic>? user) {
    final permissions = _permissions(user);
    final isAdmin = _isAdmin(user);
    final menus = (user?['menus'] as List? ?? [])
        .whereType<Map>()
        .map((item) => item['key']?.toString())
        .whereType<String>()
        .toSet();
    final sections = <_AdminSection>[];
    if (isAdmin ||
        permissions.contains('settings.view') ||
        menus.contains('settings')) {
      sections.add(const _AdminSection('overview', '概览'));
    }
    if (isAdmin ||
        permissions.contains('user.view') ||
        menus.contains('users')) {
      sections.add(const _AdminSection('users', '用户'));
    }
    if (isAdmin ||
        permissions.contains('invite.view') ||
        menus.contains('invites')) {
      sections.add(const _AdminSection('invites', '邀请码'));
    }
    if (isAdmin ||
        permissions.contains('feedback.view') ||
        menus.contains('feedback')) {
      sections.add(const _AdminSection('feedback', '用户反馈'));
    }
    if (isAdmin ||
        permissions.contains('announcement.view') ||
        menus.contains('announcements')) {
      sections.add(const _AdminSection('announcements', '公告福利'));
    }
    if (isAdmin || permissions.contains('feedback.ai')) {
      sections.add(const _AdminSection('feedbackAi', '反馈 AI'));
    }
    if (isAdmin ||
        permissions.contains('settings.view') ||
        menus.contains('backups')) {
      sections.add(const _AdminSection('backups', '数据备份'));
    }
    if (isAdmin ||
        permissions.contains('settings.view') ||
        menus.contains('settings')) {
      sections.add(const _AdminSection('settings', '设置'));
    }
    if (isAdmin ||
        permissions.contains('group.view') ||
        menus.contains('groups')) {
      sections.add(const _AdminSection('groups', '用户组'));
    }
    if (isAdmin ||
        permissions.contains('role.view') ||
        menus.contains('roles')) {
      sections.add(const _AdminSection('roles', '角色'));
    }
    if (isAdmin ||
        permissions.contains('permission.view') ||
        menus.contains('permissions')) {
      sections.add(const _AdminSection('permissions', '权限'));
    }
    if (isAdmin ||
        permissions.contains('api_key.view') ||
        menus.contains('apiKeys')) {
      sections.add(const _AdminSection('apiKeys', '密钥'));
    }
    if (isAdmin ||
        permissions.contains('audit.view') ||
        menus.contains('audit')) {
      sections.add(const _AdminSection('audit', '审计'));
    }
    return sections;
  }

  Widget _sectionBody(
    BuildContext context,
    AppBrand brand,
    _AdminSection section,
    Map<String, dynamic>? user,
    List<_AdminSection> sections,
  ) {
    switch (section.key) {
      case 'overview':
        return _overviewPage(context, brand, sections);
      case 'users':
        return _usersPage(brand, canManage: _can(user, 'user.manage'));
      case 'invites':
        return _invitationCodesPage(brand,
            canManage: _can(user, 'invite.manage'));
      case 'groups':
        return _groupsPage(brand, canManage: _can(user, 'group.manage'));
      case 'roles':
        return _rolesPage(brand, canManage: _can(user, 'role.manage'));
      case 'permissions':
        return _permissionsPage(brand);
      case 'apiKeys':
        return _apiKeysPage(brand, canManage: _can(user, 'api_key.manage'));
      case 'feedback':
        return AdminFeedbackPanel(
          canManage: _can(user, 'feedback.manage'),
          canReply: _can(user, 'feedback.reply'),
          canAi: _can(user, 'feedback.ai'),
        );
      case 'feedbackAi':
        return AdminFeedbackPanel(
          mode: AdminFeedbackPanelMode.automation,
          canManage: _can(user, 'feedback.manage'),
          canReply: _can(user, 'feedback.reply'),
          canAi: _can(user, 'feedback.ai'),
        );
      case 'announcements':
        return _announcementsPage(
          brand,
          canManage: _can(user, 'announcement.manage'),
        );
      case 'backups':
        return _backupsPage(brand, canManage: _can(user, 'settings.manage'));
      case 'settings':
        return _settingsPage(brand, canManage: _can(user, 'settings.manage'));
      case 'audit':
        return _auditPage(brand);
      default:
        return const Center(child: Text('未知管理页'));
    }
  }

  Widget _overviewPage(
    BuildContext tabContext,
    AppBrand brand,
    List<_AdminSection> sections,
  ) {
    return _futureSection<Map<String, dynamic>>(
      future: ref.read(gatewayClientProvider).adminOverview(),
      builder: (overview) {
        final items = [
          _OverviewItem('用户', overview['user_count'], Icons.people_outline,
              'users', '查看用户账号与额度'),
          _OverviewItem('邀请码', overview['unused_invitation_count'],
              Icons.card_membership_outlined, 'invites', '未使用邀请码'),
          _OverviewItem(
              '用户反馈',
              overview['feedback_count'],
              Icons.forum_outlined,
              'feedback',
              '未关闭 ${overview['feedback_open_count'] ?? 0} 条'),
          _OverviewItem(
              '公告福利',
              overview['announcement_count'],
              Icons.campaign_outlined,
              'announcements',
              '福利 ${overview['welfare_grant_count'] ?? 0} 次'),
          _OverviewItem('用户组', overview['group_count'],
              Icons.group_work_outlined, 'groups', '管理默认额度'),
          _OverviewItem('角色', overview['role_count'],
              Icons.admin_panel_settings_outlined, 'roles', '管理权限组合'),
          _OverviewItem('数据备份', overview['local_backup_count'],
              Icons.backup_outlined, 'backups', '本地与 OpenList 备份'),
          _OverviewItem('可用密钥', overview['active_api_key_count'],
              Icons.key_outlined, 'apiKeys', '对外调用密钥'),
        ];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: items
              .map((item) => _overviewCard(tabContext, brand, sections, item))
              .toList(),
        );
      },
    );
  }

  Widget _overviewCard(
    BuildContext tabContext,
    AppBrand brand,
    List<_AdminSection> sections,
    _OverviewItem item,
  ) {
    final targetIndex =
        sections.indexWhere((section) => section.key == item.key);
    final enabled = targetIndex >= 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled
            ? () => DefaultTabController.of(tabContext).animateTo(targetIndex)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: brand.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: brand.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(item.subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                '${item.value ?? 0}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: brand.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 4),
              if (enabled) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _usersPage(AppBrand brand, {required bool canManage}) {
    return _futureSection<_UsersData>(
      future: _loadUsersData(),
      builder: (data) {
        final currentUserId = ref.read(authStateProvider)?['id']?.toString();
        final totalPages = _pageCount(data.users.length, _usersPageSize);
        final page = _clampedPage(_usersPageIndex, totalPages);
        final users = _pageItems(data.users, page, _usersPageSize);
        return _adminList(
          action: canManage
              ? FilledButton.icon(
                  onPressed: () => _editUser(null, data),
                  icon: const Icon(Icons.person_add),
                  label: const Text('新增用户'),
                )
              : null,
          children: [
            ...users.map((user) {
              final quota = _map(user['quota_summary']);
              final historyCaps = _map(user['history_retention_summary']);
              final historyQuota =
                  _map(user['history_retention_quota_summary']);
              final userId = user['id']?.toString() ?? '';
              final canDelete =
                  canManage && userId.isNotEmpty && userId != currentUserId;
              final generateQuota = _quotaBrief('生图', _map(quota['generate']));
              final editQuota = _quotaBrief('改图', _map(quota['edit']));
              final mode = _imageModeLabel(_text(
                user['effective_image_mode'],
                fallback: _text(user['image_mode'], fallback: 'vip'),
              ));
              final overrideMode = _imageModeOverrideLabel(
                _text(user['image_mode_override'], fallback: ''),
              );
              return _infoCard(
                title:
                    '${_text(user['display_name'])} (${_text(user['username'])})',
                subtitle:
                    '角色: ${_text(user['role_name'])}  用户组: ${_text(user['group_name'])}',
                active: user['is_active'] == true,
                trailing: canManage
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: '编辑用户',
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editUser(user, data),
                          ),
                          IconButton(
                            tooltip:
                                userId == currentUserId ? '不能删除当前登录账号' : '删除用户',
                            icon: const Icon(Icons.delete_outline),
                            color: Theme.of(context).colorScheme.error,
                            onPressed:
                                canDelete ? () => _deleteUser(user) : null,
                          ),
                        ],
                      )
                    : null,
                lines: [
                  '图片模式: $mode（$overrideMode）',
                  '$generateQuota · $editQuota',
                  '记忆保留额度: 生图 ${_historyQuotaBrief(historyQuota['generate'], historyCaps['generate'])} / 改图 ${_historyQuotaBrief(historyQuota['edit'], historyCaps['edit'])}',
                ],
                lineBreaks: false,
              );
            }),
            if (data.users.isNotEmpty)
              _listPager(
                page: page,
                totalPages: totalPages,
                totalItems: data.users.length,
                onPrevious: page <= 1
                    ? null
                    : () => setState(() => _usersPageIndex = page - 1),
                onNext: page >= totalPages
                    ? null
                    : () => setState(() => _usersPageIndex = page + 1),
              ),
          ],
        );
      },
    );
  }

  Widget _invitationCodesPage(AppBrand brand, {required bool canManage}) {
    return _futureSection<List<Map<String, dynamic>>>(
      future:
          _loadMapList(ref.read(gatewayClientProvider).adminInvitationCodes()),
      builder: (codes) {
        final filteredCodes = _inviteStatusFilter.isEmpty
            ? codes
            : codes
                .where((item) => _text(item['status']) == _inviteStatusFilter)
                .toList();
        final totalPages = _pageCount(filteredCodes.length, _invitesPageSize);
        final page = _clampedPage(_invitesPageIndex, totalPages);
        final visibleCodes = _pageItems(filteredCodes, page, _invitesPageSize);
        final unusedCodes = codes
            .where((item) => _text(item['status']) == 'unused')
            .map((item) => _text(item['code']))
            .where((code) => code != '-')
            .toList();
        return _adminList(
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (canManage)
                FilledButton.icon(
                  onPressed: _createInvitationCodes,
                  icon: const Icon(Icons.add_card),
                  label: const Text('生成邀请码'),
                ),
              SizedBox(
                width: 148,
                child: CompactDropdownField<String>(
                  label: '状态',
                  value: _inviteStatusFilter,
                  width: 148,
                  menuWidth: 148,
                  selectedLabels: const ['全部状态', '未使用', '已使用', '已停用'],
                  items: const [
                    DropdownMenuItem(value: '', child: Text('全部状态')),
                    DropdownMenuItem(value: 'unused', child: Text('未使用')),
                    DropdownMenuItem(value: 'used', child: Text('已使用')),
                    DropdownMenuItem(value: 'disabled', child: Text('已停用')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _inviteStatusFilter = value;
                      _invitesPageIndex = 1;
                    });
                  },
                ),
              ),
              OutlinedButton.icon(
                onPressed: unusedCodes.isEmpty
                    ? null
                    : () => _copyText(unusedCodes.join('\n'), '未使用邀请码已复制。'),
                icon: const Icon(Icons.copy_all),
                label: const Text('复制未使用'),
              ),
            ],
          ),
          children: [
            ...visibleCodes.map((item) {
              final status = _text(item['status']);
              final usedBy = _text(
                item['used_by_display_name'],
                fallback: _text(item['used_by_username'], fallback: ''),
              );
              return _infoCard(
                title: _text(item['code']),
                subtitle: status == 'unused'
                    ? '未使用，复制后发给新用户注册。'
                    : '已使用的邀请码会保留展示，便于追溯。',
                badge: _text(item['status_label']),
                trailing: IconButton(
                  tooltip: '复制邀请码',
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyText(_text(item['code']), '邀请码已复制。'),
                ),
                lines: [
                  '创建: ${formatLocalTime(item['created_at'])}',
                  '创建人: ${_text(item['created_by_display_name'], fallback: _text(item['created_by_username']))}',
                  if (status != 'unused')
                    '使用人: ${usedBy.isEmpty ? '-' : usedBy}',
                  if (status != 'unused')
                    '使用时间: ${formatLocalTime(item['used_at'])}',
                ],
              );
            }),
            if (filteredCodes.isNotEmpty)
              _listPager(
                page: page,
                totalPages: totalPages,
                totalItems: filteredCodes.length,
                onPrevious: page <= 1
                    ? null
                    : () => setState(() => _invitesPageIndex = page - 1),
                onNext: page >= totalPages
                    ? null
                    : () => setState(() => _invitesPageIndex = page + 1),
              ),
          ],
        );
      },
    );
  }

  Widget _groupsPage(AppBrand brand, {required bool canManage}) {
    return _futureSection<List<Map<String, dynamic>>>(
      future: _loadMapList(ref.read(gatewayClientProvider).adminGroups()),
      builder: (groups) {
        return _adminList(
          action: canManage
              ? FilledButton.icon(
                  onPressed: () => _editGroup(null),
                  icon: const Icon(Icons.group_add),
                  label: const Text('新增用户组'),
                )
              : null,
          children: groups.map((group) {
            return _infoCard(
              title: _text(group['name']),
              subtitle: _text(group['description']),
              active: group['is_active'] == true,
              trailing: canManage
                  ? IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editGroup(group),
                    )
                  : null,
              lines: [
                '默认生图模式: ${_imageModeLabel(_text(group['image_mode'], fallback: 'vip'))}',
                '默认生图额度: ${_text(group['default_generate_quota'])}',
                '默认改图额度: ${_text(group['default_edit_quota'])}',
                '默认生图保留额度: ${_text(group['default_generate_history_retention'])} 条',
                '默认改图保留额度: ${_text(group['default_edit_history_retention'])} 条',
                '成员数: ${_text(group['user_count'])}',
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _rolesPage(AppBrand brand, {required bool canManage}) {
    return _futureSection<_RolesData>(
      future: _loadRolesData(),
      builder: (data) {
        return _adminList(
          action: canManage
              ? FilledButton.icon(
                  onPressed: () => _editRole(null, data),
                  icon: const Icon(Icons.add_moderator),
                  label: const Text('新增角色'),
                )
              : null,
          children: data.roles.map((role) {
            final permissions = (role['permissions'] as List? ?? []).length;
            return _infoCard(
              title: _text(role['name']),
              subtitle: _text(role['description']),
              active: role['is_active'] == true,
              trailing: canManage
                  ? IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editRole(role, data),
                    )
                  : null,
              lines: [
                '权限数: $permissions',
                '用户数: ${_text(role['user_count'])}',
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _permissionsPage(AppBrand brand) {
    return _futureSection<List<Map<String, dynamic>>>(
      future: _loadMapList(ref.read(gatewayClientProvider).adminPermissions()),
      builder: (permissions) {
        return _adminList(
          children: permissions.map((permission) {
            return _infoCard(
              title: _text(permission['name']),
              subtitle: _text(permission['description']),
              badge: _text(permission['category']),
              lines: [_text(permission['code'])],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _apiKeysPage(AppBrand brand, {required bool canManage}) {
    return _futureSection<List<Map<String, dynamic>>>(
      future: _loadMapList(ref.read(gatewayClientProvider).adminApiKeys()),
      builder: (apiKeys) {
        return _adminList(
          action: canManage
              ? FilledButton.icon(
                  onPressed: () => _editApiKey(null),
                  icon: const Icon(Icons.key),
                  label: const Text('新增密钥'),
                )
              : null,
          children: apiKeys.map((item) {
            return _infoCard(
              title: _text(item['name']),
              subtitle: _text(item['description']),
              active: item['is_active'] == true,
              trailing: canManage
                  ? IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editApiKey(item),
                    )
                  : null,
              lines: [
                '密钥: ${_text(item['masked_key'])}',
                '最近使用: ${formatLocalTime(item['last_used_at'], fallback: '暂无')}',
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _settingsPage(AppBrand brand, {required bool canManage}) {
    return _futureSection<Map<String, dynamic>>(
      future: ref.read(gatewayClientProvider).adminSystemSettings(),
      builder: (data) {
        final settings = _settingsWithAiDefaults(_mapList(data['settings']));
        final runtime = _map(data['runtime_status']);
        final groups = _settingGroups(settings);
        return _adminList(
          action: canManage
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _editSettings(data),
                      icon: const Icon(Icons.save_as),
                      label: const Text('编辑设置'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _probeCapabilities,
                      icon: const Icon(Icons.radar),
                      label: const Text('探测尺寸'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isProviderHealthChecking
                          ? null
                          : _probeProviderHealth,
                      icon: const Icon(Icons.monitor_heart_outlined),
                      label:
                          Text(_isProviderHealthChecking ? '检测中...' : '线路检测'),
                    ),
                  ],
                )
              : null,
          children: [
            _infoCard(
              title: '运行状态',
              subtitle: '当前后端实际使用的配置',
              lines: runtime.entries
                  .map((item) => '${item.key}: ${_text(item.value)}')
                  .toList(),
            ),
            ...groups.entries.map(
              (entry) => _infoCard(
                title: entry.key,
                subtitle: '${entry.value.length} 项设置',
                badge: '分类',
                trailing: canManage
                    ? IconButton(
                        tooltip: '编辑${entry.key}',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () =>
                            _editSettings(data, category: entry.key),
                      )
                    : null,
                lines: entry.value
                    .take(6)
                    .map(
                      (setting) =>
                          '${_settingLabel(_text(setting['key']))}: ${_displaySettingValue(setting)}',
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _backupsPage(AppBrand brand, {required bool canManage}) {
    return _futureSection<_BackupsData>(
      future: _loadBackupsData(),
      builder: (data) {
        final byKey = {
          for (final item in _settingsWithAiDefaults(data.settings))
            _text(item['key']): item,
        };
        final runtime = data.runtime;
        final sortedBackups = [...data.backups]..sort(
            (a, b) => _backupCreatedAt(b).compareTo(_backupCreatedAt(a)),
          );
        final totalRecordPages =
            _pageCount(sortedBackups.length, _backupRecordsPageSize);
        final recordPage = _clampedPage(
          _backupRecordsPageIndex,
          totalRecordPages,
        );
        final visibleRecords = _pageItems(
          sortedBackups,
          recordPage,
          _backupRecordsPageSize,
        );
        return _adminList(
          action: canManage
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _editBackupSettings(data.settings),
                      icon: const Icon(Icons.tune),
                      label: const Text('备份设置'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isRunningBackup ? null : _runLocalBackup,
                      icon: const Icon(Icons.backup_outlined),
                      label: Text(_isRunningBackup ? '备份中...' : '立即备份'),
                    ),
                  ],
                )
              : null,
          children: [
            _infoCard(
              title: '本地备份',
              subtitle: '生成包含数据库和本地生成文件的备份包。',
              active: runtime['local_backup_enabled'] == true,
              lines: [
                '定时备份: ${_enabledLabel(runtime['local_backup_enabled'])}',
                '间隔: ${_backupIntervalLabel(_settingValue(byKey, 'local_backup_interval_minutes', fallback: '1440'))}',
                '保留: ${_settingValue(byKey, 'local_backup_retention_days', fallback: '14')} 天',
                '通知: ${_enabledLabel(runtime['backup_notification_enabled'])}',
              ],
            ),
            const SizedBox(height: 4),
            _settingsSectionTitle('备份上传通道'),
            const SizedBox(height: 8),
            _infoCard(
              title: 'Google Drive 备份',
              subtitle: '使用 Google 服务账号上传备份包。',
              active: runtime['google_drive_backup_enabled'] == true,
              lines: [
                '开关: ${_enabledLabel(runtime['google_drive_backup_enabled'])}',
                '配置: ${runtime['google_drive_backup_configured'] == true ? '已配置' : '未完整配置'}',
                '文件夹: ${_settingValue(byKey, 'google_drive_backup_folder_id')}',
              ],
            ),
            _infoCard(
              title: 'OpenList 主用备份',
              subtitle: '通过 WebDAV 上传，外网地址用于打开远端文件。',
              active: runtime['openlist_backup_primary_enabled'] == true,
              lines: [
                '开关: ${_enabledLabel(runtime['openlist_backup_primary_enabled'])}',
                '配置: ${runtime['openlist_backup_primary_configured'] == true ? '已配置' : '未完整配置'}',
                'WebDAV: ${_settingValue(byKey, 'openlist_backup_primary_webdav_url')}',
                '外网: ${_settingValue(byKey, 'openlist_backup_primary_public_url')}',
                '目录: ${_settingValue(byKey, 'openlist_backup_primary_path', fallback: '/gateway-backups')}',
              ],
            ),
            _infoCard(
              title: 'OpenList 备用备份',
              subtitle: '主备独立开关，备用未配置时不会上传。',
              active: runtime['openlist_backup_secondary_enabled'] == true,
              lines: [
                '开关: ${_enabledLabel(runtime['openlist_backup_secondary_enabled'])}',
                '配置: ${runtime['openlist_backup_secondary_configured'] == true ? '已配置' : '未完整配置'}',
                'WebDAV: ${_settingValue(byKey, 'openlist_backup_secondary_webdav_url')}',
                '外网: ${_settingValue(byKey, 'openlist_backup_secondary_public_url')}',
                '目录: ${_settingValue(byKey, 'openlist_backup_secondary_path', fallback: '/gateway-backups-secondary')}',
              ],
            ),
            const SizedBox(height: 8),
            _settingsSectionTitle('备份记录'),
            const SizedBox(height: 8),
            if (data.backups.isEmpty)
              _infoCard(
                title: '暂无备份记录',
                subtitle: '执行一次备份后会在这里显示最近记录。',
                lines: const [],
              )
            else ...[
              _infoCard(
                title: '记录分页',
                subtitle: '默认每页显示 5 条备份记录。',
                badge: '每页 5 条',
                lines: [
                  '当前页: $recordPage / $totalRecordPages',
                  '本页记录: ${visibleRecords.length} 条',
                  '全部记录: ${data.backups.length} 条',
                ],
              ),
              ...visibleRecords.map((item) {
                final target = _backupTargetLabel(_text(item['target']));
                final status = _text(item['status']);
                final url = _text(item['remote_file_url'], fallback: '');
                return _infoCard(
                  title: '$target备份${status == 'success' ? '完成' : '异常'}',
                  subtitle: _text(item['message']),
                  badge: _backupStatusLabel(status),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      if (url.isNotEmpty)
                        IconButton(
                          tooltip: '复制远端地址',
                          icon: const Icon(Icons.link),
                          onPressed: () => _copyText(url, '远端备份地址已复制。'),
                        ),
                      if (canManage &&
                          _text(item['target']) == 'local' &&
                          status == 'success')
                        IconButton(
                          tooltip: '恢复此备份',
                          icon: const Icon(Icons.restore),
                          onPressed: () => _restoreLocalBackup(item),
                        ),
                    ],
                  ),
                  lines: [
                    '时间: ${formatLocalTime(item['created_at'])}',
                    '大小: ${_formatBytes(item['size_bytes'])}',
                    if (url.isNotEmpty) '远端: $url',
                    if (url.isEmpty) '文件: ${_text(item['file_path'])}',
                  ],
                );
              }),
              _listPager(
                page: recordPage,
                totalPages: totalRecordPages,
                totalItems: data.backups.length,
                onPrevious: recordPage > 1
                    ? () => setState(
                          () => _backupRecordsPageIndex = recordPage - 1,
                        )
                    : null,
                onNext: recordPage < totalRecordPages
                    ? () => setState(
                          () => _backupRecordsPageIndex = recordPage + 1,
                        )
                    : null,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _announcementsPage(AppBrand brand, {required bool canManage}) {
    return _futureSection<Map<String, dynamic>>(
      future: ref.read(gatewayClientProvider).adminAnnouncements(),
      builder: (data) {
        final announcements = _mapList(data['announcements']);
        final grants = _mapList(data['welfare_grants']);
        return _adminList(
          action: canManage
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _isPublishingAnnouncement
                          ? null
                          : _publishAnnouncement,
                      icon: const Icon(Icons.campaign_outlined),
                      label:
                          Text(_isPublishingAnnouncement ? '发布中...' : '发布公告'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isGrantingWelfare ? null : _grantWelfare,
                      icon: const Icon(Icons.card_giftcard_outlined),
                      label: Text(_isGrantingWelfare ? '发放中...' : '发放福利'),
                    ),
                  ],
                )
              : null,
          children: [
            _infoCard(
              title: '展示位置',
              subtitle: '公告会进入每个用户的通知中心；未读通知会在“我的”页显示红点。',
              lines: const ['系统公告', '全员通知', '福利到账'],
            ),
            ...announcements.map(
              (item) {
                final active = item['is_published'] != false;
                return _infoCard(
                  title: _text(item['title']),
                  subtitle: _text(item['body']),
                  badge: active ? '公告' : '已下线',
                  active: active,
                  trailing: canManage
                      ? Wrap(
                          spacing: 2,
                          children: [
                            IconButton(
                              tooltip: '编辑公告',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _editAnnouncement(item),
                            ),
                            IconButton(
                              tooltip: '删除公告',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: active
                                  ? () => _deleteAnnouncement(item)
                                  : null,
                            ),
                          ],
                        )
                      : null,
                  lines: [
                    '发布者: ${_text(item['created_by_display_name'], fallback: _text(item['created_by_username']))}',
                    '时间: ${formatLocalTime(_text(item['created_at']))}',
                    if (_text(item['updated_at']).isNotEmpty)
                      '更新: ${formatLocalTime(_text(item['updated_at']))}',
                  ],
                );
              },
            ),
            ...grants.map(
              (item) => _infoCard(
                title: _text(item['title']),
                subtitle: _text(item['body'], fallback: '全员额度福利'),
                badge: '福利',
                lines: [
                  '生图 +${_text(item['generate_bonus'], fallback: '0')}',
                  '改图 +${_text(item['edit_bonus'], fallback: '0')}',
                  '人数: ${_text(item['recipient_count'], fallback: '0')}',
                  '时间: ${formatLocalTime(_text(item['created_at']))}',
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _auditPage(AppBrand brand) {
    return _futureSection<List<Map<String, dynamic>>>(
      future: _loadMapList(ref.read(gatewayClientProvider).adminAuditLogs()),
      builder: (logs) {
        return _adminList(
          children: logs.map((log) {
            return _infoCard(
              title: _text(log['action']),
              subtitle:
                  '${_text(log['actor_username'], fallback: '系统')}  ${formatLocalTime(log['created_at'])}',
              lines: [
                '资源: ${_text(log['resource_type'])} ${_text(log['resource_id'])}',
                if (log['detail'] != null) '详情: ${_text(log['detail'])}',
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Future<_BackupsData> _loadBackupsData() async {
    final client = ref.read(gatewayClientProvider);
    final values = await Future.wait([
      client.adminSystemSettings(),
      client.adminLocalBackups(),
    ]);
    final settingsData = values[0];
    final backupData = values[1];
    return _BackupsData(
      _mapList(settingsData['settings']),
      _map(settingsData['runtime_status']),
      _mapList(backupData['items']),
    );
  }

  Future<_UsersData> _loadUsersData() async {
    final client = ref.read(gatewayClientProvider);
    final values = await Future.wait([
      _loadMapList(client.adminUsers()),
      _loadMapList(client.adminGroups()),
      _loadMapList(client.adminRoles()),
    ]);
    return _UsersData(values[0], values[1], values[2]);
  }

  Future<_RolesData> _loadRolesData() async {
    final client = ref.read(gatewayClientProvider);
    final values = await Future.wait([
      _loadMapList(client.adminRoles()),
      _loadMapList(client.adminPermissions()),
    ]);
    return _RolesData(values[0], values[1]);
  }

  Future<List<Map<String, dynamic>>> _loadMapList(
      Future<List<dynamic>> future) async {
    final items = await future;
    return _mapList(items);
  }

  Widget _futureSection<T>({
    required Future<T> future,
    required Widget Function(T data) builder,
  }) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorState(snapshot.error);
        }
        return builder(snapshot.data as T);
      },
    );
  }

  Widget _adminList({required List<Widget> children, Widget? action}) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (action != null) ...[
            Align(alignment: Alignment.centerLeft, child: action),
            const SizedBox(height: 12),
          ],
          if (children.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: Text('暂无数据')),
            )
          else
            ...children,
        ],
      ),
    );
  }

  int _pageCount(int totalItems, int pageSize) {
    if (totalItems <= 0) return 1;
    return ((totalItems - 1) ~/ pageSize) + 1;
  }

  int _clampedPage(int page, int totalPages) {
    if (page < 1) return 1;
    if (page > totalPages) return totalPages;
    return page;
  }

  List<Map<String, dynamic>> _pageItems(
    List<Map<String, dynamic>> items,
    int page,
    int pageSize,
  ) {
    if (items.isEmpty) return const [];
    final start = (page - 1) * pageSize;
    if (start >= items.length) return const [];
    final end =
        (start + pageSize) > items.length ? items.length : start + pageSize;
    return items.sublist(start, end);
  }

  Widget _listPager({
    required int page,
    required int totalPages,
    required int totalItems,
    required VoidCallback? onPrevious,
    required VoidCallback? onNext,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(onPressed: onPrevious, child: const Text('上一页')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$page / $totalPages，共 $totalItems 条',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onNext, child: const Text('下一页')),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    String? subtitle,
    List<String> lines = const [],
    bool? active,
    String? badge,
    Widget? trailing,
    bool lineBreaks = true,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (badge != null) _pill(badge),
                if (active != null) _pill(active ? '启用' : '停用'),
                if (trailing != null) trailing,
              ],
            ),
            if (subtitle != null && subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (lines.isNotEmpty) ...[
              const SizedBox(height: 10),
              if (!lineBreaks)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: lines
                      .where((item) => item.trim().isNotEmpty)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _lineChip(item),
                        ),
                      )
                      .toList(),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: lines
                      .where((item) => item.trim().isNotEmpty)
                      .map((item) => _lineChip(item))
                      .toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lineChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.visible,
        softWrap: false,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ref.read(brandProvider).primaryColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _errorState(Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            Text(
              friendlyError(error ?? '加载失败'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _adminDialog({
    required String title,
    required IconData icon,
    required Widget content,
    required List<Widget> actions,
  }) {
    final brand = ref.read(brandProvider);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: brand.primaryColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: brand.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: content,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: actions,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editUser(Map<String, dynamic>? user, _UsersData data) async {
    final username =
        TextEditingController(text: _text(user?['username'], fallback: ''));
    final displayName =
        TextEditingController(text: _text(user?['display_name'], fallback: ''));
    final password = TextEditingController();
    final generateQuota = TextEditingController(
      text: user?['generate_quota_total_override']?.toString() ?? '',
    );
    final editQuota = TextEditingController(
      text: user?['edit_quota_total_override']?.toString() ?? '',
    );
    final generateHistoryRetention = TextEditingController(
      text: user?['generate_history_retention_override']?.toString() ?? '',
    );
    final editHistoryRetention = TextEditingController(
      text: user?['edit_history_retention_override']?.toString() ?? '',
    );
    var roleId = _text(
      user?['role_id'],
      fallback: data.roles.isEmpty ? '' : _text(data.roles.first['id']),
    );
    var groupId = _text(
      user?['group_id'],
      fallback: data.groups.isEmpty ? '' : _text(data.groups.first['id']),
    );
    var imageModeOverride = _text(user?['image_mode_override'], fallback: '');
    if (!const ['', 'vip', 'general'].contains(imageModeOverride)) {
      imageModeOverride = '';
    }
    var active = user?['is_active'] != false;
    var canEditUsername = user?['can_edit_username'] != false;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return _adminDialog(
            title: user == null ? '新增用户' : '编辑用户',
            icon: user == null ? Icons.person_add : Icons.manage_accounts,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: username,
                    decoration: const InputDecoration(labelText: '用户名')),
                const SizedBox(height: 12),
                TextField(
                    controller: displayName,
                    decoration: const InputDecoration(labelText: '显示名称')),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(
                      labelText: user == null ? '初始密码' : '密码留空不修改'),
                ),
                const SizedBox(height: 12),
                _dropdown(
                  label: '角色',
                  value: roleId,
                  items: data.roles,
                  onChanged: (value) => setDialogState(() => roleId = value),
                ),
                const SizedBox(height: 12),
                _dropdown(
                  label: '用户组',
                  value: groupId,
                  items: data.groups,
                  onChanged: (value) => setDialogState(() => groupId = value),
                ),
                const SizedBox(height: 12),
                _stringDropdown(
                  '生图模式',
                  imageModeOverride,
                  const ['', 'vip', 'general'],
                  (value) => setDialogState(() => imageModeOverride = value),
                  labels: const {
                    '': '跟随用户组',
                    'vip': 'VIP模式',
                    'general': '一般模式',
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: generateQuota,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '个人生图额度',
                    helperText: '留空则跟随用户组默认额度',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: editQuota,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '个人改图额度',
                    helperText: '留空则跟随用户组默认额度',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: generateHistoryRetention,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '个人生图保留额度',
                    helperText: '留空则跟随用户组和等级福利；达到上限后需先手动清理记忆回廊',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: editHistoryRetention,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '个人改图保留额度',
                    helperText: '留空则跟随用户组和等级福利；达到上限后需先手动清理记忆回廊',
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: active,
                  onChanged: (value) =>
                      setDialogState(() => active = value ?? true),
                  title: const Text('启用账号'),
                ),
                CheckboxListTile(
                  value: canEditUsername,
                  onChanged: (value) =>
                      setDialogState(() => canEditUsername = value ?? true),
                  title: const Text('允许修改用户名'),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消')),
              FilledButton(
                onPressed: () {
                  final body = {
                    'username': username.text.trim(),
                    'display_name': displayName.text.trim(),
                    'role_id': roleId,
                    'group_id': groupId,
                    'image_mode_override':
                        imageModeOverride.isEmpty ? null : imageModeOverride,
                    'is_active': active,
                    'can_edit_username': canEditUsername,
                    'generate_quota_total_override':
                        _nullableInt(generateQuota.text),
                    'edit_quota_total_override': _nullableInt(editQuota.text),
                    'generate_history_retention_override':
                        _nullableInt(generateHistoryRetention.text),
                    'edit_history_retention_override':
                        _nullableInt(editHistoryRetention.text),
                  };
                  if (user == null) {
                    body['password'] = password.text;
                  }
                  Navigator.pop(context, body);
                },
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    if (payload == null) return;
    await _save(
        () => ref
            .read(gatewayClientProvider)
            .saveAdminUser(user?['id']?.toString(), payload),
        '用户已保存。');
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final userId = user['id']?.toString() ?? '';
    if (userId.isEmpty) return;
    final displayName = _text(
      user['display_name'],
      fallback: _text(user['username'], fallback: '该用户'),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除用户'),
        content: Text('确定删除 $displayName 吗？删除后该账号会被停用，不能再登录。'),
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
      await ref.read(gatewayClientProvider).deleteAdminUser(userId);
      if (!mounted) return;
      _showMessage('用户已删除，列表已刷新。');
      setState(() {
        _usersPageIndex = 1;
        _revision += 1;
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage(friendlyError(error, fallback: '删除用户失败。'), isError: true);
    }
  }

  Future<void> _editGroup(Map<String, dynamic>? group) async {
    final name =
        TextEditingController(text: _text(group?['name'], fallback: ''));
    final description =
        TextEditingController(text: _text(group?['description'], fallback: ''));
    final generateQuota = TextEditingController(
        text: _text(group?['default_generate_quota'], fallback: '10'));
    final editQuota = TextEditingController(
        text: _text(group?['default_edit_quota'], fallback: '5'));
    final generateHistoryRetention = TextEditingController(
      text: _text(group?['default_generate_history_retention'], fallback: '20'),
    );
    final editHistoryRetention = TextEditingController(
      text: _text(group?['default_edit_history_retention'], fallback: '12'),
    );
    var imageMode = _text(group?['image_mode'], fallback: 'vip');
    if (!const ['vip', 'general'].contains(imageMode)) {
      imageMode = 'vip';
    }
    var active = group?['is_active'] != false;
    final payload = await _basicEntityDialog(
      title: group == null ? '新增用户组' : '编辑用户组',
      name: name,
      description: description,
      extraFields: [
        TextField(
          controller: generateQuota,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '默认生图额度'),
        ),
        TextField(
          controller: editQuota,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '默认改图额度'),
        ),
        TextField(
          controller: generateHistoryRetention,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '默认生图保留额度',
            helperText: '组内用户基础保留额度；等级福利会额外增加',
          ),
        ),
        TextField(
          controller: editHistoryRetention,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '默认改图保留额度',
            helperText: '组内用户基础保留额度；等级福利会额外增加',
          ),
        ),
        _stringDropdown(
          '默认生图模式',
          imageMode,
          const ['vip', 'general'],
          (value) => imageMode = value,
          labels: const {
            'vip': 'VIP模式',
            'general': '一般模式',
          },
        ),
      ],
      active: active,
      onActiveChanged: (value) => active = value,
      payloadBuilder: () => {
        'name': name.text.trim(),
        'description': description.text.trim(),
        'default_generate_quota': int.tryParse(generateQuota.text) ?? 0,
        'default_edit_quota': int.tryParse(editQuota.text) ?? 0,
        'default_generate_history_retention':
            int.tryParse(generateHistoryRetention.text) ?? 0,
        'default_edit_history_retention':
            int.tryParse(editHistoryRetention.text) ?? 0,
        'image_mode': imageMode,
        'is_active': active,
      },
    );
    if (payload == null) return;
    await _save(
        () => ref
            .read(gatewayClientProvider)
            .saveAdminGroup(group?['id']?.toString(), payload),
        '用户组已保存。');
  }

  Future<void> _editRole(Map<String, dynamic>? role, _RolesData data) async {
    final name =
        TextEditingController(text: _text(role?['name'], fallback: ''));
    final description =
        TextEditingController(text: _text(role?['description'], fallback: ''));
    final selected = (role?['permissions'] as List? ?? [])
        .map((item) => item.toString())
        .toSet();
    var active = role?['is_active'] != false;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return _adminDialog(
            title: role == null ? '新增角色' : '编辑角色',
            icon: Icons.admin_panel_settings,
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: '名称')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: description,
                      decoration: const InputDecoration(labelText: '描述')),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: active,
                    onChanged: (value) =>
                        setDialogState(() => active = value ?? true),
                    title: const Text('启用角色'),
                  ),
                  const Divider(),
                  ...data.permissions.map((permission) {
                    final code = _text(permission['code']);
                    return CheckboxListTile(
                      dense: true,
                      value: selected.contains(code),
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            selected.add(code);
                          } else {
                            selected.remove(code);
                          }
                        });
                      },
                      title: Text(_text(permission['name'])),
                      subtitle: Text(code),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消')),
              FilledButton(
                onPressed: () => Navigator.pop(context, {
                  'name': name.text.trim(),
                  'description': description.text.trim(),
                  'permission_codes': selected.toList(),
                  'is_active': active,
                }),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    if (payload == null) return;
    await _save(
        () => ref
            .read(gatewayClientProvider)
            .saveAdminRole(role?['id']?.toString(), payload),
        '角色已保存。');
  }

  Future<void> _editApiKey(Map<String, dynamic>? item) async {
    final name =
        TextEditingController(text: _text(item?['name'], fallback: ''));
    final description =
        TextEditingController(text: _text(item?['description'], fallback: ''));
    final rawKey = TextEditingController();
    var active = item?['is_active'] != false;
    final payload = await _basicEntityDialog(
      title: item == null ? '新增密钥' : '编辑密钥',
      name: name,
      description: description,
      extraFields: [
        TextField(
          controller: rawKey,
          decoration:
              InputDecoration(labelText: item == null ? '密钥值' : '新密钥，留空不轮换'),
        ),
      ],
      active: active,
      onActiveChanged: (value) => active = value,
      payloadBuilder: () => {
        'name': name.text.trim(),
        'description': description.text.trim(),
        'is_active': active,
        if (item == null) 'raw_key': rawKey.text.trim(),
        if (item != null && rawKey.text.trim().isNotEmpty)
          '_rotate_to': rawKey.text.trim(),
      },
    );
    if (payload == null) return;
    final rotateTo = payload.remove('_rotate_to')?.toString();
    await _save(() async {
      await ref
          .read(gatewayClientProvider)
          .saveAdminApiKey(item?['id']?.toString(), payload);
      if (item != null && rotateTo != null && rotateTo.isNotEmpty) {
        final result = await ref
            .read(gatewayClientProvider)
            .rotateAdminApiKey(_text(item['id']), rotateTo);
        if (mounted) _showMessage('密钥已轮换，请立即保存: ${_text(result['raw_key'])}');
      }
    }, '密钥已保存。');
  }

  Future<void> _editSettings(
    Map<String, dynamic> data, {
    String? category,
  }) async {
    final byKey = {
      for (final item in _settingsWithAiDefaults(_mapList(data['settings'])))
        _text(item['key']): item,
    };
    final uiTitle =
        TextEditingController(text: _settingValue(byKey, 'ui_title'));
    final externalBase = TextEditingController(
        text: _settingValue(byKey, 'external_access_base_url'));
    final providerBase =
        TextEditingController(text: _settingValue(byKey, 'provider_base_url'));
    final providerKey = TextEditingController();
    final providerSecondaryKey = TextEditingController();
    final providerBackupBase = TextEditingController(
        text: _settingValue(byKey, 'provider_backup_base_url'));
    final providerBackupKey = TextEditingController();
    final providerBackupSecondaryKey = TextEditingController();
    final providerModel =
        TextEditingController(text: _settingValue(byKey, 'provider_model'));
    final generalProviderBase = TextEditingController(
      text: _settingValue(
        byKey,
        'general_provider_base_url',
        fallback: _generalProviderBaseUrl,
      ),
    );
    final generalProviderKey = TextEditingController();
    final generalProviderModel = TextEditingController(
      text: _settingValue(
        byKey,
        'general_provider_model',
        fallback: _generalProviderModel,
      ),
    );
    final generalProviderImageModel = TextEditingController(
      text: _settingValue(
        byKey,
        'general_provider_image_model',
        fallback: _generalProviderImageModel,
      ),
    );
    final providerTimeout = TextEditingController(
        text: _settingValue(byKey, 'provider_timeout_seconds'));
    final providerHealthcheckInterval = TextEditingController(
      text: _settingValue(
        byKey,
        'provider_healthcheck_interval_minutes',
        fallback: '60',
      ),
    );
    final instructions = TextEditingController(
        text: _settingValue(byKey, 'provider_instructions'));
    final feedbackAiBase = TextEditingController(
      text: _settingValue(
        byKey,
        'feedback_ai_base_url',
        fallback: _defaultAiBaseUrl,
      ),
    );
    final feedbackAiKey = TextEditingController();
    final feedbackAiModel = TextEditingController(
      text: _settingValue(
        byKey,
        'feedback_ai_model',
        fallback: _feedbackAiModel,
      ),
    );
    final promptAiBase = TextEditingController(
      text: _settingValue(
        byKey,
        'prompt_ai_base_url',
        fallback: '',
      ),
    );
    final promptAiKey = TextEditingController();
    final promptAiModel = TextEditingController(
      text: _settingValue(
        byKey,
        'prompt_ai_model',
        fallback: _promptAiModel,
      ),
    );
    var openclawMailEnabled = _settingBool(byKey, 'openclaw_mail_enabled');
    final openclawMailUser = TextEditingController(
      text: _settingValue(byKey, 'openclaw_mail_user'),
    );
    final openclawMailApiKey = TextEditingController();
    final emailSenderName = TextEditingController(
      text: _settingValue(byKey, 'email_sender_name', fallback: '从零开始生图'),
    );
    var emailPrimaryProvider = _settingValue(
      byKey,
      'email_code_primary_provider',
      fallback: 'claw163',
    );
    var emailBackupProvider = _settingValue(
      byKey,
      'email_code_backup_provider',
      fallback: 'resend',
    );
    var emailActiveSlot =
        _settingValue(byKey, 'email_code_active_slot', fallback: 'primary');
    var emailAutoSwitchEnabled =
        _settingBool(byKey, 'email_auto_switch_enabled');
    final resendBase = TextEditingController(
      text: _settingValue(
        byKey,
        'resend_base_url',
        fallback: 'https://api.resend.com',
      ),
    );
    final resendKey = TextEditingController();
    final resendFrom = TextEditingController(
      text: _settingValue(
        byKey,
        'resend_from',
        fallback: '从零开始生图 <noreply@mail.6688667.xyz>',
      ),
    );
    final systemNoticeEmailTo = TextEditingController(
      text: _settingValue(byKey, 'system_notice_email_to'),
    );
    final hermesBase =
        TextEditingController(text: _settingValue(byKey, 'hermes_base_url'));
    final hermesKey = TextEditingController();
    final smtpHost =
        TextEditingController(text: _settingValue(byKey, 'email_smtp_host'));
    final smtpPort = TextEditingController(
        text: _settingValue(byKey, 'email_smtp_port', fallback: '465'));
    final smtpUsername = TextEditingController(
        text: _settingValue(byKey, 'email_smtp_username'));
    final smtpPassword = TextEditingController();
    var smtpUseSsl = _settingBool(byKey, 'email_smtp_use_ssl', fallback: true);
    final generateCheckinMultiplier = TextEditingController(
      text: _settingValue(byKey, 'daily_checkin_generate_multiplier',
          fallback: '1'),
    );
    final editCheckinMultiplier = TextEditingController(
      text:
          _settingValue(byKey, 'daily_checkin_edit_multiplier', fallback: '1'),
    );
    var profile =
        _settingValue(byKey, 'provider_image_profile', fallback: 'gpt-image-2');
    var responseFormat =
        _settingValue(byKey, 'default_response_format', fallback: 'url');
    var quality =
        _settingValue(byKey, 'default_image_quality', fallback: 'high');
    var background =
        _settingValue(byKey, 'default_image_background', fallback: 'auto');
    var outputFormat =
        _settingValue(byKey, 'default_image_output_format', fallback: 'png');
    var allowRegistration =
        _settingValue(byKey, 'allow_public_registration', fallback: 'true')
                .toLowerCase() ==
            'true';
    var protectFileAccess =
        _settingValue(byKey, 'protect_file_access', fallback: 'false')
                .toLowerCase() ==
            'true';
    var activeProviderSlot =
        _settingValue(byKey, 'provider_active_slot', fallback: 'primary');
    if (!const ['primary', 'backup'].contains(activeProviderSlot)) {
      activeProviderSlot = 'primary';
    }
    var providerHealthcheckEnabled = _settingValue(
          byKey,
          'provider_healthcheck_enabled',
          fallback: 'true',
        ).toLowerCase() ==
        'true';
    final notificationRetentionDays = TextEditingController(
      text: _settingValue(byKey, 'notification_retention_days', fallback: '30'),
    );
    final notificationCategoryLimit = TextEditingController(
      text: _settingValue(byKey, 'notification_category_limit', fallback: '50'),
    );
    var forceUpdateEnabled = _settingBool(byKey, 'force_app_update_enabled');
    var forceReloginEnabled = _settingBool(byKey, 'force_relogin_enabled');
    final dialogCategory = category ?? '全部设置';

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final showBasic = category == null || category == '基础设置';
          final showProvider = category == null || category == '生成线路';
          final showAi = category == null || category == 'AI 辅助';
          final showNotification = category == null || category == '通知设置';
          final showMail = category == null || category == '邮件通道';
          final showPolicy = category == null || category == '系统策略';
          return _adminDialog(
            title: dialogCategory,
            icon: Icons.tune,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showBasic) ...[
                  TextField(
                      controller: uiTitle,
                      decoration: const InputDecoration(labelText: '界面标题')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: externalBase,
                      decoration: const InputDecoration(
                        labelText: '公开访问地址',
                        helperText: '用于邮件、分享和图片链接；留空时按当前访问地址自动判断',
                      )),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: allowRegistration,
                    onChanged: (value) =>
                        setDialogState(() => allowRegistration = value ?? true),
                    title: const Text('允许公开注册'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: generateCheckinMultiplier,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '签到生图奖励倍数'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: editCheckinMultiplier,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '签到改图奖励倍数'),
                  ),
                  const SizedBox(height: 18),
                ],
                if (showProvider) ...[
                  _settingsSectionTitle('VIP 模式线路'),
                  const SizedBox(height: 8),
                  TextField(
                      controller: providerBase,
                      decoration: const InputDecoration(labelText: '主用线路地址')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: providerKey,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: '主用线路密钥 1，留空不修改')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: providerSecondaryKey,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: '主用线路密钥 2，留空不修改')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: providerBackupBase,
                      decoration: const InputDecoration(labelText: '备用线路地址')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: providerBackupKey,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: '备用线路密钥 1，留空不修改')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: providerBackupSecondaryKey,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: '备用线路密钥 2，留空不修改')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: providerModel,
                      decoration: const InputDecoration(
                        labelText: 'VIP 模型',
                        helperText: '用于 VIP 模式的 Responses 文本调度和图片工具调用',
                      )),
                  const SizedBox(height: 12),
                  _stringDropdown(
                      'VIP 图片档位',
                      profile,
                      const ['gpt-image-2', 'codex-gpt-image-2', 'gpt-image-1'],
                      (value) => setDialogState(() => profile = value)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: providerTimeout,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '超时时间秒')),
                  const SizedBox(height: 18),
                  _settingsSectionTitle('一般模式线路'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: generalProviderBase,
                    decoration: const InputDecoration(labelText: '一般模式线路地址'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: generalProviderKey,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: '一般模式密钥，留空不修改'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: generalProviderModel,
                    decoration: const InputDecoration(
                      labelText: '一般模式文本模型',
                      helperText: '用于一般模式文本检测；图片生成使用下面的图片模型',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: generalProviderImageModel,
                    decoration: const InputDecoration(
                      labelText: '一般模式图片模型',
                      helperText: '用于普通模式 /v1/images 生图和改图',
                    ),
                  ),
                  const SizedBox(height: 18),
                  _settingsSectionTitle('通用生成设置'),
                  const SizedBox(height: 8),
                  _stringDropdown(
                      '当前线路',
                      activeProviderSlot,
                      const ['primary', 'backup'],
                      (value) =>
                          setDialogState(() => activeProviderSlot = value)),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: providerHealthcheckEnabled,
                    onChanged: (value) => setDialogState(
                        () => providerHealthcheckEnabled = value),
                    title: const Text('定时检测线路并自动切换'),
                    subtitle: const Text('开启后按下方间隔检测主用和备用线路'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: providerHealthcheckInterval,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '线路检测间隔分钟')),
                  const SizedBox(height: 12),
                  _stringDropdown(
                      '响应格式',
                      responseFormat,
                      const ['url', 'b64_json'],
                      (value) => setDialogState(() => responseFormat = value)),
                  const SizedBox(height: 12),
                  _stringDropdown(
                      '默认质量',
                      quality,
                      const ['auto', 'low', 'medium', 'high'],
                      (value) => setDialogState(() => quality = value)),
                  const SizedBox(height: 12),
                  _stringDropdown(
                      '默认背景',
                      background,
                      const ['auto', 'opaque', 'transparent'],
                      (value) => setDialogState(() => background = value)),
                  const SizedBox(height: 12),
                  _stringDropdown(
                      '输出格式',
                      outputFormat,
                      const ['png', 'jpeg', 'webp'],
                      (value) => setDialogState(() => outputFormat = value)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: instructions,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '模型调用指令',
                        helperText: '随请求转发给模型的系统级说明',
                      )),
                  const SizedBox(height: 16),
                ],
                if (showAi) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    '反馈 AI 整理',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: feedbackAiBase,
                    decoration: const InputDecoration(labelText: '反馈整理服务地址'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: feedbackAiKey,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '反馈整理密钥，留空不修改',
                      helperText: '展示时会打码；请求应由后端代理执行',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: feedbackAiModel,
                    decoration: const InputDecoration(labelText: '反馈整理模型'),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    '提示词 AI / 图片识别 AI',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: promptAiBase,
                    decoration: const InputDecoration(labelText: '提示词服务地址'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: promptAiKey,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '提示词服务密钥，留空不修改',
                      helperText: '与反馈 AI 分开保存，避免混淆',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: promptAiModel,
                    decoration: const InputDecoration(labelText: '提示词服务模型'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (showNotification) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    '通知中心',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notificationRetentionDays,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '已读通知保留天数',
                      helperText: '只清理已读通知，未读通知不会按天数自动移除',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notificationCategoryLimit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '每类通知显示上限',
                      helperText: '通知中心每个分类最多展示的条数',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (showMail) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    '验证码和系统通知邮件',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: openclawMailEnabled,
                    onChanged: (value) =>
                        setDialogState(() => openclawMailEnabled = value),
                    title: const Text('启用 163 邮箱主通道'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: openclawMailUser,
                    decoration: const InputDecoration(
                      labelText: '主通道发件邮箱',
                      helperText: '例如：bot.image@claw.163.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: openclawMailApiKey,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '主通道密钥，留空不修改',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailSenderName,
                    decoration: const InputDecoration(
                      labelText: '发件人显示名',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _stringDropdown(
                    '主用邮件通道',
                    emailPrimaryProvider,
                    const ['claw163', 'resend', 'smtp', 'none'],
                    (value) =>
                        setDialogState(() => emailPrimaryProvider = value),
                    labels: _mailProviderLabels,
                  ),
                  const SizedBox(height: 12),
                  _stringDropdown(
                    '备用邮件通道',
                    emailBackupProvider,
                    const ['resend', 'claw163', 'smtp', 'none'],
                    (value) =>
                        setDialogState(() => emailBackupProvider = value),
                    labels: _mailProviderLabels,
                  ),
                  const SizedBox(height: 12),
                  _stringDropdown(
                    '当前邮件线路',
                    emailActiveSlot,
                    const ['primary', 'backup'],
                    (value) => setDialogState(() => emailActiveSlot = value),
                    labels: _mailSlotLabels,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: emailAutoSwitchEnabled,
                    onChanged: (value) =>
                        setDialogState(() => emailAutoSwitchEnabled = value),
                    title: const Text('邮件失败后自动切换线路'),
                    subtitle: const Text('关闭时本次可走备用，但不会保存为当前线路'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: resendBase,
                    decoration: const InputDecoration(
                      labelText: '备用通道 API 地址',
                      helperText: '默认 https://api.resend.com',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: resendFrom,
                    decoration: const InputDecoration(
                      labelText: '备用通道发件人',
                      helperText: '例如：从零开始生图 <noreply@mail.6688667.xyz>',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resendKey,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '备用通道密钥，留空不修改',
                      helperText: '默认作为备用邮件通道',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    '系统通知收件人和兼容邮件通道',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: systemNoticeEmailTo,
                    decoration: const InputDecoration(
                      labelText: '系统通知收件人',
                      helperText: '多个邮箱用英文逗号分隔',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hermesBase,
                    decoration: const InputDecoration(
                      labelText: '兼容邮件服务地址',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: hermesKey,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: '兼容邮件服务密钥，留空不修改',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: smtpHost,
                    decoration: const InputDecoration(labelText: 'SMTP 服务器'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: smtpPort,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'SMTP 端口'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: smtpUsername,
                    decoration: const InputDecoration(labelText: 'SMTP 用户名/邮箱'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: smtpPassword,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'SMTP 密码/授权码，留空不修改'),
                  ),
                  SwitchListTile(
                    value: smtpUseSsl,
                    onChanged: (value) =>
                        setDialogState(() => smtpUseSsl = value),
                    title: const Text('SMTP 使用 SSL'),
                  ),
                  const SizedBox(height: 12),
                ],
                if (showPolicy) ...[
                  SwitchListTile(
                    value: protectFileAccess,
                    onChanged: (value) =>
                        setDialogState(() => protectFileAccess = value),
                    title: const Text('图片访问需要登录'),
                    subtitle: const Text('关闭时头像、历史图和分享链接可直接查看；开启后未登录会跳转登录'),
                  ),
                  SwitchListTile(
                    value: forceUpdateEnabled,
                    onChanged: (value) =>
                        setDialogState(() => forceUpdateEnabled = value),
                    title: const Text('强制更新'),
                  ),
                  SwitchListTile(
                    value: forceReloginEnabled,
                    onChanged: (value) =>
                        setDialogState(() => forceReloginEnabled = value),
                    title: const Text('强制重新登录'),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消')),
              FilledButton(
                onPressed: () => Navigator.pop(
                    context,
                    {
                      'ui_title': uiTitle.text.trim(),
                      'external_access_base_url': externalBase.text.trim(),
                      'provider_base_url': providerBase.text.trim(),
                      if (providerKey.text.trim().isNotEmpty)
                        'provider_api_key': providerKey.text.trim(),
                      if (providerSecondaryKey.text.trim().isNotEmpty)
                        'provider_secondary_api_key':
                            providerSecondaryKey.text.trim(),
                      'provider_backup_base_url':
                          providerBackupBase.text.trim(),
                      if (providerBackupKey.text.trim().isNotEmpty)
                        'provider_backup_api_key':
                            providerBackupKey.text.trim(),
                      if (providerBackupSecondaryKey.text.trim().isNotEmpty)
                        'provider_backup_secondary_api_key':
                            providerBackupSecondaryKey.text.trim(),
                      'provider_active_slot': activeProviderSlot,
                      'provider_healthcheck_enabled':
                          providerHealthcheckEnabled,
                      'provider_healthcheck_interval_minutes':
                          int.tryParse(providerHealthcheckInterval.text),
                      'provider_model': providerModel.text.trim(),
                      'general_provider_base_url':
                          generalProviderBase.text.trim(),
                      if (generalProviderKey.text.trim().isNotEmpty)
                        'general_provider_api_key':
                            generalProviderKey.text.trim(),
                      'general_provider_model':
                          generalProviderModel.text.trim(),
                      'general_provider_image_model':
                          generalProviderImageModel.text.trim(),
                      'provider_image_profile': profile,
                      'provider_timeout_seconds':
                          int.tryParse(providerTimeout.text),
                      'default_response_format': responseFormat,
                      'default_image_quality': quality,
                      'default_image_background': background,
                      'default_image_output_format': outputFormat,
                      'feedback_ai_base_url': feedbackAiBase.text.trim().isEmpty
                          ? _defaultAiBaseUrl
                          : feedbackAiBase.text.trim(),
                      if (feedbackAiKey.text.trim().isNotEmpty)
                        'feedback_ai_api_key': feedbackAiKey.text.trim(),
                      'feedback_ai_model': feedbackAiModel.text.trim().isEmpty
                          ? _feedbackAiModel
                          : feedbackAiModel.text.trim(),
                      'prompt_ai_base_url': promptAiBase.text.trim().isEmpty
                          ? null
                          : promptAiBase.text.trim(),
                      if (promptAiKey.text.trim().isNotEmpty)
                        'prompt_ai_api_key': promptAiKey.text.trim(),
                      'prompt_ai_model': promptAiModel.text.trim().isEmpty
                          ? _promptAiModel
                          : promptAiModel.text.trim(),
                      'openclaw_mail_enabled': openclawMailEnabled,
                      'openclaw_mail_user': openclawMailUser.text.trim(),
                      if (openclawMailApiKey.text.trim().isNotEmpty)
                        'openclaw_mail_api_key': openclawMailApiKey.text.trim(),
                      'email_sender_name': emailSenderName.text.trim().isEmpty
                          ? '从零开始生图'
                          : emailSenderName.text.trim(),
                      'email_code_primary_provider': emailPrimaryProvider,
                      'email_code_backup_provider': emailBackupProvider,
                      'email_code_active_slot': emailActiveSlot,
                      'email_auto_switch_enabled': emailAutoSwitchEnabled,
                      'hermes_base_url': hermesBase.text.trim(),
                      if (hermesKey.text.trim().isNotEmpty)
                        'hermes_api_key': hermesKey.text.trim(),
                      if (resendKey.text.trim().isNotEmpty)
                        'resend_api_key': resendKey.text.trim(),
                      'resend_base_url': resendBase.text.trim().isEmpty
                          ? 'https://api.resend.com'
                          : resendBase.text.trim(),
                      'resend_from': resendFrom.text.trim(),
                      'system_notice_email_to': systemNoticeEmailTo.text.trim(),
                      'email_smtp_host': smtpHost.text.trim(),
                      'email_smtp_port': int.tryParse(smtpPort.text.trim()),
                      'email_smtp_username': smtpUsername.text.trim(),
                      if (smtpPassword.text.trim().isNotEmpty)
                        'email_smtp_password': smtpPassword.text.trim(),
                      'email_smtp_use_ssl': smtpUseSsl,
                      'daily_checkin_generate_multiplier':
                          double.tryParse(generateCheckinMultiplier.text),
                      'daily_checkin_edit_multiplier':
                          double.tryParse(editCheckinMultiplier.text),
                      'provider_instructions': instructions.text.trim(),
                      'allow_public_registration': allowRegistration,
                      'protect_file_access': protectFileAccess,
                      'notification_retention_days':
                          int.tryParse(notificationRetentionDays.text.trim()),
                      'notification_category_limit':
                          int.tryParse(notificationCategoryLimit.text.trim()),
                      'force_app_update_enabled': forceUpdateEnabled,
                      'force_relogin_enabled': forceReloginEnabled,
                    }..removeWhere(
                        (key, value) =>
                            category != null &&
                            !_settingKeyBelongsToCategory(key, category),
                      )),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    notificationRetentionDays.dispose();
    notificationCategoryLimit.dispose();
    if (payload == null) return;
    await _save(
        () => ref.read(gatewayClientProvider).saveAdminSystemSettings(payload),
        '系统设置已保存。');
  }

  Future<void> _editBackupSettings(List<Map<String, dynamic>> settings) async {
    final byKey = {
      for (final item in _settingsWithAiDefaults(settings))
        _text(item['key']): item,
    };
    var localEnabled = _settingBool(byKey, 'local_backup_enabled');
    var backupNotificationEnabled =
        _settingBool(byKey, 'backup_notification_enabled', fallback: true);
    final localInterval = TextEditingController(
      text: _settingValue(byKey, 'local_backup_interval_minutes',
          fallback: '1440'),
    );
    final localRetention = TextEditingController(
      text: _settingValue(byKey, 'local_backup_retention_days', fallback: '14'),
    );
    var googleEnabled = _settingBool(byKey, 'google_drive_backup_enabled');
    final googleFolder = TextEditingController(
      text: _settingValue(byKey, 'google_drive_backup_folder_id'),
    );
    final googleServiceAccount = TextEditingController();
    var openlistPrimaryEnabled =
        _settingBool(byKey, 'openlist_backup_primary_enabled');
    final openlistPrimaryWebdav = TextEditingController(
      text: _settingValue(byKey, 'openlist_backup_primary_webdav_url'),
    );
    final openlistPrimaryPublic = TextEditingController(
      text: _settingValue(byKey, 'openlist_backup_primary_public_url'),
    );
    final openlistPrimaryUsername = TextEditingController(
      text: _settingValue(byKey, 'openlist_backup_primary_username'),
    );
    final openlistPrimaryPassword = TextEditingController();
    final openlistPrimaryPath = TextEditingController(
      text: _settingValue(
        byKey,
        'openlist_backup_primary_path',
        fallback: '/gateway-backups',
      ),
    );
    var openlistSecondaryEnabled =
        _settingBool(byKey, 'openlist_backup_secondary_enabled');
    final openlistSecondaryWebdav = TextEditingController(
      text: _settingValue(byKey, 'openlist_backup_secondary_webdav_url'),
    );
    final openlistSecondaryPublic = TextEditingController(
      text: _settingValue(byKey, 'openlist_backup_secondary_public_url'),
    );
    final openlistSecondaryUsername = TextEditingController(
      text: _settingValue(byKey, 'openlist_backup_secondary_username'),
    );
    final openlistSecondaryPassword = TextEditingController();
    final openlistSecondaryPath = TextEditingController(
      text: _settingValue(
        byKey,
        'openlist_backup_secondary_path',
        fallback: '/gateway-backups-secondary',
      ),
    );

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return _adminDialog(
            title: '数据备份设置',
            icon: Icons.backup_outlined,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _settingsSectionTitle('本地备份'),
                SwitchListTile(
                  value: localEnabled,
                  onChanged: (value) =>
                      setDialogState(() => localEnabled = value),
                  title: const Text('开启定时备份'),
                ),
                TextField(
                  controller: localInterval,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '备份间隔分钟'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: localRetention,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '本地保留天数'),
                ),
                SwitchListTile(
                  value: backupNotificationEnabled,
                  onChanged: (value) =>
                      setDialogState(() => backupNotificationEnabled = value),
                  title: const Text('备份结果通知'),
                ),
                const SizedBox(height: 18),
                _settingsSectionTitle('Google Drive'),
                SwitchListTile(
                  value: googleEnabled,
                  onChanged: (value) =>
                      setDialogState(() => googleEnabled = value),
                  title: const Text('上传到 Google Drive'),
                ),
                TextField(
                  controller: googleFolder,
                  decoration: const InputDecoration(labelText: '目标文件夹 ID'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: googleServiceAccount,
                  obscureText: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Google 服务账号 JSON，留空不修改',
                    helperText: '从 Google Cloud 服务账号下载的 JSON',
                  ),
                ),
                const SizedBox(height: 18),
                _settingsSectionTitle('OpenList 主用'),
                SwitchListTile(
                  value: openlistPrimaryEnabled,
                  onChanged: (value) =>
                      setDialogState(() => openlistPrimaryEnabled = value),
                  title: const Text('启用主用 OpenList'),
                ),
                TextField(
                  controller: openlistPrimaryWebdav,
                  decoration: const InputDecoration(labelText: 'WebDAV 地址'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: openlistPrimaryPublic,
                  decoration: const InputDecoration(labelText: '外网打开地址'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: openlistPrimaryUsername,
                  decoration: const InputDecoration(labelText: '用户名'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: openlistPrimaryPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'WebDAV 密码，留空不修改',
                    helperText: '用于备份上传；OpenList 后台登录密码需在 OpenList 内单独设置',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: openlistPrimaryPath,
                  decoration: const InputDecoration(labelText: '远端目录'),
                ),
                const SizedBox(height: 18),
                _settingsSectionTitle('OpenList 备用'),
                SwitchListTile(
                  value: openlistSecondaryEnabled,
                  onChanged: (value) =>
                      setDialogState(() => openlistSecondaryEnabled = value),
                  title: const Text('启用备用 OpenList'),
                ),
                TextField(
                  controller: openlistSecondaryWebdav,
                  decoration: const InputDecoration(labelText: 'WebDAV 地址'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: openlistSecondaryPublic,
                  decoration: const InputDecoration(labelText: '外网打开地址'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: openlistSecondaryUsername,
                  decoration: const InputDecoration(labelText: '用户名'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: openlistSecondaryPassword,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'WebDAV 密码，留空不修改',
                    helperText: '用于备份上传；OpenList 后台登录密码需在 OpenList 内单独设置',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: openlistSecondaryPath,
                  decoration: const InputDecoration(labelText: '远端目录'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, {
                  'local_backup_enabled': localEnabled,
                  'local_backup_interval_minutes':
                      int.tryParse(localInterval.text.trim()),
                  'local_backup_interval_hours':
                      _minutesToHours(localInterval.text.trim()),
                  'local_backup_retention_days':
                      int.tryParse(localRetention.text.trim()),
                  'backup_notification_enabled': backupNotificationEnabled,
                  'google_drive_backup_enabled': googleEnabled,
                  'google_drive_backup_folder_id': googleFolder.text.trim(),
                  if (googleServiceAccount.text.trim().isNotEmpty)
                    'google_drive_service_account_json':
                        googleServiceAccount.text.trim(),
                  'openlist_backup_primary_enabled': openlistPrimaryEnabled,
                  'openlist_backup_primary_webdav_url':
                      openlistPrimaryWebdav.text.trim(),
                  'openlist_backup_primary_public_url':
                      openlistPrimaryPublic.text.trim(),
                  'openlist_backup_primary_username':
                      openlistPrimaryUsername.text.trim(),
                  if (openlistPrimaryPassword.text.trim().isNotEmpty)
                    'openlist_backup_primary_password':
                        openlistPrimaryPassword.text.trim(),
                  'openlist_backup_primary_path':
                      openlistPrimaryPath.text.trim().isEmpty
                          ? '/gateway-backups'
                          : openlistPrimaryPath.text.trim(),
                  'openlist_backup_secondary_enabled': openlistSecondaryEnabled,
                  'openlist_backup_secondary_webdav_url':
                      openlistSecondaryWebdav.text.trim(),
                  'openlist_backup_secondary_public_url':
                      openlistSecondaryPublic.text.trim(),
                  'openlist_backup_secondary_username':
                      openlistSecondaryUsername.text.trim(),
                  if (openlistSecondaryPassword.text.trim().isNotEmpty)
                    'openlist_backup_secondary_password':
                        openlistSecondaryPassword.text.trim(),
                  'openlist_backup_secondary_path':
                      openlistSecondaryPath.text.trim().isEmpty
                          ? '/gateway-backups-secondary'
                          : openlistSecondaryPath.text.trim(),
                }),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    if (payload == null) return;
    await _save(
      () => ref.read(gatewayClientProvider).saveAdminSystemSettings(payload),
      '备份设置已保存。',
    );
  }

  Future<void> _runLocalBackup() async {
    if (_isRunningBackup) return;
    setState(() => _isRunningBackup = true);
    try {
      final result =
          await ref.read(gatewayClientProvider).runAdminLocalBackup();
      if (!mounted) return;
      final status = _text(result['status']);
      _showMessage(
        _text(result['message'], fallback: '备份已执行。'),
        isError: status == 'failed',
      );
      _reload();
    } catch (error) {
      if (!mounted) return;
      _showMessage(friendlyError(error, fallback: '执行数据备份失败。'), isError: true);
    } finally {
      if (mounted) setState(() => _isRunningBackup = false);
    }
  }

  Future<void> _restoreLocalBackup(Map<String, dynamic> item) async {
    final id = _text(item['id']);
    if (id.isEmpty || id == '-') return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('恢复备份'),
        content: Text(
          '将恢复 ${formatLocalTime(item['created_at'])} 的本地备份。'
          '系统会先生成当前状态安全备份，再恢复数据库和生成文件。确认继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final result =
          await ref.read(gatewayClientProvider).restoreAdminLocalBackup(id);
      if (!mounted) return;
      _showMessage(_text(result['message'], fallback: '备份已恢复。'));
      _reload();
    } catch (error) {
      if (!mounted) return;
      _showMessage(friendlyError(error, fallback: '恢复数据备份失败。'), isError: true);
    }
  }

  Future<void> _createInvitationCodes() async {
    final countController = TextEditingController(text: '5');
    final count = await showDialog<int>(
      context: context,
      builder: (context) => _adminDialog(
        title: '生成邀请码',
        icon: Icons.add_card,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '生成数量',
                helperText: '单次 1 到 100 个，生成后会保留在列表中。',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(countController.text.trim()) ?? 0;
              Navigator.pop(context, value);
            },
            child: const Text('生成'),
          ),
        ],
      ),
    );
    countController.dispose();
    if (count == null) return;
    if (count < 1 || count > 100) {
      _showMessage('生成数量需为 1 到 100。', isError: true);
      return;
    }
    try {
      final created = await ref
          .read(gatewayClientProvider)
          .createAdminInvitationCodes(count);
      final codes = _mapList(created)
          .map((item) => _text(item['code']))
          .where((code) => code != '-')
          .toList();
      if (!mounted) return;
      _showMessage('已生成 ${codes.length} 个邀请码。');
      _reload();
      if (codes.isNotEmpty) {
        await _showGeneratedInvitationCodes(codes);
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(friendlyError(error), isError: true);
    }
  }

  Future<void> _showGeneratedInvitationCodes(List<String> codes) {
    final text = codes.join('\n');
    return showDialog<void>(
      context: context,
      builder: (context) => _adminDialog(
        title: '本次生成的邀请码',
        icon: Icons.copy_all,
        content: SelectableText(
          text,
          style: const TextStyle(
            fontFamily: 'monospace',
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) Navigator.pop(context);
              if (mounted) _showMessage('本批邀请码已复制。');
            },
            icon: const Icon(Icons.copy),
            label: const Text('复制本批'),
          ),
        ],
      ),
    );
  }

  Future<void> _publishAnnouncement() async {
    final title = TextEditingController();
    final body = TextEditingController();
    var notify = true;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return _adminDialog(
            title: '发布公告',
            icon: Icons.campaign_outlined,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: '公告标题'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: body,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: '公告内容'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: notify,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('同步推送到通知'),
                  onChanged: (value) => setDialogState(() => notify = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, {
                  'title': title.text.trim(),
                  'body': body.text.trim(),
                  'notify': notify,
                }),
                child: const Text('发布'),
              ),
            ],
          );
        },
      ),
    );
    title.dispose();
    body.dispose();
    if (payload == null) return;
    if (_text(payload['title'], fallback: '').length < 2 ||
        _text(payload['body'], fallback: '').length < 2) {
      _showMessage('请填写公告标题和内容。', isError: true);
      return;
    }
    setState(() => _isPublishingAnnouncement = true);
    try {
      await ref.read(gatewayClientProvider).publishAdminAnnouncement(
            title: _text(payload['title'], fallback: ''),
            body: _text(payload['body'], fallback: ''),
            notify: payload['notify'] == true,
          );
      if (!mounted) return;
      _showMessage('公告已发布。');
      _reload();
    } catch (error) {
      if (!mounted) return;
      _showMessage(friendlyError(error, fallback: '发布公告失败。'), isError: true);
    } finally {
      if (mounted) setState(() => _isPublishingAnnouncement = false);
    }
  }

  Future<void> _editAnnouncement(Map<String, dynamic> item) async {
    final id = _text(item['id']);
    if (id.isEmpty) return;
    final title =
        TextEditingController(text: _text(item['title'], fallback: ''));
    final body = TextEditingController(text: _text(item['body'], fallback: ''));
    var isPublished = item['is_published'] != false;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return _adminDialog(
            title: '编辑公告',
            icon: Icons.edit_outlined,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: '公告标题'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: body,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(labelText: '公告内容'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: isPublished,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('公告上线'),
                  onChanged: (value) =>
                      setDialogState(() => isPublished = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, {
                  'title': title.text.trim(),
                  'body': body.text.trim(),
                  'is_published': isPublished,
                }),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    title.dispose();
    body.dispose();
    if (payload == null) return;
    if (_text(payload['title'], fallback: '').length < 2 ||
        _text(payload['body'], fallback: '').length < 2) {
      _showMessage('请填写公告标题和内容。', isError: true);
      return;
    }
    await _save(
      () => ref.read(gatewayClientProvider).updateAdminAnnouncement(
            id: id,
            title: _text(payload['title'], fallback: ''),
            body: _text(payload['body'], fallback: ''),
            isPublished: payload['is_published'] == true,
          ),
      '公告已保存。',
    );
  }

  Future<void> _deleteAnnouncement(Map<String, dynamic> item) async {
    final id = _text(item['id']);
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除公告'),
        content: Text('确认删除“${_text(item['title'])}”？'),
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
    await _save(
      () => ref.read(gatewayClientProvider).deleteAdminAnnouncement(id),
      '公告已删除。',
    );
  }

  Future<void> _grantWelfare() async {
    final title = TextEditingController(text: '全员福利');
    final body = TextEditingController();
    final generate = TextEditingController(text: '0');
    final edit = TextEditingController(text: '0');
    var notify = true;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return _adminDialog(
            title: '发放福利',
            icon: Icons.card_giftcard_outlined,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: '福利标题'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: body,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: '说明，可选'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: generate,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '生图额度'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: edit,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '改图额度'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: notify,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('同步推送到通知'),
                  onChanged: (value) => setDialogState(() => notify = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, {
                  'title': title.text.trim(),
                  'body': body.text.trim(),
                  'generate': int.tryParse(generate.text.trim()) ?? 0,
                  'edit': int.tryParse(edit.text.trim()) ?? 0,
                  'notify': notify,
                }),
                child: const Text('发放'),
              ),
            ],
          );
        },
      ),
    );
    title.dispose();
    body.dispose();
    generate.dispose();
    edit.dispose();
    if (payload == null) return;
    final generateBonus = payload['generate'] as int? ?? 0;
    final editBonus = payload['edit'] as int? ?? 0;
    if (generateBonus <= 0 && editBonus <= 0) {
      _showMessage('请至少填写一种福利额度。', isError: true);
      return;
    }
    setState(() => _isGrantingWelfare = true);
    try {
      final result = await ref.read(gatewayClientProvider).grantAdminWelfare(
            title: _text(payload['title'], fallback: '全员福利'),
            body: _text(payload['body'], fallback: ''),
            generateBonus: generateBonus,
            editBonus: editBonus,
            notify: payload['notify'] == true,
          );
      if (!mounted) return;
      _showMessage(
          '已给 ${_text(result['recipient_count'], fallback: '0')} 个用户发放福利。');
      _reload();
    } catch (error) {
      if (!mounted) return;
      _showMessage(friendlyError(error, fallback: '发放福利失败。'), isError: true);
    } finally {
      if (mounted) setState(() => _isGrantingWelfare = false);
    }
  }

  Future<Map<String, dynamic>?> _basicEntityDialog({
    required String title,
    required TextEditingController name,
    required TextEditingController description,
    required List<Widget> extraFields,
    required bool active,
    required void Function(bool active) onActiveChanged,
    required Map<String, dynamic> Function() payloadBuilder,
  }) {
    var isActive = active;
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return _adminDialog(
            title: title,
            icon: Icons.edit_note,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: '名称')),
                const SizedBox(height: 12),
                TextField(
                    controller: description,
                    decoration: const InputDecoration(labelText: '描述')),
                const SizedBox(height: 12),
                ...extraFields
                    .expand((field) => [field, const SizedBox(height: 12)]),
                CheckboxListTile(
                  value: isActive,
                  onChanged: (value) {
                    setDialogState(() => isActive = value ?? true);
                    onActiveChanged(isActive);
                  },
                  title: const Text('启用'),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, payloadBuilder()),
                  child: const Text('保存')),
            ],
          );
        },
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<Map<String, dynamic>> items,
    required void Function(String value) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: _text(item['id']),
              child: Text(_text(item['name'])),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Widget _stringDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String value) onChanged, {
    Map<String, String> labels = const {},
  }) {
    final safeValue = items.contains(value) ? value : items.first;
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((item) => DropdownMenuItem<String>(
              value: item, child: Text(labels[item] ?? item)))
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }

  Future<void> _probeCapabilities() async {
    await _save(
      () => ref.read(gatewayClientProvider).probeImageCapabilities(),
      '图片尺寸探测已完成。',
    );
  }

  Future<void> _probeProviderHealth() async {
    if (_isProviderHealthChecking) return;
    setState(() => _isProviderHealthChecking = true);
    _showMessage('正在检测生成线路，请稍候。');
    try {
      final result =
          await ref.read(gatewayClientProvider).providerHealthcheck();
      if (!mounted) return;
      await _showProviderHealthResult(result);
      _reload();
    } catch (error) {
      if (!mounted) return;
      _showMessage(friendlyError(error, fallback: '线路检测失败。'), isError: true);
    } finally {
      if (mounted) setState(() => _isProviderHealthChecking = false);
    }
  }

  Widget _settingsSectionTitle(String title) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: scheme.primary,
        ),
      ),
    );
  }

  Future<void> _showProviderHealthResult(Map<String, dynamic> result) async {
    final checks = _map(result['checks']);
    final current = _text(result['current_slot'], fallback: 'primary');
    final recommended = _text(result['recommended_slot'], fallback: current);
    final shouldSwitch = recommended != current;
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('线路检测'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _healthLine('主用', _map(checks['primary'])),
              const SizedBox(height: 8),
              _healthLine('备用', _map(checks['backup'])),
              const SizedBox(height: 12),
              Text(
                '当前线路：${_providerSlotLabel(current)}\n建议线路：${_providerSlotLabel(recommended)}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('关闭'),
          ),
          if (shouldSwitch)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('切换到建议线路'),
            ),
        ],
      ),
    );
    if (apply != true) return;
    try {
      _showMessage('正在切换推荐线路...');
      final switched = await ref
          .read(gatewayClientProvider)
          .providerHealthcheck(applySwitch: true);
      if (!mounted) return;
      final newSlot =
          _text(switched['recommended_slot'], fallback: recommended);
      _showMessage('已切换到 $newSlot。');
      _reload();
    } catch (error) {
      if (!mounted) return;
      _showMessage(friendlyError(error, fallback: '切换推荐线路失败。'), isError: true);
    }
  }

  Widget _healthLine(String label, Map<String, dynamic> item) {
    final ok = item['ok'] == true;
    final configured = item['configured'] == true;
    final textOk = item['text_ok'];
    final imageOk = item['image_ok'];
    final textDetail = _healthReason(_text(item['text_detail'], fallback: '-'));
    final imageDetail =
        _healthReason(_text(item['image_detail'], fallback: '-'));
    final detail = configured
        ? _healthReason(_text(item['detail'], fallback: '-'))
        : '线路未完整配置';
    final lines = <String>[
      '状态：${ok ? '可用' : '不可用'}',
      if (textOk != null) '文本：${textOk == true ? '可用' : '不可用（$textDetail）'}',
      if (imageOk != null) '图片：${imageOk == true ? '可用' : '不可用（$imageDetail）'}',
      if (textOk == null && imageOk == null) '原因：$detail',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label线路',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        ...lines.map((line) => Text('- $line')),
      ],
    );
  }

  String _providerSlotLabel(String value) {
    return _providerSlotLabels[value] ?? value;
  }

  String _healthReason(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    final lowered = normalized.toLowerCase();
    final reasons = <String>[];
    void addIf(String label, List<String> needles) {
      if (needles.any((needle) => lowered.contains(needle.toLowerCase()))) {
        reasons.add(label);
      }
    }

    addIf('额度或频率限制', ['额度或频率限制', 'usage_limit', 'rate limit']);
    addIf('权限或账号限制', ['拒绝访问', '认证失败', 'unauthorized', 'forbidden', '权限']);
    addIf('模型或接口不存在', ['模型或接口不存在', 'not found']);
    addIf('线路超时', ['响应超时', 'timeout']);
    addIf('网络或地址不可达', ['无法连接上游', 'network', 'dns', 'base_url']);
    addIf('安全策略拦截', ['安全策略', 'content_policy', 'safety']);
    addIf('返回格式异常', ['返回格式异常', '空响应', '空图片', '未返回可用图片']);
    addIf('线路未完整配置', ['未配置', 'base_url 或 key 未配置', '线路未完整配置']);
    addIf('线路返回异常', ['上游返回异常', 'provider returned http']);
    if (reasons.isNotEmpty) {
      return reasons.toSet().join('、');
    }
    if (normalized.isEmpty || normalized == '-') return '未返回明确原因';
    const maxLength = 80;
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}...';
  }

  String _enabledLabel(dynamic value) {
    return value == true ? '开启' : '关闭';
  }

  String _backupIntervalLabel(String value) {
    final minutes = int.tryParse(value) ?? 1440;
    if (minutes % 1440 == 0) {
      return '${minutes ~/ 1440} 天';
    }
    if (minutes % 60 == 0) {
      return '${minutes ~/ 60} 小时';
    }
    return '$minutes 分钟';
  }

  int? _minutesToHours(String value) {
    final minutes = int.tryParse(value.trim());
    if (minutes == null) return null;
    final hours = (minutes / 60).round();
    if (hours < 1) return 1;
    if (hours > 168) return 168;
    return hours;
  }

  DateTime _backupCreatedAt(Map<String, dynamic> item) {
    return DateTime.tryParse(_text(item['created_at'], fallback: '')) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  String _backupTargetLabel(String target) {
    switch (target) {
      case 'local':
        return '本地';
      case 'google_drive':
        return 'Google Drive';
      case 'openlist_primary':
        return 'OpenList 主用';
      case 'openlist_secondary':
        return 'OpenList 备用';
      default:
        return target == '-' ? '备份' : target;
    }
  }

  String _backupStatusLabel(String status) {
    switch (status) {
      case 'success':
        return '成功';
      case 'partial':
        return '部分成功';
      case 'failed':
        return '失败';
      default:
        return status == '-' ? '未知' : status;
    }
  }

  String _formatBytes(dynamic value) {
    final bytes =
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes;
    var index = 0;
    while (size >= 1024 && index < units.length - 1) {
      size /= 1024;
      index += 1;
    }
    final fractionDigits = index == 0 ? 0 : 1;
    return '${size.toStringAsFixed(fractionDigits)} ${units[index]}';
  }

  bool _settingBool(
    Map<String, Map<String, dynamic>> settings,
    String key, {
    bool fallback = false,
  }) {
    final value =
        _settingValue(settings, key, fallback: fallback ? 'true' : 'false');
    return const {'1', 'true', 'yes', 'on'}.contains(value.toLowerCase());
  }

  Map<String, List<Map<String, dynamic>>> _settingGroups(
    List<Map<String, dynamic>> settings,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final setting in settings) {
      final key = _text(setting['key']);
      final category = _text(
        setting['category'],
        fallback: _settingCategoryForKey(key),
      );
      groups.putIfAbsent(category, () => []).add(setting);
    }
    const order = [
      '基础设置',
      '生成线路',
      'AI 辅助',
      '通知设置',
      '邮件通道',
      '系统策略',
      '数据备份',
    ];
    final sorted = <String, List<Map<String, dynamic>>>{};
    for (final key in order) {
      final values = groups.remove(key);
      if (values != null && values.isNotEmpty) sorted[key] = values;
    }
    sorted.addAll(groups);
    return sorted;
  }

  bool _settingKeyBelongsToCategory(String key, String category) {
    return _settingCategoryForKey(key) == category;
  }

  String _settingCategoryForKey(String key) {
    if (key == 'ui_title' ||
        key == 'external_access_base_url' ||
        key == 'allow_public_registration' ||
        key.startsWith('daily_checkin_')) {
      return '基础设置';
    }
    if (key.startsWith('feedback_ai_') || key.startsWith('prompt_ai_')) {
      return 'AI 辅助';
    }
    if (key.startsWith('notification_')) {
      return '通知设置';
    }
    if (key.startsWith('hermes_') ||
        key.startsWith('openclaw_mail_') ||
        key.startsWith('resend_') ||
        key.startsWith('email_code_') ||
        key.startsWith('email_smtp_') ||
        key == 'email_sender_name' ||
        key == 'email_auto_switch_enabled' ||
        key.startsWith('system_notice')) {
      return '邮件通道';
    }
    if (key == 'protect_file_access' ||
        key.startsWith('force_app_update') ||
        key.startsWith('force_relogin')) {
      return '系统策略';
    }
    if (key.contains('backup') ||
        key.startsWith('google_drive_') ||
        key.startsWith('openlist_')) {
      return '数据备份';
    }
    if (key.startsWith('provider_') ||
        key.startsWith('general_provider_') ||
        key.startsWith('default_')) {
      return '生成线路';
    }
    return '基础设置';
  }

  String _settingLabel(String key) {
    const labels = {
      'ui_title': '标题',
      'external_access_base_url': '公开地址',
      'provider_active_slot': '线路',
      'provider_model': 'VIP 模型',
      'general_provider_image_model': '普通图片模型',
      'notification_retention_days': '已读通知清理',
      'notification_category_limit': '每类显示上限',
      'openclaw_mail_enabled': '主邮件通道',
      'openclaw_mail_user': '主通道邮箱',
      'email_code_primary_provider': '主用通道',
      'email_code_backup_provider': '备用通道',
      'email_code_active_slot': '邮件线路',
      'email_auto_switch_enabled': '自动切换',
      'force_app_update_enabled': '强制更新',
      'force_relogin_enabled': '强制重登',
      'protect_file_access': '图片登录访问',
    };
    return labels[key] ?? key;
  }

  Future<void> _copyText(String text, String success) async {
    final value = text.trim();
    if (value.isEmpty || value == '-') return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    _showMessage(success);
  }

  Future<void> _save(Future<dynamic> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      _showMessage(success);
      _reload();
    } catch (error) {
      if (!mounted) return;
      _showMessage(friendlyError(error), isError: true);
    }
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _revision += 1);
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!isError) {
      showCenterNotice(context, message);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  bool _can(Map<String, dynamic>? user, String permission) {
    return _isAdmin(user) || _permissions(user).contains(permission);
  }

  bool _isAdmin(Map<String, dynamic>? user) {
    final role = user?['role'] as Map? ?? {};
    return role['id'] == 'role_admin';
  }

  Set<String> _permissions(Map<String, dynamic>? user) {
    return (user?['permissions'] as List? ?? [])
        .map((item) => item.toString())
        .toSet();
  }

  String _quotaBrief(String label, Map<String, dynamic> quota) {
    if (quota['is_unlimited'] == true) {
      return '$label 无限/已用 ${_text(quota['used'], fallback: '0')}';
    }
    return '$label ${_text(quota['remaining'], fallback: '0')}/${_text(quota['total'], fallback: '0')}';
  }

  String _historyQuotaBrief(dynamic quotaValue, dynamic capValue) {
    final quota = _map(quotaValue);
    if (quota.isNotEmpty) {
      if (quota['is_unlimited'] == true) {
        return '无限';
      }
      return '${_text(quota['used'], fallback: '0')}/${_text(quota['total'], fallback: '0')} 条';
    }
    return '${_text(capValue, fallback: '0')} 条';
  }

  String _imageModeLabel(String mode) {
    switch (mode) {
      case 'general':
        return '一般模式';
      case 'vip':
        return 'VIP模式';
      default:
        return 'VIP模式';
    }
  }

  String _imageModeOverrideLabel(String mode) {
    if (mode.trim().isEmpty || mode == '-') return '跟随用户组';
    return '用户指定 ${_imageModeLabel(mode)}';
  }

  int? _nullableInt(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  List<Map<String, dynamic>> _settingsWithAiDefaults(
    List<Map<String, dynamic>> settings,
  ) {
    final byKey = {for (final item in settings) _text(item['key']): item};
    final additions = <Map<String, dynamic>>[
      {
        'key': 'feedback_ai_base_url',
        'value': _defaultAiBaseUrl,
        'description': '反馈 AI 整理服务地址',
      },
      {
        'key': 'provider_secondary_api_key',
        'value': 'xxx',
        'description': '主用线路备用密钥',
      },
      {
        'key': 'provider_backup_base_url',
        'value': '',
        'description': '备用线路地址',
      },
      {
        'key': 'provider_backup_api_key',
        'value': 'xxx',
        'description': '备用线路密钥',
      },
      {
        'key': 'provider_backup_secondary_api_key',
        'value': 'xxx',
        'description': '备用线路第二密钥',
      },
      {
        'key': 'provider_active_slot',
        'value': 'primary',
        'description': '当前启用的生成线路',
      },
      {
        'key': 'provider_healthcheck_enabled',
        'value': 'true',
        'description': '是否定时检测并自动切换主备线路',
      },
      {
        'key': 'provider_healthcheck_interval_minutes',
        'value': '60',
        'description': '文本和图片线路检测间隔分钟',
      },
      {
        'key': 'protect_file_access',
        'value': 'false',
        'description': '是否要求登录后才能查看图片文件与分享链接',
      },
      {
        'key': 'general_provider_base_url',
        'value': _generalProviderBaseUrl,
        'description': '一般模式 OpenAI 兼容服务地址',
      },
      {
        'key': 'general_provider_api_key',
        'value': 'xxx',
        'description': '一般模式密钥',
      },
      {
        'key': 'general_provider_model',
        'value': _generalProviderModel,
        'description': '一般模式文本模型',
      },
      {
        'key': 'general_provider_image_model',
        'value': _generalProviderImageModel,
        'description': '一般模式图片模型',
      },
      {
        'key': 'feedback_ai_api_key',
        'value': 'xxx',
        'description': '反馈 AI 整理密钥',
      },
      {
        'key': 'feedback_ai_model',
        'value': _feedbackAiModel,
        'description': '反馈 AI 整理模型',
      },
      {
        'key': 'feedback_ai_auto_enabled',
        'value': 'false',
        'description': '每 5 分钟自动整理新反馈',
      },
      {
        'key': 'feedback_ai_auto_reply_enabled',
        'value': 'false',
        'description': '自动用 AI 回复草稿回复已整理反馈',
      },
      {
        'key': 'feedback_ai_auto_export_enabled',
        'value': 'true',
        'description': '每日自动导出反馈需求排行榜',
      },
      {
        'key': 'prompt_ai_base_url',
        'value': '',
        'description': '提示词生成与图片识别 AI 服务地址',
      },
      {
        'key': 'prompt_ai_api_key',
        'value': 'xxx',
        'description': '提示词生成与图片识别 AI 密钥',
      },
      {
        'key': 'prompt_ai_model',
        'value': _promptAiModel,
        'description': '提示词生成与图片识别 AI 模型',
      },
      {
        'key': 'email_sender_name',
        'value': '从零开始生图',
        'description': '邮件发件人显示名',
      },
      {
        'key': 'email_code_primary_provider',
        'value': 'claw163',
        'description': '验证码和系统通知主用邮件通道',
      },
      {
        'key': 'email_code_backup_provider',
        'value': 'resend',
        'description': '验证码和系统通知备用邮件通道',
      },
      {
        'key': 'email_code_active_slot',
        'value': 'primary',
        'description': '当前邮件线路',
      },
      {
        'key': 'email_auto_switch_enabled',
        'value': 'false',
        'description': '备用通道成功后是否自动保存当前线路',
      },
      {
        'key': 'openclaw_mail_enabled',
        'value': 'false',
        'description': '是否启用 163 邮箱主通道',
      },
      {
        'key': 'openclaw_mail_user',
        'value': '',
        'description': '主通道发件邮箱',
      },
      {
        'key': 'openclaw_mail_api_key',
        'value': 'xxx',
        'description': '主通道密钥',
      },
      {
        'key': 'resend_base_url',
        'value': 'https://api.resend.com',
        'description': 'Resend API 地址，默认备用通道',
      },
      {
        'key': 'resend_api_key',
        'value': 'xxx',
        'description': '备用通道密钥',
      },
      {
        'key': 'resend_from',
        'value': '从零开始生图 <noreply@mail.6688667.xyz>',
        'description': 'Resend 发件人',
      },
      {
        'key': 'system_notice_email_to',
        'value': '',
        'description': '系统通知邮件收件人，多个邮箱用英文逗号分隔',
      },
      {
        'key': 'notification_retention_days',
        'value': '30',
        'description': '已读通知自动清理天数',
      },
      {
        'key': 'notification_category_limit',
        'value': '50',
        'description': '每类通知最多条数',
      },
      {
        'key': 'hermes_base_url',
        'value': '',
        'description': '兼容邮件服务地址',
      },
      {
        'key': 'hermes_api_key',
        'value': 'xxx',
        'description': '兼容邮件服务密钥',
      },
      {
        'key': 'email_smtp_host',
        'value': '',
        'description': 'SMTP 邮件服务器地址',
      },
      {
        'key': 'email_smtp_port',
        'value': '465',
        'description': 'SMTP 邮件服务器端口',
      },
      {
        'key': 'email_smtp_username',
        'value': '',
        'description': 'SMTP 登录邮箱或用户名',
      },
      {
        'key': 'email_smtp_password',
        'value': 'xxx',
        'description': 'SMTP 登录密码或授权码',
      },
      {
        'key': 'email_smtp_use_ssl',
        'value': 'true',
        'description': 'SMTP 是否使用 SSL 直连',
      },
      {
        'key': 'local_backup_enabled',
        'value': 'false',
        'description': '是否开启本地数据定时备份',
      },
      {
        'key': 'local_backup_interval_hours',
        'value': '24',
        'description': '本地数据自动备份间隔小时',
      },
      {
        'key': 'local_backup_retention_days',
        'value': '14',
        'description': '本地备份文件保留天数',
      },
      {
        'key': 'google_drive_backup_enabled',
        'value': 'false',
        'description': '是否把备份包同步上传到 Google Drive',
      },
      {
        'key': 'google_drive_backup_folder_id',
        'value': '',
        'description': 'Google Drive 目标文件夹 ID',
      },
      {
        'key': 'google_drive_service_account_json',
        'value': 'xxx',
        'description': 'Google Drive 服务账号 JSON',
      },
      {
        'key': 'openlist_backup_primary_enabled',
        'value': 'false',
        'description': '是否同步上传到 OpenList 主用备份',
      },
      {
        'key': 'openlist_backup_primary_webdav_url',
        'value': 'http://openlist:5244/dav',
        'description': 'OpenList 主用 WebDAV 地址',
      },
      {
        'key': 'openlist_backup_primary_public_url',
        'value': 'http://127.0.0.1:5244/dav',
        'description': 'OpenList 主用外网打开地址',
      },
      {
        'key': 'openlist_backup_primary_username',
        'value': 'admin',
        'description': 'OpenList 主用 WebDAV 用户名',
      },
      {
        'key': 'openlist_backup_primary_password',
        'value': 'xxx',
        'description': 'OpenList 主用 WebDAV 密码',
      },
      {
        'key': 'openlist_backup_primary_path',
        'value': '/gateway-backups',
        'description': 'OpenList 主用备份目录',
      },
      {
        'key': 'openlist_backup_secondary_enabled',
        'value': 'false',
        'description': '是否同步上传到 OpenList 备用备份',
      },
      {
        'key': 'openlist_backup_secondary_webdav_url',
        'value': '',
        'description': 'OpenList 备用 WebDAV 地址',
      },
      {
        'key': 'openlist_backup_secondary_public_url',
        'value': '',
        'description': 'OpenList 备用外网打开地址',
      },
      {
        'key': 'openlist_backup_secondary_username',
        'value': '',
        'description': 'OpenList 备用 WebDAV 用户名',
      },
      {
        'key': 'openlist_backup_secondary_password',
        'value': 'xxx',
        'description': 'OpenList 备用 WebDAV 密码',
      },
      {
        'key': 'openlist_backup_secondary_path',
        'value': '/gateway-backups-secondary',
        'description': 'OpenList 备用备份目录',
      },
    ];
    return [
      ...settings,
      ...additions.where((item) => !byKey.containsKey(_text(item['key']))),
    ];
  }

  String _displaySettingValue(Map<String, dynamic> setting) {
    final key = _text(setting['key'], fallback: '');
    final value = _text(setting['value'], fallback: '未设置');
    if (key.contains('api_key') ||
        key.endsWith('_key') ||
        key.endsWith('_password') ||
        key.contains('service_account')) {
      return _maskSecret(value);
    }
    return value;
  }

  String _maskSecret(String value) {
    final text = value.trim();
    if (text.isEmpty || text == '未设置') return '未设置';
    if (text.length <= 6) return '***';
    return '${text.substring(0, 2)}***${text.substring(text.length - 2)}';
  }

  String _settingValue(
    Map<String, Map<String, dynamic>> settings,
    String key, {
    String fallback = '',
  }) {
    final value = settings[key]?['value'];
    return _text(value, fallback: fallback);
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    return (value as List? ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  String _text(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}

class _AdminSection {
  const _AdminSection(this.key, this.label);

  final String key;
  final String label;
}

class _OverviewItem {
  const _OverviewItem(
    this.title,
    this.value,
    this.icon,
    this.key,
    this.subtitle,
  );

  final String title;
  final dynamic value;
  final IconData icon;
  final String key;
  final String subtitle;
}

class _UsersData {
  const _UsersData(this.users, this.groups, this.roles);

  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> roles;
}

class _RolesData {
  const _RolesData(this.roles, this.permissions);

  final List<Map<String, dynamic>> roles;
  final List<Map<String, dynamic>> permissions;
}

class _BackupsData {
  const _BackupsData(this.settings, this.runtime, this.backups);

  final List<Map<String, dynamic>> settings;
  final Map<String, dynamic> runtime;
  final List<Map<String, dynamic>> backups;
}
