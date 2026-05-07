import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/brand_background.dart';
import '../../core/compact_save_notice.dart';
import '../../core/providers.dart';

class PasswordResetScreen extends ConsumerStatefulWidget {
  const PasswordResetScreen({super.key, this.initialAccount = ''});

  final String initialAccount;

  @override
  ConsumerState<PasswordResetScreen> createState() =>
      _PasswordResetScreenState();
}

class _PasswordResetScreenState extends ConsumerState<PasswordResetScreen> {
  static const _defaultServerUrl = 'https://image.6688667.xyz';

  late final TextEditingController _accountController;
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _accountError;
  String? _emailError;
  String? _codeError;
  String? _passwordError;
  bool _isSendingCode = false;
  bool _isSubmitting = false;
  int _emailCooldownSeconds = 0;
  Timer? _emailCooldownTimer;

  @override
  void initState() {
    super.initState();
    _accountController = TextEditingController(text: widget.initialAccount);
  }

  @override
  void dispose() {
    _emailCooldownTimer?.cancel();
    _accountController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendResetCode() async {
    final account = _accountController.text.trim();
    if (account.isEmpty) {
      setState(() => _accountError = '请输入用户名、账号或邮箱。');
      return;
    }

    setState(() {
      _accountError = null;
      _emailError = null;
      _isSendingCode = true;
    });
    try {
      final client = ref.read(gatewayClientProvider);
      await client.init(_defaultServerUrl);
      final result = await client.requestPasswordReset(account);
      _emailController.text =
          result['email']?.toString() ?? _emailController.text;
      if (!mounted) return;
      _startEmailCooldown();
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
        friendlyError(error, fallback: '发送找回密码验证码失败。'),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingCode = false);
      }
    }
  }

  void _startEmailCooldown() {
    _emailCooldownTimer?.cancel();
    setState(() => _emailCooldownSeconds = 60);
    _emailCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_emailCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _emailCooldownSeconds = 0);
      } else {
        setState(() => _emailCooldownSeconds -= 1);
      }
    });
  }

  bool _validate() {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;

    String? emailError;
    String? codeError;
    String? passwordError;

    if (email.isEmpty) {
      emailError = '请先发送验证码获取收件邮箱。';
    } else if (!RegExp(r'^[^@\s]+@(qq\.com|163\.com|claw\.163\.com)$')
        .hasMatch(email.toLowerCase())) {
      emailError = '当前仅支持 qq.com、163.com 和 claw.163.com 邮箱。';
    }
    if (code.isEmpty) {
      codeError = '请输入验证码。';
    }
    if (password.isEmpty) {
      passwordError = '请输入新密码。';
    } else if (password.length < 10) {
      passwordError = '新密码至少需要 10 位。';
    }

    setState(() {
      _emailError = emailError;
      _codeError = codeError;
      _passwordError = passwordError;
    });

    return emailError == null && codeError == null && passwordError == null;
  }

  Future<void> _resetPassword() async {
    if (!_validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(gatewayClientProvider).confirmPasswordReset(
            email: _emailController.text.trim(),
            code: _codeController.text.trim(),
            newPassword: _passwordController.text,
          );
      if (!mounted) return;
      showCenterNotice(context, '密码已重置，请重新登录。');
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      showCenterNotice(
        context,
        friendlyError(error, fallback: '重置密码失败。'),
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
      appBar: AppBar(title: const Text('找回密码')),
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
                          '通过已绑定邮箱接收验证码，然后设置新密码。',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _accountController,
                          onChanged: (_) {
                            if (_accountError != null) {
                              setState(() => _accountError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: '用户名、账号或邮箱',
                            helperText: '填写任一已绑定账号信息，用于发送邮件验证码',
                            errorText: _accountError,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) {
                            if (_emailError != null) {
                              setState(() => _emailError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: '收件邮箱',
                            helperText: '发送验证码后会自动填入',
                            errorText: _emailError,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _codeController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) {
                                  if (_codeError != null) {
                                    setState(() => _codeError = null);
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText: '邮箱验证码',
                                  errorText: _codeError,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              height: 56,
                              child: OutlinedButton(
                                onPressed:
                                    _isSendingCode || _emailCooldownSeconds > 0
                                        ? null
                                        : _sendResetCode,
                                child: _isSendingCode
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(_emailCooldownSeconds > 0
                                        ? '${_emailCooldownSeconds}s'
                                        : '发送邮件'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          onChanged: (_) {
                            if (_passwordError != null) {
                              setState(() => _passwordError = null);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: '新密码',
                            helperText: '至少 10 位，需包含大小写字母、数字和特殊字符',
                            errorText: _passwordError,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => Navigator.pop(context),
                                child: const Text('取消'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed:
                                    _isSubmitting ? null : _resetPassword,
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('重置密码'),
                              ),
                            ),
                          ],
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
