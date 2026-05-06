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

  Future<_StartupResult> _checkSavedAuth() async {
    try {
      final client = ref.read(gatewayClientProvider);
      await client.init(_defaultServerUrl);
      final bootstrap = await client.bootstrap();
      final forceUpdate = bootstrap['force_app_update_enabled'] == true;
      if (forceUpdate) {
        try {
          final info = await ref.read(appUpdateProvider).checkForUpdate();
          if (info.available) {
            return _StartupResult.forceUpdate(info);
          }
        } catch (_) {
          return const _StartupResult.login();
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
        if (result.forceUpdateInfo != null) {
          return _ForcedUpdateScreen(
            info: result.forceUpdateInfo!,
            isDownloading: _isDownloadingUpdate,
            progress: _updateProgress,
            onDownload: _isDownloadingUpdate
                ? null
                : () {
                    _downloadForcedUpdate(result.forceUpdateInfo!);
                  },
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

class _ForcedUpdateScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.system_update_alt,
                        size: 48, color: colorScheme.primary),
                    const SizedBox(height: 18),
                    Text(
                      '需要更新到 ${info.latestVersionName}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      info.releaseNotes,
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatBytes(info.fileSize),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (isDownloading) ...[
                      const SizedBox(height: 22),
                      LinearProgressIndicator(value: progress),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.download),
                      label: Text(isDownloading ? '下载中' : '下载更新'),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
