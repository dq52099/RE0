import 'package:flutter/material.dart';

class CompactDropdownField<T> extends StatelessWidget {
  const CompactDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.width,
    required this.items,
    required this.selectedLabels,
    required this.onChanged,
    this.showLabel = true,
  });

  final String label;
  final T value;
  final double width;
  final List<DropdownMenuItem<T>> items;
  final List<String> selectedLabels;
  final ValueChanged<T?> onChanged;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: 13,
          height: 1.3,
        );
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: 12,
        );

    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(label, style: labelStyle),
            ),
          DropdownButtonFormField<T>(
            value: value,
            isDense: true,
            isExpanded: true,
            menuMaxHeight: 280,
            borderRadius: BorderRadius.circular(14),
            alignment: Alignment.center,
            icon: const Icon(Icons.expand_more, size: 18),
            style: bodyStyle,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
        ],
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
              fontSize: 13,
              height: 1.3,
            ),
      ),
    );
  }
}
