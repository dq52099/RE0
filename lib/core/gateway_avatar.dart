import 'package:flutter/material.dart';

import 'cached_gateway_image.dart';

class GatewayAvatar extends StatelessWidget {
  const GatewayAvatar({
    super.key,
    required this.avatarUrl,
    required this.displayName,
    required this.radius,
    required this.fallback,
    required this.backgroundColor,
    this.textStyle,
  });

  final String avatarUrl;
  final String displayName;
  final double radius;
  final String fallback;
  final Color backgroundColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = avatarUrl.trim();
    final normalizedName = displayName.trim();
    final initial =
        normalizedName.isEmpty ? fallback : normalizedName.substring(0, 1);
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: normalizedUrl.isEmpty
            ? Center(child: Text(initial, style: textStyle))
            : CachedGatewayImage(
                url: normalizedUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                showDownload: false,
                cacheWidth: (radius * 4).round(),
              ),
      ),
    );
  }
}
