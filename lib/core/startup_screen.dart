import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'brand_background.dart';
import 'providers.dart';

/// Covers the login/update checks with the user's saved theme.
class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});

  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen>
    with SingleTickerProviderStateMixin {
  late final _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _glow.stop();
      _glow.value = 0.5;
    } else if (!_glow.isAnimating) {
      _glow.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = ref.watch(brandProvider);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: BrandBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _glow,
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icon.png',
                              width: 104,
                              height: 104,
                              cacheWidth: 312,
                              fit: BoxFit.cover,
                            ),
                          ),
                          builder: (context, child) {
                            final progress =
                                Curves.easeInOut.transform(_glow.value);
                            return Transform.scale(
                              scale: 1 + progress * 0.035,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: scheme.surface.withValues(alpha: 0.75),
                                  border: Border.all(
                                    color: brand.primaryColor
                                        .withValues(alpha: 0.2),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: brand.primaryColor.withValues(
                                        alpha: 0.12 + progress * 0.12,
                                      ),
                                      blurRadius: 24 + progress * 16,
                                      spreadRadius: 2 + progress * 3,
                                    ),
                                  ],
                                ),
                                child: child,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      brand.appTitle,
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        color: brand.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '让想象成为画面',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Semantics(
                      label: '正在准备应用，请稍候',
                      liveRegion: true,
                      child: ExcludeSemantics(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 120,
                              child: LinearProgressIndicator(
                                value: MediaQuery.disableAnimationsOf(context)
                                    ? 0.5
                                    : null,
                                minHeight: 2,
                                borderRadius: BorderRadius.circular(2),
                                color:
                                    brand.primaryColor.withValues(alpha: 0.65),
                                backgroundColor:
                                    brand.primaryColor.withValues(alpha: 0.1),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('正在准备…', style: textTheme.bodySmall),
                          ],
                        ),
                      ),
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
}
