import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/brand_background.dart';
import '../../core/providers.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key, this.initialView});

  final String? initialView;

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  int _revision = 0;

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

    final initialIndex = sections.indexWhere((item) => item.key == widget.initialView);
    return DefaultTabController(
      key: ValueKey(sections.map((item) => item.key).join('|')),
      length: sections.length,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('系统管理'),
          bottom: TabBar(
            isScrollable: true,
            tabs: sections.map((item) => Tab(text: item.label)).toList(),
          ),
        ),
        body: BrandBackground(
          child: TabBarView(
            children: sections
                .map(
                  (item) => KeyedSubtree(
                    key: ValueKey('${item.key}-$_revision'),
                    child: _sectionBody(context, brand, item, user),
                  ),
                )
                .toList(),
          ),
        ),
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
    if (isAdmin || permissions.contains('settings.view') || menus.contains('settings')) {
      sections.add(const _AdminSection('overview', '概览'));
    }
    if (isAdmin || permissions.contains('user.view') || menus.contains('users')) {
      sections.add(const _AdminSection('users', '用户'));
    }
    if (isAdmin || permissions.contains('group.view') || menus.contains('groups')) {
      sections.add(const _AdminSection('groups', '用户组'));
    }
    if (isAdmin || permissions.contains('role.view') || menus.contains('roles')) {
      sections.add(const _AdminSection('roles', '角色'));
    }
    if (isAdmin || permissions.contains('permission.view') || menus.contains('permissions')) {
      sections.add(const _AdminSection('permissions', '权限'));
    }
    if (isAdmin || permissions.contains('api_key.view') || menus.contains('apiKeys')) {
      sections.add(const _AdminSection('apiKeys', '密钥'));
    }
    if (isAdmin || permissions.contains('settings.view') || menus.contains('settings')) {
      sections.add(const _AdminSection('settings', '设置'));
    }
    if (isAdmin || permissions.contains('audit.view') || menus.contains('audit')) {
      sections.add(const _AdminSection('audit', '审计'));
    }
    return sections;
  }

  Widget _sectionBody(
    BuildContext context,
    AppBrand brand,
    _AdminSection section,
    Map<String, dynamic>? user,
  ) {
    switch (section.key) {
      case 'overview':
        return _overviewPage(brand);
      case 'users':
        return _usersPage(brand, canManage: _can(user, 'user.manage'));
      case 'groups':
        return _groupsPage(brand, canManage: _can(user, 'group.manage'));
      case 'roles':
        return _rolesPage(brand, canManage: _can(user, 'role.manage'));
      case 'permissions':
        return _permissionsPage(brand);
      case 'apiKeys':
        return _apiKeysPage(brand, canManage: _can(user, 'api_key.manage'));
      case 'settings':
        return _settingsPage(brand, canManage: _can(user, 'settings.manage'));
      case 'audit':
        return _auditPage(brand);
      default:
        return const Center(child: Text('未知管理页'));
    }
  }

  Widget _overviewPage(AppBrand brand) {
    return _futureSection<Map<String, dynamic>>(
      future: ref.read(gatewayClientProvider).adminOverview(),
      builder: (overview) {
        final items = [
          ('用户', overview['user_count']),
          ('用户组', overview['group_count']),
          ('角色', overview['role_count']),
          ('可用密钥', overview['active_api_key_count']),
        ];
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.45,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item.$1, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      '${item.$2 ?? 0}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: brand.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _usersPage(AppBrand brand, {required bool canManage}) {
    return _futureSection<_UsersData>(
      future: _loadUsersData(),
      builder: (data) {
        return _adminList(
          action: canManage
              ? FilledButton.icon(
                  onPressed: () => _editUser(null, data),
                  icon: const Icon(Icons.person_add),
                  label: const Text('新增用户'),
                )
              : null,
          children: data.users.map((user) {
            final quota = _map(user['quota_summary']);
            final retention = _map(user['history_retention_summary']);
            return _infoCard(
              title: '${_text(user['display_name'])} (${_text(user['username'])})',
              subtitle: '角色: ${_text(user['role_name'])}  用户组: ${_text(user['group_name'])}',
              active: user['is_active'] == true,
              trailing: canManage
                  ? IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editUser(user, data),
                    )
                  : null,
              lines: [
                _quotaLine('生图', _map(quota['generate'])),
                _quotaLine('改图', _map(quota['edit'])),
                '生图保留: ${_text(retention['generate'])}',
                '改图保留: ${_text(retention['edit'])}',
              ],
            );
          }).toList(),
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
                '默认生图额度: ${_text(group['default_generate_quota'])}',
                '默认改图额度: ${_text(group['default_edit_quota'])}',
                '默认生图保留: ${_text(group['default_generate_history_retention'])}',
                '默认改图保留: ${_text(group['default_edit_history_retention'])}',
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
                'Key: ${_text(item['masked_key'])}',
                '最近使用: ${_text(item['last_used_at'], fallback: '暂无')}',
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
        final settings = _mapList(data['settings']);
        final runtime = _map(data['runtime_status']);
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
            ...settings.map((setting) {
              return _infoCard(
                title: _text(setting['key']),
                subtitle: _text(setting['description']),
                lines: ['当前值: ${_text(setting['value'], fallback: '未设置')}'],
              );
            }),
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
              subtitle: '${_text(log['actor_username'], fallback: '系统')}  ${_text(log['created_at'])}',
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

  Future<List<Map<String, dynamic>>> _loadMapList(Future<List<dynamic>> future) async {
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

  Widget _infoCard({
    required String title,
    String? subtitle,
    List<String> lines = const [],
    bool? active,
    String? badge,
    Widget? trailing,
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
        color: Theme.of(context).colorScheme.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Widget _pill(String text) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ref.read(brandProvider).primaryColor.withOpacity(0.16),
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
                      color: brand.primaryColor.withOpacity(0.14),
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
    final username = TextEditingController(text: _text(user?['username'], fallback: ''));
    final displayName = TextEditingController(text: _text(user?['display_name'], fallback: ''));
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
                TextField(controller: username, decoration: const InputDecoration(labelText: '用户名')),
                const SizedBox(height: 12),
                TextField(controller: displayName, decoration: const InputDecoration(labelText: '显示名称')),
                const SizedBox(height: 12),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: InputDecoration(labelText: user == null ? '初始密码' : '密码留空不修改'),
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
                TextField(
                  controller: generateQuota,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '生图额度覆盖'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: editQuota,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '改图额度覆盖'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: generateHistoryRetention,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '生图历史保留覆盖'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: editHistoryRetention,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '改图历史保留覆盖'),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: active,
                  onChanged: (value) => setDialogState(() => active = value ?? true),
                  title: const Text('启用账号'),
                ),
                CheckboxListTile(
                  value: canEditUsername,
                  onChanged: (value) => setDialogState(() => canEditUsername = value ?? true),
                  title: const Text('允许修改用户名'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              FilledButton(
                onPressed: () {
                  final body = {
                    'username': username.text.trim(),
                    'display_name': displayName.text.trim(),
                    'role_id': roleId,
                    'group_id': groupId,
                    'is_active': active,
                    'can_edit_username': canEditUsername,
                    'generate_quota_total_override': _nullableInt(generateQuota.text),
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
    await _save(() => ref.read(gatewayClientProvider).saveAdminUser(user?['id']?.toString(), payload), '用户已保存。');
  }

  Future<void> _editGroup(Map<String, dynamic>? group) async {
    final name = TextEditingController(text: _text(group?['name'], fallback: ''));
    final description = TextEditingController(text: _text(group?['description'], fallback: ''));
    final generateQuota = TextEditingController(text: _text(group?['default_generate_quota'], fallback: '10'));
    final editQuota = TextEditingController(text: _text(group?['default_edit_quota'], fallback: '5'));
    final generateHistoryRetention = TextEditingController(
      text: _text(group?['default_generate_history_retention'], fallback: '5'),
    );
    final editHistoryRetention = TextEditingController(
      text: _text(group?['default_edit_history_retention'], fallback: '3'),
    );
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
          decoration: const InputDecoration(labelText: '默认生图历史保留'),
        ),
        TextField(
          controller: editHistoryRetention,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '默认改图历史保留'),
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
        'is_active': active,
      },
    );
    if (payload == null) return;
    await _save(() => ref.read(gatewayClientProvider).saveAdminGroup(group?['id']?.toString(), payload), '用户组已保存。');
  }

  Future<void> _editRole(Map<String, dynamic>? role, _RolesData data) async {
    final name = TextEditingController(text: _text(role?['name'], fallback: ''));
    final description = TextEditingController(text: _text(role?['description'], fallback: ''));
    final selected = (role?['permissions'] as List? ?? []).map((item) => item.toString()).toSet();
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
                  TextField(controller: name, decoration: const InputDecoration(labelText: '名称')),
                  const SizedBox(height: 12),
                  TextField(controller: description, decoration: const InputDecoration(labelText: '描述')),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value ?? true),
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
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
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
    await _save(() => ref.read(gatewayClientProvider).saveAdminRole(role?['id']?.toString(), payload), '角色已保存。');
  }

  Future<void> _editApiKey(Map<String, dynamic>? item) async {
    final name = TextEditingController(text: _text(item?['name'], fallback: ''));
    final description = TextEditingController(text: _text(item?['description'], fallback: ''));
    final rawKey = TextEditingController();
    var active = item?['is_active'] != false;
    final payload = await _basicEntityDialog(
      title: item == null ? '新增密钥' : '编辑密钥',
      name: name,
      description: description,
      extraFields: [
        TextField(
          controller: rawKey,
          decoration: InputDecoration(labelText: item == null ? 'Key 值' : '新 Key，留空不轮换'),
        ),
      ],
      active: active,
      onActiveChanged: (value) => active = value,
      payloadBuilder: () => {
        'name': name.text.trim(),
        'description': description.text.trim(),
        'is_active': active,
        if (item == null) 'raw_key': rawKey.text.trim(),
        if (item != null && rawKey.text.trim().isNotEmpty) '_rotate_to': rawKey.text.trim(),
      },
    );
    if (payload == null) return;
    final rotateTo = payload.remove('_rotate_to')?.toString();
    await _save(() async {
      await ref.read(gatewayClientProvider).saveAdminApiKey(item?['id']?.toString(), payload);
      if (item != null && rotateTo != null && rotateTo.isNotEmpty) {
        final result = await ref.read(gatewayClientProvider).rotateAdminApiKey(_text(item['id']), rotateTo);
        if (mounted) _showMessage('密钥已轮换，请立即保存: ${_text(result['raw_key'])}');
      }
    }, '密钥已保存。');
  }

  Future<void> _editSettings(Map<String, dynamic> data) async {
    final byKey = {
      for (final item in _mapList(data['settings'])) _text(item['key']): item,
    };
    final uiTitle = TextEditingController(text: _settingValue(byKey, 'ui_title'));
    final externalBase = TextEditingController(text: _settingValue(byKey, 'external_access_base_url'));
    final providerBase = TextEditingController(text: _settingValue(byKey, 'provider_base_url'));
    final providerKey = TextEditingController();
    final providerModel = TextEditingController(text: _settingValue(byKey, 'provider_model'));
    final providerTimeout = TextEditingController(text: _settingValue(byKey, 'provider_timeout_seconds'));
    final instructions = TextEditingController(text: _settingValue(byKey, 'provider_instructions'));
    var profile = _settingValue(byKey, 'provider_image_profile', fallback: 'gpt-image-2');
    var responseFormat = _settingValue(byKey, 'default_response_format', fallback: 'url');
    var quality = _settingValue(byKey, 'default_image_quality', fallback: 'high');
    var background = _settingValue(byKey, 'default_image_background', fallback: 'auto');
    var outputFormat = _settingValue(byKey, 'default_image_output_format', fallback: 'png');
    var allowRegistration = _settingValue(byKey, 'allow_public_registration', fallback: 'true').toLowerCase() == 'true';

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return _adminDialog(
            title: '系统设置',
            icon: Icons.tune,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: uiTitle, decoration: const InputDecoration(labelText: '界面标题')),
                const SizedBox(height: 12),
                TextField(controller: externalBase, decoration: const InputDecoration(labelText: '外部访问地址')),
                const SizedBox(height: 12),
                TextField(controller: providerBase, decoration: const InputDecoration(labelText: '上游地址')),
                const SizedBox(height: 12),
                TextField(controller: providerKey, decoration: const InputDecoration(labelText: '上游 Key，留空不修改')),
                const SizedBox(height: 12),
                TextField(controller: providerModel, decoration: const InputDecoration(labelText: '模型')),
                const SizedBox(height: 12),
                _stringDropdown('图片档位', profile, const ['gpt-image-2', 'gpt-image-1'], (value) => setDialogState(() => profile = value)),
                const SizedBox(height: 12),
                TextField(controller: providerTimeout, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '超时时间秒')),
                const SizedBox(height: 12),
                _stringDropdown('响应格式', responseFormat, const ['url', 'b64_json'], (value) => setDialogState(() => responseFormat = value)),
                const SizedBox(height: 12),
                _stringDropdown('默认质量', quality, const ['auto', 'low', 'medium', 'high'], (value) => setDialogState(() => quality = value)),
                const SizedBox(height: 12),
                _stringDropdown('默认背景', background, const ['auto', 'opaque', 'transparent'], (value) => setDialogState(() => background = value)),
                const SizedBox(height: 12),
                _stringDropdown('输出格式', outputFormat, const ['png', 'jpeg', 'webp'], (value) => setDialogState(() => outputFormat = value)),
                const SizedBox(height: 12),
                TextField(controller: instructions, maxLines: 3, decoration: const InputDecoration(labelText: '上游指令')),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: allowRegistration,
                  onChanged: (value) => setDialogState(() => allowRegistration = value ?? true),
                  title: const Text('允许公开注册'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              FilledButton(
                onPressed: () => Navigator.pop(context, {
                  'ui_title': uiTitle.text.trim(),
                  'external_access_base_url': externalBase.text.trim(),
                  'provider_base_url': providerBase.text.trim(),
                  'provider_api_key': providerKey.text.trim(),
                  'provider_model': providerModel.text.trim(),
                  'provider_image_profile': profile,
                  'provider_timeout_seconds': int.tryParse(providerTimeout.text),
                  'default_response_format': responseFormat,
                  'default_image_quality': quality,
                  'default_image_background': background,
                  'default_image_output_format': outputFormat,
                  'provider_instructions': instructions.text.trim(),
                  'allow_public_registration': allowRegistration,
                }),
                child: const Text('保存'),
              ),
            ],
          );
        },
      ),
    );
    if (payload == null) return;
    await _save(() => ref.read(gatewayClientProvider).saveAdminSystemSettings(payload), '系统设置已保存。');
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
                TextField(controller: name, decoration: const InputDecoration(labelText: '名称')),
                const SizedBox(height: 12),
                TextField(controller: description, decoration: const InputDecoration(labelText: '描述')),
                const SizedBox(height: 12),
                ...extraFields.expand((field) => [field, const SizedBox(height: 12)]),
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
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, payloadBuilder()), child: const Text('保存')),
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
      value: value.isEmpty ? null : value,
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
    void Function(String value) onChanged,
  ) {
    final safeValue = items.contains(value) ? value : items.first;
    return DropdownButtonFormField<String>(
      value: safeValue,
      decoration: InputDecoration(labelText: label),
      items: items
          .map((item) => DropdownMenuItem<String>(value: item, child: Text(item)))
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

  String _quotaLine(String label, Map<String, dynamic> quota) {
    if (quota['is_unlimited'] == true) {
      return '$label: 无限，已用 ${_text(quota['used'], fallback: '0')}';
    }
    return '$label: ${_text(quota['total'], fallback: '0')} / 已用 ${_text(quota['used'], fallback: '0')} / 剩余 ${_text(quota['remaining'], fallback: '0')}';
  }

  int? _nullableInt(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
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
