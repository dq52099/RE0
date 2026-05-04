import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/brand_background.dart';
import '../../core/compact_save_notice.dart';
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
  final _emailController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final _resetAccountController = TextEditingController();
  final _resetEmailController = TextEditingController();
  final _resetCodeController = TextEditingController();
  final _resetPasswordController = TextEditingController();
  String? _usernameError;
  String? _passwordError;
  String? _emailError;
  String? _emailCodeError;
  bool _isLoading = false;
  bool _isEmailLogin = false;
  bool _isSendingEmailCode = false;
  bool _isSendingResetCode = false;
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
    _emailController.dispose();
    _emailCodeController.dispose();
    _resetAccountController.dispose();
    _resetEmailController.dispose();
    _resetCodeController.dispose();
    _resetPasswordController.dispose();
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
    if (_isEmailLogin) {
      await _loginWithEmailCode();
      return;
    }
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
        showCenterNotice(
          context,
          friendlyError(e, fallback: '登录失败，请检查账号和密码。'),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendLoginEmailCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = '请输入邮箱。');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _emailError = '邮箱格式不正确。');
      return;
    }
    setState(() {
      _emailError = null;
      _emailCodeError = null;
      _isSendingEmailCode = true;
    });
    try {
      final client = ref.read(gatewayClientProvider);
      await client.init(_defaultServerUrl);
      final result = await client.sendEmailCode(email, 'login');
      if (!mounted) return;
      final message = result['message']?.toString() ?? '验证码已发送，请查看邮箱。';
      final devCode = result['dev_code']?.toString();
      showCenterNotice(
        context,
        devCode == null || devCode.isEmpty ? message : '$message 验证码：$devCode',
      );
    } catch (error) {
      if (!mounted) return;
      showCenterNotice(
        context,
        friendlyError(error, fallback: '发送邮箱验证码失败。'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingEmailCode = false);
      }
    }
  }

  Future<void> _loginWithEmailCode() async {
    final email = _emailController.text.trim();
    final code = _emailCodeController.text.trim();
    String? emailError;
    String? codeError;
    if (email.isEmpty) {
      emailError = '请输入邮箱。';
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      emailError = '邮箱格式不正确。';
    }
    if (code.isEmpty) {
      codeError = '请输入验证码。';
    }
    if (emailError != null || codeError != null) {
      setState(() {
        _emailError = emailError;
        _emailCodeError = codeError;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final client = ref.read(gatewayClientProvider);
      await client.init(_defaultServerUrl);
      final res = await client.emailLogin(email, code);
      final prefs = ref.read(sharedPrefsProvider);
      await prefs.setString('server_url', _defaultServerUrl);
      ref.read(authStateProvider.notifier).state = res['user'];
      ref.read(energyProvider.notifier).state = res['user']['quota_summary'];
      if (mounted) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (error) {
      if (mounted) {
        showCenterNotice(
          context,
          friendlyError(error, fallback: '邮箱验证码登录失败。'),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openPasswordReset() async {
    _resetAccountController.text = _usernameController.text.trim();
    _resetEmailController.clear();
    _resetCodeController.clear();
    _resetPasswordController.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendResetCode() async {
              final account = _resetAccountController.text.trim();
              if (account.isEmpty) {
                showCenterNotice(context, '请先填写账号或邮箱。');
                return;
              }
              setDialogState(() => _isSendingResetCode = true);
              try {
                final client = ref.read(gatewayClientProvider);
                await client.init(_defaultServerUrl);
                final result = await client.requestPasswordReset(account);
                _resetEmailController.text =
                    result['email']?.toString() ?? _resetEmailController.text;
                final message =
                    result['message']?.toString() ?? '验证码已发送，请查看邮箱。';
                final devCode = result['dev_code']?.toString();
                if (!context.mounted) return;
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
                  friendlyError(error, fallback: '发送找回密码验证码失败。'),
                );
              } finally {
                if (context.mounted) {
                  setDialogState(() => _isSendingResetCode = false);
                }
              }
            }

            Future<void> confirmReset() async {
              final email = _resetEmailController.text.trim();
              final code = _resetCodeController.text.trim();
              final password = _resetPasswordController.text;
              if (email.isEmpty || code.isEmpty || password.isEmpty) {
                showCenterNotice(context, '请填写邮箱、验证码和新密码。');
                return;
              }
              try {
                await ref.read(gatewayClientProvider).confirmPasswordReset(
                      email: email,
                      code: code,
                      newPassword: password,
                    );
                if (!context.mounted) return;
                Navigator.pop(context);
                showCenterNotice(context, '密码已重置，请重新登录。');
              } catch (error) {
                if (!context.mounted) return;
                showCenterNotice(
                  context,
                  friendlyError(error, fallback: '重置密码失败。'),
                );
              }
            }

            return AlertDialog(
              title: const Text('找回密码'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _resetAccountController,
                      decoration: const InputDecoration(
                        labelText: '账号或邮箱',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _resetEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: '收件邮箱',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _resetCodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '验证码'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _resetPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: '新密码',
                        helperText: '至少 10 位，包含大小写字母、数字和特殊字符',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                OutlinedButton(
                  onPressed: _isSendingResetCode ? null : sendResetCode,
                  child: _isSendingResetCode
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('发送验证码'),
                ),
                FilledButton(
                  onPressed: confirmReset,
                  child: const Text('重置密码'),
                ),
              ],
            );
          },
        );
      },
    );
    if (mounted) {
      setState(() => _isSendingResetCode = false);
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
      resizeToAvoidBottomInset: true,
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
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('密码登录')),
                    ButtonSegment(value: true, label: Text('邮箱验证码')),
                  ],
                  selected: {_isEmailLogin},
                  onSelectionChanged: (values) {
                    setState(() => _isEmailLogin = values.first);
                  },
                ),
                const SizedBox(height: 18),
                if (!_isEmailLogin) ...[
                  TextField(
                    controller: _usernameController,
                    onChanged: (_) {
                      if (_usernameError != null) {
                        setState(() => _usernameError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: '账号或邮箱',
                      hintText: '输入账号或已绑定邮箱',
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
                ] else ...[
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: '邮箱',
                      hintText: '输入已绑定邮箱',
                      errorText: _emailError,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailCodeController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) {
                            if (_emailCodeError != null) {
                              setState(() => _emailCodeError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: '验证码',
                            errorText: _emailCodeError,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed:
                              _isSendingEmailCode ? null : _sendLoginEmailCode,
                          child: _isSendingEmailCode
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('获取验证码'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 32),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _login,
                        child: const Text('登录'),
                      ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _isLoading ? null : _openPasswordReset,
                  child: const Text('忘记密码'),
                ),
                if (_allowRegistration) ...[
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
