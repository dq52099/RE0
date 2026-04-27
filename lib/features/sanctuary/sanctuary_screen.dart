import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/providers.dart';
import '../auth/login_screen.dart';

class SanctuaryScreen extends ConsumerStatefulWidget {
  const SanctuaryScreen({
    super.key,
    this.title,
    this.targetView,
  });

  final String? title;
  final String? targetView;

  @override
  ConsumerState<SanctuaryScreen> createState() => _SanctuaryScreenState();
}

class _SanctuaryScreenState extends ConsumerState<SanctuaryScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _activateTargetView(),
        ),
      );
    _loadConsole();
  }

  Future<void> _loadConsole() async {
    final client = ref.read(gatewayClientProvider);
    try {
      await _syncWebViewCookies();
      await _controller.loadRequest(Uri.parse(client.baseUrl));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _syncWebViewCookies() async {
    final client = ref.read(gatewayClientProvider);
    final uri = Uri.parse(client.baseUrl);
    final cookies = await client.webViewCookies();
    final cookieManager = WebViewCookieManager();
    for (final cookie in cookies) {
      await cookieManager.setCookie(
        WebViewCookie(
          name: cookie.name,
          value: cookie.value,
          domain: (cookie.domain?.isNotEmpty ?? false) ? cookie.domain! : uri.host,
          path: (cookie.path?.isNotEmpty ?? false) ? cookie.path! : '/',
        ),
      );
    }
  }

  Future<void> _activateTargetView() async {
    final targetView = widget.targetView;
    if (targetView == null || targetView.isEmpty) {
      return;
    }
    final escapedTarget = targetView.replaceAll("'", r"\'");
    await _controller.runJavaScript('''
(function() {
  var target = '$escapedTarget';
  var tries = 0;
  var timer = setInterval(function() {
    var button = document.querySelector('[data-view-key="' + target + '"]');
    if (button) {
      button.click();
      clearInterval(timer);
      return;
    }
    tries += 1;
    if (tries > 30) {
      clearInterval(timer);
    }
  }, 250);
})();
''');
  }

  void _logout() async {
    final client = ref.read(gatewayClientProvider);
    await client.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? brand.consoleTitle),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: brand.warningColor),
            onPressed: () {
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text('退出${brand.consoleTitle}'),
                  content: const Text('确定要断开连接并退出吗？'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(c);
                        _logout();
                      },
                      child: Text(
                        '退出',
                        style: TextStyle(color: brand.warningColor),
                      )
                    ),
                  ],
                )
              );
            },
          )
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }
}
