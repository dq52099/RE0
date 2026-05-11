import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/api_error.dart';
import 'core/app_update_service.dart';
import 'core/brand_background.dart';
import 'core/providers.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const Re0App(),
    ),
  );
}

class Re0App extends ConsumerWidget {
  const Re0App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    return MaterialApp(
      title: '从零开始生图',
      debugShowCheckedModeBanner: false,
      theme: brand.theme,
      home: const _StartupGate(),
    );
  }
}

class _StartupGate extends ConsumerStatefulWidget {
  const _StartupGate();

  @override
  ConsumerState<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<_StartupGate> {
  static const _defaultServerUrl = 'https://image.6688667.xyz';
  late Future<_StartupResult> _future;
  bool _isDownloadingUpdate = false;
  double? _updateProgress;

  @override
  void initState() {
    super.initState();
    _future = _checkSavedAuth();
  }

  AppUpdateInfo _buildForcedUpdateInfo(Map<String, dynamic> data) {
    final service = ref.read(appUpdateProvider);
    final latestVersionNameRaw = data['latest_version_name']?.toString().trim();
    final appNameRaw = data['app_name']?.toString().trim();
    final packageNameRaw = data['package_name']?.toString().trim();
    final available = data['available'] == true;
    final downloadUrl = data['download_url']?.toString().trim() ?? '';
    if (available && downloadUrl.isEmpty) {
      throw StateError('更新包下载地址缺失。');
    }
    final releaseNotes = data['release_notes']?.toString().trim();
    return AppUpdateInfo(
      appName:
          appNameRaw == null || appNameRaw.isEmpty ? service.appName : appNameRaw,
      packageName: packageNameRaw == null || packageNameRaw.isEmpty
          ? service.packageName
          : packageNameRaw,
      latestVersionName: latestVersionNameRaw == null || latestVersionNameRaw.isEmpty
          ? service.currentVersionName
          : latestVersionNameRaw,
      latestVersionCode:
          _asInt(data['latest_version_code'], service.currentVersionCode),
      currentVersionCode:
          _asInt(data['current_version_code'], service.currentVersionCode),
      available: available,
      downloadUrl: downloadUrl,
      fileSize: _asInt(data['file_size']),
      sha256: data['sha256']?.toString() ?? '',
      releaseNotes: (releaseNotes == null || releaseNotes.isEmpty)
          ? '包含最新修复与体验优化。'
          : releaseNotes,
      releaseUrl: data['download_url']?.toString() ?? '',
      forceUpdate: data['force_update'] == true,
    );
  }

  Future<_StartupResult> _checkSavedAuth() async {
    try {
      final client = ref.read(gatewayClientProvider);
      await client.init(_defaultServerUrl);
      final bootstrap = await client.bootstrap();
      final forceUpdate = bootstrap['force_app_update_enabled'] == true;
      if (forceUpdate) {
        try {
          final info = _buildForcedUpdateInfo(
            await client.checkAppUpdate(
              ref.read(appUpdateProvider).appId,
              ref.read(appUpdateProvider).currentVersionCode,
            ),
          );
          if (info.available) {
            return _StartupResult.forceUpdate(info);
          }
        } catch (error) {
          debugPrint('Force update check skipped: $error');
        }
      }
      final auth = await client.checkAuth();
      ref.read(authStateProvider.notifier).state = auth;
      ref.read(energyProvider.notifier).state = auth['quota_summary'];
      ref.read(historyRetentionProvider.notifier).state =
          historyRetentionSummaryFromUser(
        auth,
        fallback: ref.read(historyRetentionProvider),
      );
      return const _StartupResult.home();
    } catch (_) {
      final client = ref.read(gatewayClientProvider);
      await client.clearLocalSession();
      ref.read(authStateProvider.notifier).state = null;
      return const _StartupResult.login();
    }
  }

  Future<void> _downloadForcedUpdate(AppUpdateInfo info) async {
    setState(() {
      _isDownloadingUpdate = true;
      _updateProgress = null;
    });
    try {
      final service = ref.read(appUpdateProvider);
      final apkFile = await service.downloadUpdate(
        info,
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _updateProgress = received / total);
        },
      );
      await service.openInstaller(apkFile);
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupResult>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final result = snapshot.data!;
        final forceUpdateInfo = result.forceUpdateInfo;
        if (forceUpdateInfo != null) {
          return _ForcedUpdateScreen(
            info: forceUpdateInfo,
            isDownloading: _isDownloadingUpdate,
            progress: _updateProgress,
            onDownload: _isDownloadingUpdate
                ? null
                : () => _downloadForcedUpdate(forceUpdateInfo),
          );
        }
        return result.showHome ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}

class _StartupResult {
  const _StartupResult._({
    required this.showHome,
    this.forceUpdateInfo,
  });

  const _StartupResult.home() : this._(showHome: true);
  const _StartupResult.login() : this._(showHome: false);
  const _StartupResult.forceUpdate(AppUpdateInfo info)
      : this._(showHome: false, forceUpdateInfo: info);

  final bool showHome;
  final AppUpdateInfo? forceUpdateInfo;
}

class _ForcedUpdateScreen extends ConsumerWidget {
  const _ForcedUpdateScreen({
    required this.info,
    required this.isDownloading,
    required this.progress,
    required this.onDownload,
  });

  final AppUpdateInfo info;
  final bool isDownloading;
  final double? progress;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: BrandBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: brand.primaryColor.withValues(alpha: 0.28),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: brand.primaryColor.withValues(alpha: 0.14),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              brand.backgroundAsset,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    brand.backgroundOverlay.withValues(
                                      alpha: 0.18,
                                    ),
                                    brand.primaryColor.withValues(
                                      alpha: 0.52,
                                    ),
                                    brand.backgroundOverlay.withValues(
                                      alpha: 0.84,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: colorScheme.surface.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: colorScheme.onSurface.withValues(
                                            alpha: 0.28,
                                          ),
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Image.asset(
                                        'assets/icon.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '版本更新',
                                            style:
                                                textTheme.titleLarge?.copyWith(
                                              color: colorScheme.onSurface,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '请先安装最新版本，再继续使用。',
                                            style: textTheme.bodySmall?.copyWith(
                                              color: colorScheme.onSurface
                                                  .withValues(alpha: 0.88),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _UpdatePill(
                                      icon: Icons.system_update_alt,
                                      label: '新版本',
                                      value: info.latestVersionName,
                                    ),
                                    _UpdatePill(
                                      icon: Icons.inventory_2_outlined,
                                      label: '安装包',
                                      value: _formatBytes(info.fileSize),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color:
                                        colorScheme.surface.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: brand.primaryColor.withValues(
                                        alpha: 0.18,
                                      ),
                                    ),
                                  ),
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxHeight: 170),
                                    child: SingleChildScrollView(
                                      child: Text(
                                        _cleanReleaseNotes(info.releaseNotes),
                                        style: textTheme.bodyMedium,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isDownloading) ...[
                                  const SizedBox(height: 18),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child:
                                        LinearProgressIndicator(value: progress),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: onDownload,
                                  icon: Icon(
                                    isDownloading
                                        ? Icons.downloading
                                        : Icons.download_rounded,
                                  ),
                                  label: Text(
                                    isDownloading ? '正在下载' : '下载安装',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '安装完成后重新打开应用即可继续。',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '大小未知';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var index = 0;
    while (size >= 1024 && index < units.length - 1) {
      size /= 1024;
      index += 1;
    }
    return '${size.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
  }

  String _cleanReleaseNotes(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '包含稳定性修复与体验优化。';
    return trimmed.replaceFirst(RegExp(r'^本次更新：\s*'), '');
  }
}

class _UpdatePill extends StatelessWidget {
  const _UpdatePill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
