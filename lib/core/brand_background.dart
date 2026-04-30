import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class BrandBackground extends ConsumerWidget {
  const BrandBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    final size = MediaQuery.sizeOf(context);
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minWidth: size.width,
              maxWidth: size.width,
              minHeight: size.height,
              maxHeight: size.height,
              child: RepaintBoundary(
                child: Image.asset(
                  brand.backgroundAsset,
                  width: size.width,
                  height: size.height,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: ColoredBox(
            color: brand.backgroundOverlay.withValues(
              alpha: brand.backgroundOverlayOpacity,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
