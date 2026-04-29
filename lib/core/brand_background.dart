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
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          brand.backgroundAsset,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
        ),
        ColoredBox(
          color: brand.backgroundOverlay.withValues(
            alpha: brand.backgroundOverlayOpacity,
          ),
        ),
        child,
      ],
    );
  }
}
