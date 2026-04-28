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
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400,
          height: 1.3,
        );
    final labelStyle = theme.textTheme.titleSmall?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.15,
    );
    final decoration = InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelStyle: labelStyle,
      floatingLabelStyle: labelStyle,
    );

    return SizedBox(
      width: width,
      child: InputDecorator(
        decoration: decoration,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: value,
                  isDense: true,
                  isExpanded: true,
                  menuMaxHeight: 280,
                  menuWidth: resolvedMenuWidth,
                  alignment: Alignment.center,
                  borderRadius: BorderRadius.circular(16),
                  icon: const SizedBox.shrink(),
                  style: bodyStyle,
                  items: items,
                  selectedItemBuilder: (context) => selectedLabels
                      .map(
                        (item) => Directionality(
                          textDirection: TextDirection.ltr,
                          child: Center(
                            child: Text(
                              item,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: bodyStyle,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
            const Positioned(
              right: 0,
              child: IgnorePointer(
                child: Icon(Icons.expand_more, size: 18),
              ),
            ),
          ],
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
