import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../home/home_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _defaultServerUrl = 'https://image.6688667.xyz';

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkSavedAuth();
  }

  Future<void> _checkSavedAuth() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(gatewayClientProvider);
      await client.init(_defaultServerUrl);
      final auth = await client.checkAuth();
      ref.read(authStateProvider.notifier).state = auth;
      ref.read(energyProvider.notifier).state = auth['quota_summary'];
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      // Not logged in or server unreachable
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(gatewayClientProvider);
      await client.init(_defaultServerUrl);
      final res = await client.login(_usernameController.text.trim(), _passwordController.text);

      final prefs = ref.read(sharedPrefsProvider);
      await prefs.setString('server_url', _defaultServerUrl);

      ref.read(authStateProvider.notifier).state = res['user'];
      ref.read(energyProvider.notifier).state = res['user']['quota_summary'];

      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('登录失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, size: 80, color: brand.primaryColor),
              const SizedBox(height: 20),
              Text(
                brand.loginTitle,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'image.6688667.xyz',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: '称呼 (Username)'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '真名 (Password)'),
              ),
              const SizedBox(height: 32),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      child: const Text('缔结契约 (Login)'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
