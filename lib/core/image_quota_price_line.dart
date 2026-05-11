import 'package:flutter/material.dart';

import 'image_capabilities.dart';

class ImageQuotaPriceLine extends StatelessWidget {
  const ImageQuotaPriceLine({
    super.key,
    required this.capabilities,
    required this.accentColor,
  });

  final ImageModeCapabilities capabilities;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodySmall;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.58);
    final discounted = capabilities.hasVipDiscount;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'VIP',
          style: baseStyle?.copyWith(
            color: accentColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '原价',
          style: baseStyle?.copyWith(color: muted),
        ),
        Text(
          '${capabilities.vipBaseQuotaPerImage}额度/张',
          style: baseStyle?.copyWith(
            color: muted,
            decoration: discounted ? TextDecoration.lineThrough : null,
            decorationThickness: 1.6,
          ),
        ),
        if (discounted) ...[
          Icon(Icons.arrow_forward_rounded, size: 14, color: muted),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accentColor.withValues(alpha: 0.28)),
            ),
            child: Text(
              '折后 ${capabilities.effectiveVipQuotaPerImage}额度/张',
              style: baseStyle?.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: accentColor.withValues(alpha: 0.24)),
            ),
            child: Text(
              capabilities.vipDiscountLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        Text(
          '一般 ${capabilities.generalQuotaPerImage}额度/张',
          style: baseStyle?.copyWith(color: muted),
        ),
      ],
    );
  }
}
