import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/api_error.dart';
import 'core/app_update_service.dart';
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

  void _retryStartup() {
    setState(() {
      _future = _checkSavedAuth();
    });
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
          return _StartupResult.forceUpdateError(
            friendlyError(
              error,
              fallback: '更新检查失败，请保持联网后重试。',
            ),
          );
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
        final forceUpdateError = result.forceUpdateError;
        if (forceUpdateInfo != null || forceUpdateError != null) {
          return _ForcedUpdateScreen(
            info: forceUpdateInfo,
            errorMessage: forceUpdateError,
            isDownloading: _isDownloadingUpdate,
            progress: _updateProgress,
            onDownload:
                _isDownloadingUpdate || forceUpdateInfo == null
                    ? null
                    : () => _downloadForcedUpdate(forceUpdateInfo),
            onRetry: _isDownloadingUpdate || forceUpdateError == null
                ? null
                : _retryStartup,
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
    this.forceUpdateError,
  });

  const _StartupResult.home() : this._(showHome: true);
  const _StartupResult.login() : this._(showHome: false);
  const _StartupResult.forceUpdate(AppUpdateInfo info)
      : this._(showHome: false, forceUpdateInfo: info);
  const _StartupResult.forceUpdateError(String message)
      : this._(showHome: false, forceUpdateError: message);

  final bool showHome;
  final AppUpdateInfo? forceUpdateInfo;
  final String? forceUpdateError;
}

class _ForcedUpdateScreen extends StatelessWidget {
  const _ForcedUpdateScreen({
    this.info,
    this.errorMessage,
    required this.isDownloading,
    required this.progress,
    required this.onDownload,
    required this.onRetry,
  });

  final AppUpdateInfo? info;
  final String? errorMessage;
  final bool isDownloading;
  final double? progress;
  final VoidCallback? onDownload;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            const ModalBarrier(dismissible: false, color: Colors.black54),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Material(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              Icons.system_update_alt,
                              size: 48,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              info != null
                                  ? '需要更新到 ${info!.latestVersionName}'
                                  : '需要更新',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              info?.releaseNotes ??
                                  errorMessage ??
                                  '当前版本需要先完成更新后才能继续使用。',
                              textAlign: TextAlign.center,
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (info != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _formatBytes(info!.fileSize),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            if (isDownloading) ...[
                              const SizedBox(height: 22),
                              LinearProgressIndicator(value: progress),
                            ],
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: onDownload ?? onRetry,
                              icon: Icon(
                                onDownload != null
                                    ? Icons.download
                                    : Icons.refresh,
                              ),
                              label: Text(
                                isDownloading
                                    ? '下载中'
                                    : onDownload != null
                                        ? '下载更新'
                                        : '重试检测',
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
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '安装包大小未知';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var index = 0;
    while (size >= 1024 && index < units.length - 1) {
      size /= 1024;
      index += 1;
    }
    return '${size.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
  }
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
