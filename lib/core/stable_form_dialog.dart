import 'package:flutter/material.dart';

/// Tracks the keyboard directly while keeping the dialog's top edge fixed.
class KeyboardStableDialog extends StatelessWidget {
  const KeyboardStableDialog({
    super.key,
    required this.child,
    this.insetPadding =
        const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
    this.shape,
  });

  final Widget child;
  final EdgeInsets insetPadding;
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) => Dialog(
        alignment: Alignment.topCenter,
        insetAnimationDuration: Duration.zero,
        insetPadding: insetPadding,
        shape: shape ??
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.14),
                width: 0.8,
              ),
            ),
        child: child,
      );
}

class StableFormDialog extends StatelessWidget {
  const StableFormDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.maxWidth = 480,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => KeyboardStableDialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.titleLarge,
                  child: title,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: content,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      );
}
