import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/brand_background.dart';
import '../../core/compact_save_notice.dart';
import '../../core/providers.dart';
import '../home/home_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const _defaultServerUrl = 'https://image.6688667.xyz';

  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _emailCodeController = TextEditingController();
  final _invitationCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _usernameError;
  String? _displayNameError;
  String? _emailError;
  String? _emailCodeError;
  String? _invitationCodeError;
  String? _passwordError;
  String? _confirmPasswordError;
  bool _isSubmitting = false;
  bool _isSendingEmailCode = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _emailCodeController.dispose();
    _invitationCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validate() {
    final username = _usernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final emailCode = _emailCodeController.text.trim();
    final invitationCode = _invitationCodeController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    String? usernameError;
    String? displayNameError;
    String? emailError;
    String? emailCodeError;
    String? invitationCodeError;
    String? passwordError;
    String? confirmPasswordError;

    if (username.isEmpty) {
      usernameError = '请输入账号。';
    } else if (username.length < 4 || username.length > 24) {
      usernameError = '账号长度需为 4 到 24 位。';
    } else if (!RegExp(r'^[a-z][a-z0-9_-]{3,23}$').hasMatch(username)) {
      usernameError = '账号需以小写字母开头，只允许小写字母、数字、下划线和短横线。';
    }

    if (displayName.isEmpty) {
      displayNameError = '请输入显示名称。';
    } else if (displayName.length < 2 || displayName.length > 32) {
      displayNameError = '显示名称长度需为 2 到 32 个字符。';
    }

    if (email.isNotEmpty &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      emailError = '邮箱格式不正确。';
    }
    if (email.isNotEmpty && emailCode.isEmpty) {
      emailCodeError = '请先获取并填写邮箱验证码。';
    }

    if (invitationCode.isEmpty) {
      invitationCodeError = '请输入邀请码。';
    } else if (invitationCode.length < 4) {
      invitationCodeError = '邀请码格式不正确。';
    }

    if (password.isEmpty) {
      passwordError = '请输入密码。';
    } else if (password.length < 10) {
      passwordError = '密码至少需要 10 位。';
    }

    if (confirmPassword.isEmpty) {
      confirmPasswordError = '请再次输入密码。';
    } else if (confirmPassword != password) {
      confirmPasswordError = '两次输入的密码不一致。';
    }

    setState(() {
      _usernameError = usernameError;
      _displayNameError = displayNameError;
      _emailError = emailError;
      _emailCodeError = emailCodeError;
      _invitationCodeError = invitationCodeError;
      _passwordError = passwordError;
      _confirmPasswordError = confirmPasswordError;
    });

    return usernameError == null &&
        displayNameError == null &&
        emailError == null &&
        emailCodeError == null &&
        invitationCodeError == null &&
        passwordError == null &&
        confirmPasswordError == null;
  }

  Future<void> _sendEmailCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = '请先填写邮箱。');
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
      final result = await client.sendEmailCode(email, 'bind');
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

  Future<void> _register() async {
    if (!_validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final client = ref.read(gatewayClientProvider);
      await client.init(_defaultServerUrl);
      final res = await client.register(
        _usernameController.text.trim(),
        _displayNameController.text.trim(),
        _invitationCodeController.text.trim(),
        _passwordController.text,
        email: _emailController.text.trim(),
        emailCode: _emailCodeController.text.trim(),
      );
      final prefs = ref.read(sharedPrefsProvider);
      await prefs.setString('server_url', _defaultServerUrl);
      ref.read(authStateProvider.notifier).state = res['user'];
      ref.read(energyProvider.notifier).state = res['user']['quota_summary'];
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      showCenterNotice(
        context,
        friendlyError(error, fallback: '注册失败，请稍后重试。'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('注册新账号')),
      body: BrandBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brand.appTitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '使用邀请码创建账号，可同时绑定邮箱用于邮箱密码登录和找回密码。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _usernameController,
                          onChanged: (_) {
                            if (_usernameError != null) {
                              setState(() => _usernameError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: '账号',
                            helperText: '4-24 位，小写字母开头，可用数字、下划线和短横线',
                            errorText: _usernameError,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _displayNameController,
                          onChanged: (_) {
                            if (_displayNameError != null) {
                              setState(() => _displayNameError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: '显示名称',
                            helperText: '2-32 个字符',
                            errorText: _displayNameError,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) {
                            if (_emailError != null ||
                                _emailCodeError != null) {
                              setState(() {
                                _emailError = null;
                                _emailCodeError = null;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: '邮箱（可选）',
                            helperText: '绑定后可用邮箱密码登录和找回密码',
                            errorText: _emailError,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                                  labelText: '邮箱验证码',
                                  errorText: _emailCodeError,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 56,
                              child: OutlinedButton(
                                onPressed:
                                    _isSendingEmailCode ? null : _sendEmailCode,
                                child: _isSendingEmailCode
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('发送邮件'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _invitationCodeController,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (_) {
                            if (_invitationCodeError != null) {
                              setState(() => _invitationCodeError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: '邀请码',
                            helperText: '向管理员获取，每个邀请码只能使用一次',
                            errorText: _invitationCodeError,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          onChanged: (_) {
                            if (_passwordError != null ||
                                _confirmPasswordError != null) {
                              setState(() {
                                _passwordError = null;
                                _confirmPasswordError = null;
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: '密码',
                            helperText: '至少 10 位，需包含大小写字母、数字和特殊字符',
                            errorText: _passwordError,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: true,
                          onChanged: (_) {
                            if (_confirmPasswordError != null) {
                              setState(() => _confirmPasswordError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: '确认密码',
                            errorText: _confirmPasswordError,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _register,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('注册并登录'),
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
    );
  }
}
