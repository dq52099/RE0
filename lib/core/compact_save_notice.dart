import 'dart:math' as math;

import 'package:flutter/material.dart';

void showCompactSaveNotice(BuildContext context, String message) {
  final screenWidth = MediaQuery.of(context).size.width;
  final width = math.min(168.0, math.max(132.0, screenWidth - 96));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: width,
        duration: const Duration(milliseconds: 1500),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        content: Text(
          message,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
}
