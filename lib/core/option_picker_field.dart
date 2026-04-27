import 'package:flutter/material.dart';

class PickerOption<T> {
  const PickerOption({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

class OptionPickerField<T> extends StatelessWidget {
  const OptionPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<PickerOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = options.firstWhere(
      (item) => item.value == value,
      orElse: () => options.first,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openPicker(context, selected.value),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.expand_more),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        child: Center(
          child: Text(
            selected.label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, T selectedValue) async {
    final nextValue = await showDialog<T>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final selected = option.value == selectedValue;
                        return Material(
                          color: selected
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.10)
                              : Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withOpacity(0.4),
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            dense: true,
                            title: Text(
                              option.label,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: selected
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                  ),
                            ),
                            onTap: () => Navigator.pop(context, option.value),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (nextValue != null) {
      onChanged(nextValue);
    }
  }
}
