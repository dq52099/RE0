import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Keeps navigation buttons together when the candidate title needs its own row.
class PromptCandidateToolbar extends StatelessWidget {
  const PromptCandidateToolbar({
    super.key,
    required this.label,
    required this.color,
    required this.onViewAll,
    required this.previousTooltip,
    required this.nextTooltip,
    this.onPrevious,
    this.onNext,
  });

  final String label, previousTooltip, nextTooltip;
  final Color color;
  final VoidCallback onViewAll;
  final VoidCallback? onPrevious, onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final labelStyle = theme.textTheme.bodyMedium!;
    final buttonStyle = theme.textTheme.labelLarge!;
    double textWidth(String text, TextStyle style) {
      final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: direction,
          textScaler: scaler,
          maxLines: 1)
        ..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final viewWidth = math.max(64.0, textWidth('查看全部', buttonStyle) + 16);
    final actionWidth = viewWidth + 96;
    final titleWidth = 26 + textWidth(label, labelStyle);
    return LayoutBuilder(builder: (context, constraints) {
      final title = Row(children: [
        Icon(Icons.auto_fix_high, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: labelStyle)),
      ]);
      final actions = SizedBox(
        width: actionWidth,
        child: Row(children: [
          SizedBox(
            width: viewWidth,
            child: TextButton(
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(64, 48),
                    textStyle: buttonStyle),
                onPressed: onViewAll,
                child: const Text('查看全部', maxLines: 1, softWrap: false)),
          ),
          IconButton(
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              tooltip: previousTooltip,
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left)),
          IconButton(
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              tooltip: nextTooltip,
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right)),
        ]),
      );
      if (constraints.maxWidth >= titleWidth + 12 + actionWidth) {
        return Row(children: [
          Expanded(child: title),
          const SizedBox(width: 12),
          actions,
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        title,
        const SizedBox(height: 4),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: actions,
          ),
        ),
      ]);
    });
  }
}
