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
    return Text(
      'VIP:${capabilities.effectiveVipQuotaPerImage}额度/张（${capabilities.vipMultiplierLabel}倍）  一般:${capabilities.generalQuotaPerImage}额度/张',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: accentColor.withValues(alpha: 0.88),
            fontWeight: FontWeight.w600,
          ),
    );
  }
}
