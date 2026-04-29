import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/app_update_service.dart';
import '../../core/brand_background.dart';
import '../../core/compact_dropdown_field.dart';
import '../../core/compact_save_notice.dart';
import '../../core/level_rewards_sheet.dart';
import '../../core/points_sheet.dart';
import '../../core/providers.dart';
import '../../core/timezone_reset_hint.dart';
import '../admin/admin_screen.dart';
import '../auth/login_screen.dart';
import '../compendium/image_preview_screen.dart';
import '../feedback/feedback_screen.dart';
import '../gallery/gallery_collections_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.refreshToken = 0});

  final int refreshToken;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _picker = ImagePicker();
  bool _isClearingCache = false;
  bool _isLoggingOut = false;
  bool _isCheckingUpdate = false;
  bool _isDownloadingUpdate = false;
  bool _isUpdatingAvatar = false;
  bool _isCheckingIn = false;
  double? _updateProgress;
  Future<int>? _cacheSizeFuture;
  Future<Map<String, dynamic>>? _checkInStatusFuture;
  AppUpdateInfo? _latestUpdateInfo;
  bool _hasAutoCheckedUpdate = false;

  @override
  void initState() {
    super.initState();
    _refreshCacheSize();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      setState(_refreshCacheSize);
      _checkUpdateSilentlyOnce();
    }
  }

  void _refreshCacheSize() {
    _cacheSizeFuture = ref.read(imageCacheProvider).cacheSizeBytes();
    _checkInStatusFuture =
        ref.read(gatewayClientProvider).getDailyCheckInStatus();
  }

  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);
    try {
      await ref.read(imageCacheProvider).clearCache();
      if (!mounted) return;
      setState(_refreshCacheSize);
      showCenterNotice(context, '图片缓存已清理');
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

  Future<void> _dailyCheckIn() async {
    if (_isCheckingIn) return;
    setState(() => _isCheckingIn = true);
    try {
      final result =
          await ref.read(gatewayClientProvider).performDailyCheckIn();
      ref.read(authStateProvider.notifier).state = result['user'];
      ref.read(energyProvider.notifier).state = result['user']['quota_summary'];
      if (!mounted) return;
      setState(_refreshCacheSize);
      final reward = result['checkin']['today_reward'] as Map? ?? {};
      showCenterNotice(
        context,
        '签到成功，+${reward['generate'] ?? 0} 生图 / +${reward['edit'] ?? 0} 改图 / +5 积分',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '签到失败。'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isCheckingIn = false);
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1200,
    );
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressFormat: ImageCompressFormat.png,
      maxWidth: 1024,
      maxHeight: 1024,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: '裁剪头像',
          toolbarColor: ref.read(brandProvider).primaryColor,
          lockAspectRatio: true,
          hideBottomControls: false,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: ref.read(brandProvider).primaryColor,
          initAspectRatio: CropAspectRatioPreset.square,
          cropStyle: CropStyle.circle,
          aspectRatioPresets: [CropAspectRatioPreset.square],
        ),
      ],
    );
    if (cropped == null) return;

    setState(() => _isUpdatingAvatar = true);
    try {
      final updated = await ref.read(gatewayClientProvider).updateMyAvatar(
            cropped.path,
          );
      ref.read(authStateProvider.notifier).state = updated;
      ref.read(energyProvider.notifier).state = updated['quota_summary'];
      if (!mounted) return;
      showCenterNotice(context, '头像已更新');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '头像上传失败。'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAvatar = false);
      }
    }
  }

  Future<void> _checkUpdate() async {
    setState(() => _isCheckingUpdate = true);
    try {
      final updateService = ref.read(appUpdateProvider);
      final info = await updateService.checkForUpdate();
      if (!mounted) return;
      setState(() => _latestUpdateInfo = info);
      if (!info.available) {
        showCenterNotice(context, '已是最新版本 ${updateService.currentVersionName}');
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

  Future<void> _checkUpdateSilentlyOnce() async {
    if (_hasAutoCheckedUpdate || _isCheckingUpdate || _isDownloadingUpdate)
      return;
    _hasAutoCheckedUpdate = true;
    try {
      final info = await ref.read(appUpdateProvider).checkForUpdate();
      if (!mounted) return;
      setState(() => _latestUpdateInfo = info);
    } catch (_) {
      // Silent session check should not interrupt the profile page.
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
      showCenterNotice(context, '安装界面已打开');
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

  void _openFeedback() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FeedbackScreen()),
    );
  }

  void _openAvatarPreview(Map<String, dynamic>? user) {
    final avatarUrl = user?['avatar_url']?.toString().trim() ?? '';
    if (avatarUrl.isEmpty) {
      showCenterNotice(context, '当前没有头像');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImagePreviewScreen(
          showDownload: false,
          items: [
            PreviewImageEntry(
              url: avatarUrl,
              title: user?['display_name']?.toString() ?? '头像',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editProfile(Map<String, dynamic>? user) async {
    final username =
        TextEditingController(text: user?['username']?.toString() ?? '');
    final displayName =
        TextEditingController(text: user?['display_name']?.toString() ?? '');
    final canEditUsername = user?['can_edit_username'] != false;
    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return _wideDialog(
          title: '编辑个人资料',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: username,
                enabled: canEditUsername,
                decoration: InputDecoration(
                  labelText: '账号',
                  helperText:
                      canEditUsername ? '可使用小写字母、数字、下划线或短横线' : '当前账号不允许修改账号名',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: displayName,
                decoration: const InputDecoration(labelText: '显示名称'),
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
                final nextUsername = username.text.trim();
                final nextDisplayName = displayName.text.trim();
                if (nextUsername.isEmpty || nextDisplayName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('账号和显示名称不能为空。')),
                  );
                  return;
                }
                if (nextUsername.length < 4 || nextUsername.length > 24) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('账号长度需为 4 到 24 位。')),
                  );
                  return;
                }
                if (!RegExp(r'^[a-z][a-z0-9_-]{3,23}$')
                    .hasMatch(nextUsername)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('账号需以小写字母开头，只允许小写字母、数字、下划线和短横线。'),
                    ),
                  );
                  return;
                }
                if (nextDisplayName.length < 2 || nextDisplayName.length > 32) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('显示名称长度需为 2 到 32 个字符。')),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'username': nextUsername,
                  'display_name': nextDisplayName,
                });
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (payload == null) return;
    try {
      final updated = await ref.read(gatewayClientProvider).updateMyProfile(
            payload['username']!,
            payload['display_name']!,
          );
      ref.read(authStateProvider.notifier).state = updated;
      ref.read(energyProvider.notifier).state = updated['quota_summary'];
      if (!mounted) return;
      showCenterNotice(context, '个人资料已保存');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '个人资料保存失败。'))),
      );
    }
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return _wideDialog(
          title: '修改密码',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: '当前密码'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '新密码',
                  helperText: '至少 10 位，包含大小写字母、数字和特殊字符',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: '确认新密码'),
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
                if (current.text.isEmpty || next.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写当前密码和新密码。')),
                  );
                  return;
                }
                if (next.text.length < 10) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('新密码至少需要 10 位。')),
                  );
                  return;
                }
                if (next.text != confirm.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('两次输入的新密码不一致。')),
                  );
                  return;
                }
                Navigator.pop(context, {
                  'current_password': current.text,
                  'new_password': next.text,
                });
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    if (payload == null) return;
    try {
      await ref.read(gatewayClientProvider).changeMyPassword(
            payload['current_password']!,
            payload['new_password']!,
          );
      if (!mounted) return;
      showCenterNotice(context, '密码已修改');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '密码修改失败。'))),
      );
    }
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
            FutureBuilder<Map<String, dynamic>>(
              future: _checkInStatusFuture,
              builder: (context, snapshot) {
                final status = snapshot.data ?? const <String, dynamic>{};
                final signedToday = status['signed_today'] == true;
                final reward = (status['today_reward'] as Map?) ??
                    const <String, dynamic>{};
                final subtitle = signedToday
                    ? '今日已签到，奖励生图 ${reward['generate'] ?? 0} 次，改图 ${reward['edit'] ?? 0} 次\n${resetHintFromResponse(status)}'
                    : '每日可随机获得 5-10 次生图和 2-5 次改图奖励\n${resetHintFromResponse(status)}';
                return _menuCard(
                  child: ListTile(
                    leading: Icon(Icons.calendar_month_outlined,
                        color: brand.successColor),
                    title: const Text('每日签到'),
                    subtitle: Text(subtitle),
                    trailing: _isCheckingIn
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            signedToday ? '已签到' : '去签到',
                            style: TextStyle(
                              color: signedToday
                                  ? brand.successColor
                                  : brand.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                    onTap:
                        (_isCheckingIn || signedToday) ? null : _dailyCheckIn,
                  ),
                );
              },
            ),
            _menuCard(
              child: ListTile(
                leading: Icon(Icons.collections_bookmark_outlined,
                    color: brand.primaryColor),
                title: const Text('我的画廊'),
                subtitle: const Text('查看收藏、点赞和自己发布到画廊的作品'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GalleryCollectionsScreen(),
                  ),
                ),
              ),
            ),
            _menuCard(
              child: ListTile(
                leading: Icon(Icons.person_outline, color: brand.primaryColor),
                title: const Text('个人资料'),
                subtitle: const Text('查看并修改账号资料、密码与额度'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showProfileDetails(brand, user),
              ),
            ),
            if (!hasSystemManagement)
              _menuCard(
                child: ListTile(
                  leading:
                      Icon(Icons.forum_outlined, color: brand.primaryColor),
                  title: const Text('反馈与许愿'),
                  subtitle: const Text('提交问题、建议，或希望新增的功能、模型、主题和参数'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openFeedback,
                ),
              ),
            if (hasSystemManagement)
              _menuCard(
                child: ListTile(
                  leading: Icon(
                    Icons.admin_panel_settings,
                    color: brand.warningColor,
                  ),
                  title: const Text('系统管理'),
                  subtitle: const Text('原生管理页：用户、密钥、系统设置与审计'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openAdmin(targetView: systemTargetView),
                ),
              ),
            _menuCard(
              child: ListTile(
                leading:
                    Icon(Icons.palette_outlined, color: brand.primaryColor),
                title: const Text('主题风格'),
                subtitle: Text(brand.appTitle),
                trailing: SizedBox(
                  width: 126,
                  child: CompactDropdownField<String>(
                    label: '主题',
                    value: brand.id,
                    width: 126,
                    menuWidth: 126,
                    items: AppBrands.all
                        .map(
                          (item) => CompactDropdownField.centeredItem<String>(
                            item.id,
                            item.appTitle,
                            context,
                          ),
                        )
                        .toList(),
                    selectedLabels:
                        AppBrands.all.map((item) => item.appTitle).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(brandProvider.notifier).setBrand(value);
                      }
                    },
                  ),
                ),
              ),
            ),
            _menuCard(
              child: ListTile(
                leading: Icon(Icons.system_update, color: brand.primaryColor),
                title: const Text('检查更新'),
                subtitle: Text(
                    '当前版本 ${ref.read(appUpdateProvider).currentVersionName}'),
                trailing: _updateTrailing(),
                onTap: (_isCheckingUpdate || _isDownloadingUpdate)
                    ? null
                    : _checkUpdate,
              ),
            ),
            FutureBuilder<int>(
              future: _cacheSizeFuture,
              builder: (context, snapshot) {
                return _menuCard(
                  child: ListTile(
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
                  ),
                );
              },
            ),
            _menuCard(
              child: ListTile(
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
    final quota = user?['quota_summary'] as Map? ?? {};
    final levelInfo = user?['level_info'] as Map? ?? {};
    final generateQuota = quota['generate'] as Map? ?? {};
    final editQuota = quota['edit'] as Map? ?? {};

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openAvatarPreview(user),
                      child: _avatar(user, brand),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        elevation: 4,
                        shadowColor: Colors.black.withValues(alpha: 0.16),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap:
                              _isUpdatingAvatar ? null : _pickAndUploadAvatar,
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: Center(
                              child: _isUpdatingAvatar
                                  ? const SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Icon(
                                      Icons.edit,
                                      size: 15,
                                      color: brand.primaryColor,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isUpdatingAvatar ? null : _pickAndUploadAvatar,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('上传或更换头像'),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  brand,
                  '等级',
                  levelInfo['label']?.toString() ?? 'LV0',
                  icon: Icons.workspace_premium_outlined,
                  onTap: () => showLevelRewardsSheet(
                    context,
                    levelInfo,
                    accentColor: brand.primaryColor,
                  ),
                ),
                _chip(
                  brand,
                  '积分',
                  '${user?['points'] ?? 0}',
                  icon: Icons.toll_outlined,
                  onTap: () => showPointsSheet(
                    context,
                    ref.read(gatewayClientProvider).getPointsSummary(),
                    accentColor: brand.primaryColor,
                  ),
                ),
                _chip(brand, '生图', _quotaText(generateQuota)),
                _chip(brand, '改图', _quotaText(editQuota)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(
    AppBrand brand,
    String label,
    String value, {
    IconData? icon,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: brand.primaryColor.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: $value'),
          if (icon != null) ...[
            const SizedBox(width: 6),
            Icon(icon, size: 15, color: brand.primaryColor),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: content,
    );
  }

  Widget _menuCard({required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _avatar(Map<String, dynamic>? user, AppBrand brand) {
    final avatarUrl = user?['avatar_url']?.toString().trim() ?? '';
    final displayName = user?['display_name']?.toString().trim() ?? '';
    final initial = displayName.isNotEmpty ? displayName.substring(0, 1) : '图';
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: brand.panelColor.withValues(alpha: 0.18),
        border: Border.all(color: brand.primaryColor),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.isEmpty
          ? Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.person,
                color: brand.primaryColor,
              ),
            ),
    );
  }

  Widget _wideDialog({
    required String title,
    required Widget content,
    required List<Widget> actions,
  }) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(child: content),
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
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _editProfile(user);
                },
                icon: const Icon(Icons.edit),
                label: const Text('编辑资料'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _changePassword();
                },
                icon: const Icon(Icons.lock_reset),
                label: const Text('修改密码'),
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
    final hasUpdate = _latestUpdateInfo?.available == true;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.chevron_right),
        if (hasUpdate)
          Positioned(
            right: -1,
            top: -1,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
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
      'feedback.view',
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
      'feedback',
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
      'feedback',
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
    if (permissions.contains('feedback.view')) return 'feedback';
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
