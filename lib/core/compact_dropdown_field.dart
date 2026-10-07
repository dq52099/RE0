import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A select field with a readable menu width independent of its anchor.
class CompactDropdownField<T> extends StatefulWidget {
  const CompactDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.width,
    this.menuWidth,
    required this.items,
    required this.selectedLabels,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final double width;
  final double? menuWidth;
  final List<DropdownMenuItem<T>> items;
  final List<String> selectedLabels;
  final ValueChanged<T?> onChanged;

  @override
  State<CompactDropdownField<T>> createState() =>
      _CompactDropdownFieldState<T>();

  static DropdownMenuItem<T> centeredItem<T>(
    T value,
    String label,
    BuildContext context,
  ) =>
      DropdownMenuItem<T>(value: value, child: Text(label));
}

class _CompactDropdownFieldState<T> extends State<CompactDropdownField<T>> {
  final _controller = MenuController();
  final _focus = FocusNode();
  List<FocusNode> _itemFocus = [];
  bool _open = false;
  bool _openedWithKeyboard = false;

  @override
  void initState() {
    super.initState();
    _resetItemFocus();
  }

  @override
  void didUpdateWidget(CompactDropdownField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _controller.close();
      _resetItemFocus();
    }
  }

  void _resetItemFocus() {
    for (final node in _itemFocus) {
      node.dispose();
    }
    _itemFocus = List.generate(widget.items.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    _focus.dispose();
    for (final node in _itemFocus) {
      node.dispose();
    }
    super.dispose();
  }

  String _label(int index) => index < widget.selectedLabels.length
      ? widget.selectedLabels[index]
      : widget.items[index].value?.toString() ?? '';

  void _openFromKeyboard() {
    if (widget.items.isEmpty) return;
    _openedWithKeyboard = true;
    _controller.open();
    final selected = widget.items
        .indexWhere((item) => item.value == widget.value && item.enabled);
    final index = selected >= 0
        ? selected
        : widget.items.indexWhere((item) => item.enabled);
    if (index >= 0) _itemFocus[index].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final media = MediaQuery.of(context);
    final selected =
        widget.items.indexWhere((item) => item.value == widget.value);
    final text =
        selected >= 0 ? _label(selected) : widget.value?.toString() ?? '';
    final menuWidth = math.min(
      math.max(widget.menuWidth ?? widget.width, 224.0),
      math.min(440.0, media.size.width - 24),
    );
    final menuHeight = math.min(360.0,
        math.max(96.0, media.size.height - media.viewInsets.bottom - 32));
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.4,
    );

    return SizedBox(
      width: widget.width,
      child: MenuAnchor(
        controller: _controller,
        childFocusNode: _focus,
        crossAxisUnconstrained: false,
        alignmentOffset: const Offset(0, 6),
        consumeOutsideTap: false,
        onOpen: () {
          setState(() => _open = true);
        },
        onClose: () {
          if (mounted) {
            setState(() => _open = false);
            if (_openedWithKeyboard) _focus.requestFocus();
            _openedWithKeyboard = false;
          }
        },
        style: MenuStyle(
          alignment: AlignmentDirectional.bottomStart,
          backgroundColor: WidgetStatePropertyAll(scheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor:
              WidgetStatePropertyAll(scheme.primary.withValues(alpha: .16)),
          elevation: const WidgetStatePropertyAll(4),
          side:
              WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
          minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
          maximumSize: WidgetStatePropertyAll(Size(menuWidth, menuHeight)),
          visualDensity: VisualDensity.standard,
        ),
        menuChildren: [
          for (var i = 0; i < widget.items.length; i++)
            MenuItemButton(
              focusNode: _itemFocus[i],
              onPressed: widget.items[i].enabled
                  ? () {
                      widget.onChanged(widget.items[i].value);
                    }
                  : null,
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
                padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.disabled)
                        ? scheme.onSurface.withValues(alpha: .38)
                        : i == selected
                            ? scheme.primary
                            : scheme.onSurface),
                backgroundColor: WidgetStateProperty.resolveWith((states) =>
                    i == selected ||
                            states.contains(WidgetState.focused) ||
                            states.contains(WidgetState.hovered)
                        ? scheme.primary.withValues(alpha: .09)
                        : Colors.transparent),
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
                textStyle: WidgetStatePropertyAll(bodyStyle),
              ),
              trailingIcon: SizedBox(
                  width: 18,
                  child: i == selected
                      ? Icon(Icons.check_rounded,
                          size: 18, color: scheme.primary)
                      : null),
              child: Text(_label(i), softWrap: true),
            ),
        ],
        builder: (context, controller, child) => CallbackShortcuts(
          bindings: {
            if (_open)
              const SingleActivator(LogicalKeyboardKey.escape):
                  _controller.close,
            const SingleActivator(LogicalKeyboardKey.arrowDown):
                _openFromKeyboard,
            const SingleActivator(LogicalKeyboardKey.arrowUp):
                _openFromKeyboard,
          },
          child: Semantics(
            button: true,
            expanded: _open,
            label: widget.label,
            value: text,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                focusNode: _focus,
                borderRadius: BorderRadius.circular(12),
                onTap: widget.items.isEmpty
                    ? null
                    : () {
                        _openedWithKeyboard = false;
                        controller.isOpen
                            ? controller.close()
                            : controller.open();
                      },
                child: InputDecorator(
                  isFocused: _open,
                  isEmpty: text.isEmpty,
                  decoration: InputDecoration(
                    labelText: widget.label,
                    enabled: widget.items.isNotEmpty,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    labelStyle: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w400),
                  ),
                  child: Row(children: [
                    Expanded(
                        child: Text(text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: bodyStyle)),
                    const SizedBox(width: 8),
                    Icon(_open ? Icons.expand_less : Icons.expand_more,
                        size: 18, color: scheme.primary),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
