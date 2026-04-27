import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/app_update_service.dart';
import '../../core/brand_background.dart';
import '../../core/providers.dart';
import '../admin/admin_screen.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isClearingCache = false;
  bool _isLoggingOut = false;
  bool _isCheckingUpdate = false;
  bool _isDownloadingUpdate = false;
  double? _updateProgress;

  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);
    try {
      await ref.read(imageCacheProvider).clearCache();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片缓存已清理')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '缓存清理失败。'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isClearingCache = false);
      }
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      final client = ref.read(gatewayClientProvider);
      await client.logout();
      ref.read(authStateProvider.notifier).state = null;
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  Future<void> _checkUpdate() async {
    setState(() => _isCheckingUpdate = true);
    try {
      final updateService = ref.read(appUpdateProvider);
      final info = await updateService.checkForUpdate();
      if (!mounted) return;
      if (!info.available) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已是最新版本 ${updateService.currentVersionName}')),
        );
        return;
      }
      await _showUpdateDialog(info);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '检查更新失败。'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  Future<void> _showUpdateDialog(AppUpdateInfo info) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('发现新版本 ${info.latestVersionName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('安装包大小: ${_formatBytes(info.fileSize)}'),
              const SizedBox(height: 8),
              Text(info.releaseNotes),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('稍后'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('下载更新'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _downloadAndInstallUpdate(info);
    }
  }

  Future<void> _downloadAndInstallUpdate(AppUpdateInfo info) async {
    setState(() {
      _isDownloadingUpdate = true;
      _updateProgress = null;
    });
    try {
      final updateService = ref.read(appUpdateProvider);
      final apkFile = await updateService.downloadUpdate(
        info,
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _updateProgress = received / total);
        },
      );
      await updateService.openInstaller(apkFile);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('安装界面已打开')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '更新下载失败。'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingUpdate = false;
          _updateProgress = null;
        });
      }
    }
  }

  void _openAdmin({String? targetView}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminScreen(initialView: targetView),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    final user = ref.watch(authStateProvider);
    final hasSystemManagement = _hasSystemManagement(user);
    final systemTargetView = _systemTargetView(user);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: BrandBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProfileCard(brand, user, hasSystemManagement),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.person_outline, color: brand.primaryColor),
                    title: const Text('个人资料'),
                    subtitle: const Text('查看当前账号、角色与额度'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showProfileDetails(brand, user),
                  ),
                  if (hasSystemManagement) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.admin_panel_settings,
                        color: brand.warningColor,
                      ),
                      title: const Text('系统管理'),
                      subtitle: const Text('原生管理页：用户、密钥、系统设置与审计'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openAdmin(targetView: systemTargetView),
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.palette_outlined, color: brand.primaryColor),
                    title: const Text('主题风格'),
                    subtitle: Text(brand.appTitle),
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: brand.id,
                        items: AppBrands.all
                            .map(
                              (item) => DropdownMenuItem<String>(
                                value: item.id,
                                child: Text(item.appTitle),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            ref.read(brandProvider.notifier).setBrand(value);
                          }
                        },
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.system_update, color: brand.primaryColor),
                    title: const Text('检查更新'),
                    subtitle: Text('当前版本 ${ref.read(appUpdateProvider).currentVersionName}'),
                    trailing: _updateTrailing(),
                    onTap: (_isCheckingUpdate || _isDownloadingUpdate) ? null : _checkUpdate,
                  ),
                  const Divider(height: 1),
                  FutureBuilder<int>(
                    future: ref.read(imageCacheProvider).cacheSizeBytes(),
                    builder: (context, snapshot) {
                      return ListTile(
                        leading: Icon(Icons.cached, color: brand.successColor),
                        title: const Text('图片缓存'),
                        subtitle: Text('当前缓存 ${_formatBytes(snapshot.data ?? 0)}'),
                        trailing: _isClearingCache
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline),
                        onTap: _isClearingCache ? null : _clearCache,
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.logout, color: brand.warningColor),
                    title: const Text('退出登录'),
                    trailing: _isLoggingOut
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                    onTap: _isLoggingOut ? null : _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    AppBrand brand,
    Map<String, dynamic>? user,
    bool hasSystemManagement,
  ) {
    final role = user?['role'] as Map? ?? {};
    final group = user?['group'] as Map? ?? {};
    final quota = user?['quota_summary'] as Map? ?? {};
    final generateQuota = quota['generate'] as Map? ?? {};
    final editQuota = quota['edit'] as Map? ?? {};

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: brand.panelColor.withOpacity(0.15),
                    border: Border.all(color: brand.primaryColor),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, color: brand.primaryColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?['display_name']?.toString() ?? '未知用户',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('@${user?['username'] ?? '-'}'),
                    ],
                  ),
                ),
                if (hasSystemManagement)
                  Icon(Icons.verified_user, color: brand.warningColor),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(brand, '角色', role['name']?.toString() ?? '-'),
                _chip(brand, '用户组', group['name']?.toString() ?? '-'),
                _chip(brand, '生图', _quotaText(generateQuota)),
                _chip(brand, '改图', _quotaText(editQuota)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(AppBrand brand, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: brand.primaryColor.withOpacity(0.6)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$label: $value'),
    );
  }

  void _showProfileDetails(AppBrand brand, Map<String, dynamic>? user) {
    final role = user?['role'] as Map? ?? {};
    final group = user?['group'] as Map? ?? {};
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                user?['display_name']?.toString() ?? '未知用户',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('@${user?['username'] ?? '-'}'),
              const SizedBox(height: 16),
              _profileLine('角色', role['name']?.toString() ?? '-'),
              _profileLine('用户组', group['name']?.toString() ?? '-'),
              _profileLine('登录网关', 'image.6688667.xyz'),
              const SizedBox(height: 12),
              Text(
                '账号资料修改请联系管理员在系统管理中调整。',
                style: TextStyle(color: brand.primaryColor),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _profileLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget? _updateTrailing() {
    if (_isDownloadingUpdate) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: _updateProgress,
        ),
      );
    }
    if (_isCheckingUpdate) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return const Icon(Icons.chevron_right);
  }

  bool _hasSystemManagement(Map<String, dynamic>? user) {
    final role = user?['role'] as Map? ?? {};
    if (role['id'] == 'role_admin') {
      return true;
    }

    final permissions = (user?['permissions'] as List? ?? [])
        .map((item) => item.toString())
        .toSet();
    if (permissions.intersection({
      'settings.view',
      'settings.manage',
      'user.view',
      'group.view',
      'role.view',
      'permission.view',
      'api_key.view',
      'audit.view',
    }).isNotEmpty) {
      return true;
    }

    final menus = (user?['menus'] as List? ?? [])
        .whereType<Map>()
        .map((item) => item['key']?.toString())
        .whereType<String>()
        .toSet();
    return menus.intersection({
      'settings',
      'users',
      'groups',
      'roles',
      'permissions',
      'apiKeys',
      'audit',
    }).isNotEmpty;
  }

  String? _systemTargetView(Map<String, dynamic>? user) {
    final menus = (user?['menus'] as List? ?? [])
        .whereType<Map>()
        .map((item) => item['key']?.toString())
        .whereType<String>()
        .toSet();

    for (final key in [
      'settings',
      'users',
      'groups',
      'roles',
      'apiKeys',
      'audit',
      'permissions',
    ]) {
      if (menus.contains(key)) {
        return key;
      }
    }

    final permissions = (user?['permissions'] as List? ?? [])
        .map((item) => item.toString())
        .toSet();
    if (permissions.contains('settings.view')) return 'settings';
    if (permissions.contains('user.view')) return 'users';
    if (permissions.contains('group.view')) return 'groups';
    if (permissions.contains('role.view')) return 'roles';
    if (permissions.contains('api_key.view')) return 'apiKeys';
    if (permissions.contains('audit.view')) return 'audit';
    if (permissions.contains('permission.view')) return 'permissions';
    return null;
  }

  String _quotaText(Map quota) {
    if (quota['is_unlimited'] == true) {
      return '无限';
    }
    return '${quota['remaining'] ?? 0}/${quota['total'] ?? 0}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
