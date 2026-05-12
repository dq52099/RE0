import 'dart:async';
import 'dart:math' as math;

import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/app_update_service.dart';
import '../../core/brand_background.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/compact_dropdown_field.dart';
import '../../core/compact_save_notice.dart';
import '../../core/gateway_avatar.dart';
import '../../core/level_rewards_sheet.dart';
import '../../core/points_sheet.dart';
import '../../core/providers.dart';
import '../../core/timezone_reset_hint.dart';
import '../admin/admin_screen.dart';
import '../auth/login_screen.dart';
import '../compendium/image_preview_screen.dart';
import '../feedback/feedback_screen.dart';
import '../gallery/gallery_collections_screen.dart';
import '../notifications/notifications_screen.dart';

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
  bool _isDrawingDailyImage = false;
  double? _updateProgress;
  Future<int>? _cacheSizeFuture;
  Future<Map<String, dynamic>>? _checkInStatusFuture;
  Future<Map<String, dynamic>>? _dailyImageDrawFuture;
  Future<Map<String, dynamic>>? _notificationsFuture;
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
      _checkUpdateSilently(force: true);
    }
  }

  void _refreshCacheSize() {
    _cacheSizeFuture = ref.read(imageCacheProvider).cacheSizeBytes();
    _checkInStatusFuture =
        ref.read(gatewayClientProvider).getDailyCheckInStatus();
    _dailyImageDrawFuture =
        ref.read(gatewayClientProvider).getDailyImageDrawStatus();
    _notificationsFuture = ref.read(gatewayClientProvider).getMyNotifications(
          limit: 20,
        );
  }

  void _refreshDailyImageDrawStatus() {
    setState(() {
      _dailyImageDrawFuture =
          ref.read(gatewayClientProvider).getDailyImageDrawStatus();
    });
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
      ref.read(historyRetentionProvider.notifier).state =
          historyRetentionSummaryFromUser(null);
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
      ref.read(historyRetentionProvider.notifier).state =
          historyRetentionSummaryFromUser(
        result['user'],
        fallback: ref.read(historyRetentionProvider),
      );
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

  Map<String, dynamic> _mapValue(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _mapList(Object? value) {
    return (value as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>?> _drawDailyImage(
      {bool showNotice = true}) async {
    if (_isDrawingDailyImage) return null;
    setState(() => _isDrawingDailyImage = true);
    try {
      final result =
          await ref.read(gatewayClientProvider).performDailyImageDraw();
      final status = _mapValue(result['status']);
      final draw = _mapValue(result['draw']);
      if (!mounted) return null;
      setState(() => _dailyImageDrawFuture = Future.value(status));
      final rarity = draw['rarity']?.toString() ?? 'R';
      final score = draw['quality_score']?.toString() ?? '0';
      if (showNotice) {
        showCenterNotice(context, '今日一图：$rarity · $score 分');
      }
      return status;
    } catch (error) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '抽取每日一图失败。'))),
      );
      return null;
    } finally {
      if (mounted) {
        setState(() => _isDrawingDailyImage = false);
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
      ref.read(historyRetentionProvider.notifier).state =
          historyRetentionSummaryFromUser(
        updated,
        fallback: ref.read(historyRetentionProvider),
      );
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

  Future<void> _checkUpdateSilently({bool force = false}) async {
    if ((!force && _hasAutoCheckedUpdate) ||
        _isCheckingUpdate ||
        _isDownloadingUpdate) {
      return;
    }
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
              Text(_briefReleaseNotes(info.releaseNotes)),
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

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (!mounted) return;
    setState(_refreshCacheSize);
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
      ref.read(historyRetentionProvider.notifier).state =
          historyRetentionSummaryFromUser(
        updated,
        fallback: ref.read(historyRetentionProvider),
      );
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

  Future<void> _bindEmail(Map<String, dynamic>? user) async {
    final email = TextEditingController(text: user?['email']?.toString() ?? '');
    final code = TextEditingController();
    var sending = false;
    var binding = false;
    var cooldownSeconds = 0;
    Timer? cooldownTimer;
    final payload = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void startCooldown() {
              cooldownTimer?.cancel();
              setDialogState(() => cooldownSeconds = 60);
              cooldownTimer =
                  Timer.periodic(const Duration(seconds: 1), (timer) {
                if (!context.mounted) {
                  timer.cancel();
                  return;
                }
                if (cooldownSeconds <= 1) {
                  timer.cancel();
                  setDialogState(() => cooldownSeconds = 0);
                } else {
                  setDialogState(() => cooldownSeconds -= 1);
                }
              });
            }

            Future<void> sendCode() async {
              final emailText = email.text.trim();
              if (emailText.isEmpty) {
                showCenterNotice(context, '请先填写邮箱。');
                return;
              }
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(emailText)) {
                showCenterNotice(context, '邮箱格式不正确。');
                return;
              }
              setDialogState(() => sending = true);
              try {
                final result = await ref
                    .read(gatewayClientProvider)
                    .sendEmailCode(emailText, 'bind');
                if (!context.mounted) return;
                startCooldown();
                final message =
                    result['message']?.toString() ?? '验证码已发送，请查看邮箱。';
                final devCode = result['dev_code']?.toString();
                showCenterNotice(
                  context,
                  devCode == null || devCode.isEmpty
                      ? message
                      : '$message 验证码：$devCode',
                );
              } catch (error) {
                if (!context.mounted) return;
                showCenterNotice(
                  context,
                  friendlyError(error, fallback: '发送邮箱验证码失败。'),
                );
              } finally {
                if (context.mounted) {
                  setDialogState(() => sending = false);
                }
              }
            }

            Future<void> bindNow() async {
              final emailText = email.text.trim();
              final codeText = code.text.trim();
              if (emailText.isEmpty || codeText.isEmpty) {
                showCenterNotice(context, '请填写邮箱和验证码。');
                return;
              }
              if (!RegExp(r'^[^@\s]+@(qq\.com|163\.com|claw\.163\.com)$')
                  .hasMatch(emailText.toLowerCase())) {
                showCenterNotice(
                    context, '当前仅支持 qq.com、163.com 和 claw.163.com 邮箱。');
                return;
              }
              setDialogState(() => binding = true);
              try {
                final updated = await ref
                    .read(gatewayClientProvider)
                    .bindMyEmail(emailText, codeText);
                if (!context.mounted) return;
                Navigator.pop(context, {
                  'email': emailText,
                  'code': codeText,
                  '_updated': 'true',
                });
                ref.read(authStateProvider.notifier).state = updated;
                ref.read(energyProvider.notifier).state =
                    updated['quota_summary'];
                ref.read(historyRetentionProvider.notifier).state =
                    historyRetentionSummaryFromUser(
                  updated,
                  fallback: ref.read(historyRetentionProvider),
                );
                if (mounted) showCenterNotice(this.context, '邮箱已绑定');
              } catch (error) {
                if (!context.mounted) return;
                showCenterNotice(
                  context,
                  friendlyError(error, fallback: '绑定邮箱失败。'),
                );
              } finally {
                if (context.mounted) {
                  setDialogState(() => binding = false);
                }
              }
            }

            return _wideDialog(
              title: '绑定邮箱',
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      helperText: '绑定后可用邮箱密码登录和找回密码',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: code,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '验证码'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed:
                              sending || cooldownSeconds > 0 ? null : sendCode,
                          child: sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(cooldownSeconds > 0
                                  ? '${cooldownSeconds}s'
                                  : '发送邮件'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: binding ? null : bindNow,
                  child: binding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('绑定'),
                ),
              ],
            );
          },
        );
      },
    );
    cooldownTimer?.cancel();
    email.dispose();
    code.dispose();
    if (payload == null || payload['_updated'] == 'true') return;
    try {
      final updated = await ref
          .read(gatewayClientProvider)
          .bindMyEmail(payload['email']!, payload['code']!);
      ref.read(authStateProvider.notifier).state = updated;
      ref.read(energyProvider.notifier).state = updated['quota_summary'];
      ref.read(historyRetentionProvider.notifier).state =
          historyRetentionSummaryFromUser(
        updated,
        fallback: ref.read(historyRetentionProvider),
      );
      if (!mounted) return;
      showCenterNotice(context, '邮箱已绑定');
    } catch (error) {
      if (!mounted) return;
      showCenterNotice(
        context,
        friendlyError(error, fallback: '绑定邮箱失败。'),
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
      resizeToAvoidBottomInset: false,
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
                    ? '已签到，奖励生图 ${reward['generate'] ?? 0} 次，改图 ${reward['edit'] ?? 0} 次\n${resetHintFromResponse(status)}'
                    : '每日可随机获得 5-10 次生图和 2-5 次改图奖励\n${resetHintFromResponse(status)}';
                return _menuCard(
                  child: ListTile(
                    leading: Icon(Icons.calendar_month_outlined,
                        color: brand.successColor),
                    title: const Text('每日签到'),
                    subtitle: _menuSubtitle(subtitle),
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
            _buildDailyImageDrawCard(brand),
            _menuCard(
              child: ListTile(
                leading: Icon(Icons.collections_bookmark_outlined,
                    color: brand.primaryColor),
                title: const Text('我的画廊'),
                subtitle: _menuSubtitle('查看收藏、点赞和自己发布到画廊的作品'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GalleryCollectionsScreen(),
                  ),
                ),
              ),
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: _notificationsFuture,
              builder: (context, snapshot) {
                final unread = int.tryParse(
                      snapshot.data?['unread_count']?.toString() ?? '',
                    ) ??
                    0;
                return _menuCard(
                  child: ListTile(
                    leading: Icon(Icons.notifications_none_outlined,
                        color: brand.primaryColor),
                    title: const Text('通知'),
                    subtitle: _menuSubtitle('评论、点赞、收藏和反馈处理进度'),
                    trailing: _notificationTrailing(unread),
                    onTap: _openNotifications,
                  ),
                );
              },
            ),
            _menuCard(
              child: ListTile(
                leading: Icon(Icons.person_outline, color: brand.primaryColor),
                title: const Text('个人资料'),
                subtitle: _menuSubtitle('查看并修改账号资料、密码与额度'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showProfileDetails(brand, user),
              ),
            ),
            _menuCard(
              child: ListTile(
                leading: Icon(Icons.forum_outlined, color: brand.primaryColor),
                title: const Text('反馈与许愿'),
                subtitle: _menuSubtitle('提交问题、建议，或希望新增的功能、模型、主题和参数'),
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
                  subtitle: _menuSubtitle('原生管理页：用户、密钥、系统设置与审计'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openAdmin(targetView: systemTargetView),
                ),
              ),
            if (hasSystemManagement)
              _menuCard(
                child: ListTile(
                  leading: Icon(
                    Icons.campaign_outlined,
                    color: brand.warningColor,
                  ),
                  title: const Text('公告福利'),
                  subtitle: _menuSubtitle('发布公告，给全员发放生图和改图额度'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openAdmin(targetView: 'announcements'),
                ),
              ),
            _menuCard(
              child: ListTile(
                leading:
                    Icon(Icons.palette_outlined, color: brand.primaryColor),
                title: const Text('主题风格'),
                subtitle: _menuSubtitle(brand.appTitle),
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
                subtitle: _menuSubtitle(
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
                    subtitle: _menuSubtitle(
                        '当前缓存 ${_formatBytes(snapshot.data ?? 0)}'),
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
    final retention = ref.watch(historyRetentionProvider);
    final generateRetention = retention['generate'] as Map? ?? {};
    final editRetention = retention['edit'] as Map? ?? {};

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.62),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
        ),
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
                    client: ref.read(gatewayClientProvider),
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
                _chip(
                  brand,
                  '生图记忆',
                  _retentionText(generateRetention),
                  icon: Icons.collections_bookmark_outlined,
                ),
                _chip(
                  brand,
                  '改图记忆',
                  _retentionText(editRetention),
                  icon: Icons.history_edu_outlined,
                ),
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
      elevation: 0,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.58),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }

  Widget _menuSubtitle(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.58),
            height: 1.25,
          ),
    );
  }

  Widget _notificationTrailing(int unread) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.chevron_right),
        if (unread > 0)
          Positioned(
            right: -4,
            top: -7,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17),
              height: 17,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                unread > 99 ? '99+' : unread.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDailyDrawDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '$month-$day';
  }

  String _dailyDrawStatusText(Map<String, dynamic> status) {
    final drawnToday = status['drawn_today'] == true;
    final todayDraw = _mapValue(status['today_draw']);
    final rarity = todayDraw['rarity']?.toString() ?? 'R';
    final score = todayDraw['quality_score']?.toString() ?? '0';
    if (drawnToday) {
      return '今日已抽 $rarity · $score 分';
    }
    return '今日可抽一次';
  }

  Widget _buildDailyImageDrawCard(AppBrand brand) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dailyImageDrawFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _menuCard(
            child: ListTile(
              leading: Icon(Icons.casino_outlined, color: brand.primaryColor),
              title: const Text('每日一图'),
              subtitle: _menuSubtitle('正在读取今日状态'),
              trailing: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return _menuCard(
            child: ListTile(
              leading: Icon(Icons.casino_outlined, color: brand.warningColor),
              title: const Text('每日一图'),
              subtitle: _menuSubtitle(
                friendlyError(
                  snapshot.error ?? StateError('每日一图状态为空。'),
                  fallback: '每日一图暂时没接通，请稍后重试。',
                ),
              ),
              trailing: Text(
                '重试',
                style: TextStyle(
                  color: brand.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: _refreshDailyImageDrawStatus,
            ),
          );
        }
        final status = snapshot.data ?? const <String, dynamic>{};
        final drawnToday = status['drawn_today'] == true;
        final canDraw = status['can_draw'] == true || !drawnToday;
        final subtitle = drawnToday
            ? '${_dailyDrawStatusText(status)}\n${resetHintFromResponse(status)}'
            : '每天生成一张新的随机主题图，按质量给出 R / SR / SSR / UR\n${resetHintFromResponse(status)}';
        return _menuCard(
          child: ListTile(
            leading: Icon(Icons.casino_outlined, color: brand.primaryColor),
            title: const Text('每日一图'),
            subtitle: _menuSubtitle(subtitle),
            trailing: _isDrawingDailyImage
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    drawnToday ? '查看记录' : '去抽卡',
                    style: TextStyle(
                      color: drawnToday || canDraw
                          ? brand.primaryColor
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.38),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            onTap: _isDrawingDailyImage
                ? null
                : () => _showDailyImageDrawDialog(status),
          ),
        );
      },
    );
  }

  Widget _buildDailyDrawPreview(
    Map<String, dynamic> draw, {
    required AppBrand brand,
    bool isDrawing = false,
  }) {
    late final Widget child;
    if (isDrawing) {
      child = _DailyImageDrawSummon(
        key: const ValueKey('drawing'),
        brand: brand,
        label: '${brand.generateActionLabel}回路展开中',
      );
    } else {
      final imageUrl = draw['image_url']?.toString().trim() ?? '';
      if (imageUrl.isEmpty) {
        child = Container(
          key: const ValueKey('empty'),
          height: 170,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            '抽卡后显示今日图片',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
          ),
        );
      } else {
        child = GestureDetector(
          key: ValueKey(imageUrl),
          onTap: () => _openDailyImagePreview(draw),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                CachedGatewayImage(
                  url: imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  showDownload: false,
                ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: _dailyDrawRarityBadge(draw, brand),
                ),
              ],
            ),
          ),
        );
      }
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final scale = Tween<double>(begin: 0.96, end: 1).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
      child: child,
    );
  }

  Widget _dailyDrawRarityBadge(Map<String, dynamic> draw, AppBrand brand) {
    final rarity = draw['rarity']?.toString() ?? 'R';
    final score = draw['quality_score']?.toString() ?? '0';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: brand.primaryColor.withValues(alpha: 0.54)),
      ),
      child: Text(
        '$rarity · $score 分',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDailyDrawRecordTile(Map<String, dynamic> draw) {
    final imageUrl = draw['image_url']?.toString().trim() ?? '';
    final rarity = draw['rarity']?.toString() ?? 'R';
    final score = draw['quality_score']?.toString() ?? '0';
    final qualityLabel = draw['quality_mode_label']?.toString() ?? 'Auto';
    final modeLabel = draw['image_mode_label']?.toString() ?? '一般';
    final dateLabel = _formatDailyDrawDate(draw['draw_date']?.toString() ?? '');
    return InkWell(
      onTap: imageUrl.isEmpty ? null : () => _openDailyImagePreview(draw),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: imageUrl.isEmpty
                    ? Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.32),
                        child: const Icon(Icons.image_outlined, size: 18),
                      )
                    : CachedGatewayImage(
                        url: imageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        showDownload: false,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$dateLabel · $rarity · $score 分',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$qualityLabel / $modeLabel',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.58),
                        ),
                  ),
                ],
              ),
            ),
            if (imageUrl.isNotEmpty) const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Future<void> _showDailyImageDrawDialog(Map<String, dynamic> status) async {
    var dialogStatus = Map<String, dynamic>.from(status);
    var drawing = false;
    final brand = ref.read(brandProvider);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final drawnToday = dialogStatus['drawn_today'] == true;
            final todayDraw = _mapValue(dialogStatus['today_draw']);
            final recentDraws = _mapList(dialogStatus['recent_draws']);
            final canDraw = dialogStatus['can_draw'] == true || !drawnToday;

            Future<void> drawNow() async {
              if (drawing || !canDraw || drawnToday) return;
              setDialogState(() => drawing = true);
              final startedAt = DateTime.now();
              final nextStatus = await _drawDailyImage(showNotice: false);
              final elapsed = DateTime.now().difference(startedAt);
              const minRevealDelay = Duration(milliseconds: 920);
              if (elapsed < minRevealDelay) {
                await Future.delayed(minRevealDelay - elapsed);
              }
              if (!dialogContext.mounted || !mounted) return;
              if (nextStatus != null) {
                dialogStatus = nextStatus;
              }
              setDialogState(() => drawing = false);
            }

            return _wideDialog(
              title: '每日一图',
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    drawing
                        ? '${brand.generateActionLabel}正在回应'
                        : drawnToday
                            ? '今日已抽到一张图片'
                            : '今日可抽一次，将生成一张新的随机主题图',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  _buildDailyDrawPreview(
                    todayDraw,
                    brand: brand,
                    isDrawing: drawing,
                  ),
                  const SizedBox(height: 12),
                  if (drawing)
                    Text(
                      '命运牌面正在翻开...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: brand.primaryColor.withValues(alpha: 0.82),
                          ),
                    )
                  else if (todayDraw.isEmpty)
                    Text(
                      '评分按图片清晰度、线路模式和生成完成度计算。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.58),
                          ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(
                          brand,
                          '评分',
                          '${todayDraw['rarity']?.toString() ?? 'R'} · ${todayDraw['quality_score']?.toString() ?? 0}',
                          icon: Icons.stars_outlined,
                        ),
                        _chip(
                          brand,
                          '清晰度',
                          todayDraw['quality_mode_label']?.toString() ?? 'Auto',
                          icon: Icons.tune,
                        ),
                        _chip(
                          brand,
                          '线路',
                          todayDraw['image_mode_label']?.toString() ?? '一般',
                          icon: Icons.alt_route_rounded,
                        ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  Text(
                    '最近记录',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if (recentDraws.isEmpty)
                    Text(
                      '暂无记录',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.55),
                          ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.separated(
                        primary: false,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const ClampingScrollPhysics(),
                        itemCount: recentDraws.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 2),
                        itemBuilder: (_, index) =>
                            _buildDailyDrawRecordTile(recentDraws[index]),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('关闭'),
                ),
                FilledButton.icon(
                  onPressed: drawing || drawnToday || !canDraw ? null : drawNow,
                  icon: drawing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.casino_outlined),
                  label: Text(
                    drawnToday ? '今日已抽' : '生成今日一图',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openDailyImagePreview(Map<String, dynamic> draw) {
    final imageUrl = draw['image_url']?.toString().trim() ?? '';
    if (imageUrl.isEmpty) return;
    final rarity = draw['rarity']?.toString() ?? 'R';
    final score = draw['quality_score']?.toString() ?? '0';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImagePreviewScreen(
          showDownload: true,
          items: [
            PreviewImageEntry(
              url: imageUrl,
              title: '每日一图',
              caption: '$rarity · $score 分',
            ),
          ],
        ),
      ),
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
      child: GatewayAvatar(
        avatarUrl: avatarUrl,
        displayName: displayName,
        radius: 40,
        fallback: initial,
        backgroundColor: Colors.transparent,
        textStyle: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
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
              _profileLine(
                '邮箱',
                (user?['email']?.toString().trim().isNotEmpty ?? false)
                    ? '${user?['email']}${user?['email_verified'] == true ? '（已验证）' : '（未验证）'}'
                    : '未绑定',
              ),
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
                  _bindEmail(user);
                },
                icon: const Icon(Icons.alternate_email),
                label: const Text('绑定邮箱'),
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
      'announcement.view',
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
      'announcements',
    }).isNotEmpty;
  }

  String? _systemTargetView(Map<String, dynamic>? user) {
    if (_hasSystemManagement(user)) return 'overview';

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
      'announcements',
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
    if (permissions.contains('announcement.view')) return 'announcements';
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

  String _retentionText(Map quota) {
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

  String _briefReleaseNotes(String value) {
    final lines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(5)
        .toList();
    if (lines.isEmpty) return '包含最新修复与体验优化。';
    return lines.join('\n');
  }
}

class _DailyImageDrawSummon extends StatefulWidget {
  const _DailyImageDrawSummon({
    super.key,
    required this.brand,
    required this.label,
  });

  final AppBrand brand;
  final String label;

  @override
  State<_DailyImageDrawSummon> createState() => _DailyImageDrawSummonState();
}

class _DailyImageDrawSummonState extends State<_DailyImageDrawSummon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = widget.brand;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = _controller.value;
        final wave = math.sin(value * math.pi * 2);
        final pulse = 0.97 + wave * 0.035;
        final cardTilt = wave * 0.07;
        return Container(
          height: 180,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: brand.primaryColor.withValues(alpha: 0.24),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                brand.panelColor.withValues(alpha: 0.26),
                brand.primaryColor.withValues(alpha: 0.16),
                brand.warningColor.withValues(alpha: 0.10),
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: value * math.pi * 2,
                child: Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: brand.primaryColor.withValues(alpha: 0.36),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              Transform.rotate(
                angle: -value * math.pi * 1.4,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: pulse,
                child: Transform.rotate(
                  angle: cardTilt,
                  child: Container(
                    width: 82,
                    height: 108,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          brand.primaryColor.withValues(alpha: 0.88),
                          brand.panelColor.withValues(alpha: 0.84),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.34),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: brand.primaryColor.withValues(alpha: 0.26),
                          blurRadius: 26,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: Colors.white.withValues(alpha: 0.94),
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '今日',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
