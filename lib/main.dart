import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  late Future<bool> _future;

  @override
  void initState() {
    super.initState();
    _future = _checkSavedAuth();
  }

  Future<bool> _checkSavedAuth() async {
    try {
      final client = ref.read(gatewayClientProvider);
      await client.init(_defaultServerUrl);
      final auth = await client.checkAuth();
      ref.read(authStateProvider.notifier).state = auth;
      ref.read(energyProvider.notifier).state = auth['quota_summary'];
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == true ? const HomeScreen() : const LoginScreen();
      },
    );
  }
}
