import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'api_error.dart';
import 'app_motion.dart';
import 'stable_form_dialog.dart';

/// Disposes input controllers after the closing animation has finished.
Future<T?> showFrontendDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  List<TextEditingController> controllers = const [],
  bool barrierDismissible = true,
}) async {
  final route = AppDialogRoute<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible);
  try {
    return await Navigator.of(context, rootNavigator: true).push<T>(route);
  } finally {
    await route.completed;
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}

class FrontendSaveDialog extends StatefulWidget {
  const FrontendSaveDialog(
      {super.key,
      required this.title,
      required this.fields,
      required this.onSave});

  final String title;
  final List<Widget> fields;
  final Future<void> Function() onSave;

  @override
  State<FrontendSaveDialog> createState() => _FrontendSaveDialogState();
}

class _FrontendSaveDialogState extends State<FrontendSaveDialog> {
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: StableFormDialog(
          title: Text(widget.title),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AbsorbPointer(
                  absorbing: _saving,
                  child: Column(
                      mainAxisSize: MainAxisSize.min, children: widget.fields)),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                        liveRegion: true,
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)))),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '保存中…' : '保存')),
          ],
        ),
      );
}

class FrontendPasswordField extends StatefulWidget {
  const FrontendPasswordField(
      {super.key,
      required this.controller,
      required this.label,
      this.helperText});
  final TextEditingController controller;
  final String label;
  final String? helperText;

  @override
  State<FrontendPasswordField> createState() => _FrontendPasswordFieldState();
}

/// Gives inputs their full width when a neighboring action would crowd them.
class FrontendFieldWithAction extends StatelessWidget {
  const FrontendFieldWithAction(
      {super.key, required this.field, required this.action});
  final Widget field, action;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth < 360 * scale) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field,
                const SizedBox(height: 12),
                Align(alignment: AlignmentDirectional.centerEnd, child: action),
              ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: field),
          const SizedBox(width: 12),
          action,
        ]);
      });
}

class _FrontendPasswordFieldState extends State<FrontendPasswordField> {
  bool _visible = false;
  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        obscureText: !_visible,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
            labelText: widget.label,
            helperText: widget.helperText,
            helperMaxLines: 3,
            suffixIcon: IconButton(
                tooltip: _visible ? '隐藏密码' : '显示密码',
                onPressed: () => setState(() => _visible = !_visible),
                icon: Icon(_visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined))),
      );
}

/// Keeps scrollable pages readable on wide displays and clear of system insets.
class FrontendPageFrame extends StatelessWidget {
  const FrontendPageFrame(
      {super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      );
}

class FrontendSection extends StatelessWidget {
  const FrontendSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 21, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ]),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class FrontendStateCard extends StatelessWidget {
  const FrontendStateCard({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.photo_library_outlined,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: isError,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 36,
              color: isError
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          if (onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
                onPressed: onAction, child: Text(actionLabel ?? '重试')),
          ],
        ]),
      ),
    );
  }
}

/// Shows elapsed time and actual returned images, without predicting completion.
class ImageTaskStatusCard extends ConsumerStatefulWidget {
  const ImageTaskStatusCard({super.key});

  @override
  ConsumerState<ImageTaskStatusCard> createState() =>
      _ImageTaskStatusCardState();
}

class _ImageTaskStatusCardState extends ConsumerState<ImageTaskStatusCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(imageTaskProgressProvider);
    if (progress == null) return const SizedBox.shrink();
    final elapsed = DateTime.now().difference(progress.startedAt).inSeconds;
    final time =
        elapsed >= 60 ? '${elapsed ~/ 60} 分 ${elapsed % 60} 秒' : '$elapsed 秒';
    final recoveryStatus = ref.watch(imageRecoveryStatusProvider);
    final action = progress.kind == ImageTaskKind.generate ? '生成' : '修改';
    return FrontendSection(
      title: recoveryStatus == null ? '正在$action图片' : '正在恢复图片结果',
      icon: Icons.hourglass_top_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text('已返回 ${progress.completed} / ${progress.total} 张 · 已等待 $time'),
        const SizedBox(height: 8),
        Text(recoveryStatus ??
            (elapsed >= 120
                ? '等待时间较长，请保持应用运行，避免重复提交。若最终超时，可到图片记录查看结果。'
                : '图片完成后会依次显示。可以切换页面，请保持应用运行。')),
      ]),
    );
  }
}
