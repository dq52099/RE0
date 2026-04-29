import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/brand_background.dart';
import '../../core/providers.dart';
import '../home/home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _defaultServerUrl = 'https://image.6688667.xyz';

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _usernameError;
  String? _passwordError;
  bool _isLoading = false;
  bool _allowRegistration = true;

  @override
  void initState() {
    super.initState();
    _loadBootstrap();
    _checkSavedAuth();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadBootstrap() async {
    try {
      final client = ref.read(gatewayClientProvider);
      await client.init(_defaultServerUrl);
      final bootstrap = await client.bootstrap();
      if (!mounted) return;
      setState(() {
        _allowRegistration = bootstrap['allow_public_registration'] != false;
      });
    } catch (_) {
      // Fall back to showing registration entry.
    }
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
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      // Not logged in or server unreachable
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    String? usernameError;
    String? passwordError;
    if (username.isEmpty) {
      usernameError = '请输入账号。';
    }
    if (password.isEmpty) {
      passwordError = '请输入密码。';
    }
    if (usernameError != null || passwordError != null) {
      setState(() {
        _usernameError = usernameError;
        _passwordError = passwordError;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final client = ref.read(gatewayClientProvider);
      await client.init(_defaultServerUrl);
      final res = await client.login(username, password);

      final prefs = ref.read(sharedPrefsProvider);
      await prefs.setString('server_url', _defaultServerUrl);

      ref.read(authStateProvider.notifier).state = res['user'];
      ref.read(energyProvider.notifier).state = res['user']['quota_summary'];

      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e, fallback: '登录失败，请检查账号和密码。'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openRegisterScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: BrandBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                        color: brand.primaryColor.withValues(alpha: 0.7),
                        width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: brand.primaryColor.withValues(alpha: 0.22),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset('assets/icon.png', fit: BoxFit.cover),
                ),
                const SizedBox(height: 20),
                Text(
                  brand.loginTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  brand.style == BrandStyle.re0
                      ? '从零开始的异世界生图'
                      : 'image.6688667.xyz',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (brand.style == BrandStyle.re0) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _loginChip(brand, '死亡回归'),
                      _loginChip(brand, '魔女气息'),
                      _loginChip(brand, '王都契约'),
                    ],
                  ),
                ],
                const SizedBox(height: 40),
                TextField(
                  controller: _usernameController,
                  onChanged: (_) {
                    if (_usernameError != null) {
                      setState(() => _usernameError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: '账号',
                    hintText: '输入你的账号',
                    errorText: _usernameError,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  onChanged: (_) {
                    if (_passwordError != null) {
                      setState(() => _passwordError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: '密码',
                    hintText: '输入你的密码',
                    errorText: _passwordError,
                  ),
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _login,
                        child: const Text('登录'),
                      ),
                if (_allowRegistration) ...[
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _isLoading ? null : _openRegisterScreen,
                    child: const Text('注册新账号'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginChip(AppBrand brand, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: brand.panelColor.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: brand.primaryColor.withValues(alpha: 0.32)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
