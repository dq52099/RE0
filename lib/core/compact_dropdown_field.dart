import 'package:flutter/material.dart';

class CompactDropdownField<T> extends StatelessWidget {
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
  final T value;
  final double width;
  final double? menuWidth;
  final List<DropdownMenuItem<T>> items;
  final List<String> selectedLabels;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    const menuSafetyInset = 8.0;
    final maxMenuWidth =
        width > menuSafetyInset ? width - menuSafetyInset : width;
    final requestedMenuWidth = menuWidth ?? maxMenuWidth;
    final resolvedMenuWidth =
        requestedMenuWidth > maxMenuWidth ? maxMenuWidth : requestedMenuWidth;
    final selectedIndex = items.indexWhere((item) => item.value == value);
    final selectedLabel =
        selectedIndex >= 0 && selectedIndex < selectedLabels.length
            ? selectedLabels[selectedIndex]
            : value.toString();
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w400,
      height: 1.3,
    );
    final labelStyle = theme.textTheme.bodyMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.15,
    );
    final decoration = InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      labelStyle: labelStyle,
      floatingLabelStyle: labelStyle,
    );

    return SizedBox(
      width: width,
      child: Listener(
        onPointerDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        child: PopupMenuButton<T>(
          initialValue: value,
          tooltip: '',
          padding: EdgeInsets.zero,
          position: PopupMenuPosition.under,
          offset: Offset(width - resolvedMenuWidth, 4),
          constraints: BoxConstraints.tightFor(width: resolvedMenuWidth),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (context) => items
              .map(
                (item) => PopupMenuItem<T>(
                  value: item.value,
                  enabled: item.enabled,
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: Center(child: item.child),
                  ),
                ),
              )
              .toList(),
          onSelected: (next) {
            FocusManager.instance.primaryFocus?.unfocus();
            onChanged(next);
          },
          child: InputDecorator(
            decoration: decoration,
            isEmpty: selectedLabel.isEmpty,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedLabel,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: bodyStyle,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.expand_more, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static DropdownMenuItem<T> centeredItem<T>(
    T value,
    String label,
    BuildContext context,
  ) {
    return DropdownMenuItem<T>(
      value: value,
      alignment: AlignmentDirectional.center,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
          ),
        ),
      ),
    );
  }
}
