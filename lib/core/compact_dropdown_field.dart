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
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400,
          height: 1.3,
        );

    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        value: value,
        isDense: true,
        isExpanded: true,
        menuMaxHeight: 280,
        menuWidth: menuWidth,
        borderRadius: BorderRadius.circular(16),
        alignment: Alignment.center,
        icon: const Icon(Icons.expand_more, size: 18),
        style: bodyStyle,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w400,
              ),
        ),
        items: items,
        selectedItemBuilder: (context) => selectedLabels
            .map(
              (item) => Center(
                child: Text(
                  item,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: bodyStyle,
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
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
      alignment: Alignment.center,
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
      ),
    );
  }
}
