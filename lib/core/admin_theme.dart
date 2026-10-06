import 'package:flutter/material.dart';

/// A compact type hierarchy for management pages, preserving each brand's palette.
ThemeData adminTheme(ThemeData base) {
  final scheme = base.colorScheme;
  final text = base.textTheme;
  final title = text.titleMedium?.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: scheme.onSurface,
    height: 1.4,
  );
  final heading = text.titleLarge?.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: scheme.primary,
    height: 1.35,
  );
  return base.copyWith(
    textTheme: text.copyWith(
      headlineSmall: heading,
      headlineMedium: text.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w500,
        color: scheme.primary,
      ),
      titleLarge: heading,
      titleMedium: title,
      titleSmall: text.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: scheme.primary,
        height: 1.4,
      ),
      labelSmall: text.labelSmall?.copyWith(fontWeight: FontWeight.w400),
      labelMedium: text.labelMedium?.copyWith(fontWeight: FontWeight.w400),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w400),
    ),
    appBarTheme: base.appBarTheme.copyWith(titleTextStyle: heading),
    dialogTheme: base.dialogTheme.copyWith(titleTextStyle: heading),
    tabBarTheme: base.tabBarTheme.copyWith(
      labelStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      unselectedLabelStyle:
          text.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
    ),
    expansionTileTheme: base.expansionTileTheme.copyWith(
      textColor: scheme.onSurface,
      collapsedTextColor: scheme.onSurface,
    ),
  );
}
