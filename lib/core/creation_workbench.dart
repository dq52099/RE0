import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One readable column on a phone; independently scrollable panes on a desktop.
class CreationWorkbench extends StatefulWidget {
  const CreationWorkbench(
      {super.key,
      required this.inputs,
      required this.results,
      required this.onSubmit});
  final List<Widget> inputs;
  final List<Widget> results;
  final VoidCallback? onSubmit;

  @override
  State<CreationWorkbench> createState() => _CreationWorkbenchState();
}

class _CreationWorkbenchState extends State<CreationWorkbench> {
  final _inputKey = GlobalKey();
  final _resultKey = GlobalKey();
  final _inputScroll = ScrollController();
  final _resultScroll = ScrollController();

  @override
  void dispose() {
    _inputScroll.dispose();
    _resultScroll.dispose();
    super.dispose();
  }

  Widget _scroll(Widget child, ScrollController controller) => Scrollbar(
        controller: controller,
        child: SingleChildScrollView(
            controller: controller,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            child: child),
      );

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              _submit,
          const SingleActivator(LogicalKeyboardKey.enter, meta: true): _submit,
        },
        child: SafeArea(
            top: false,
            child: LayoutBuilder(builder: (context, constraints) {
              final input = Column(
                  key: _inputKey,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.inputs);
              final output = Column(
                  key: _resultKey,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.results);
              final wide = constraints.maxWidth >= 1000 &&
                  MediaQuery.textScalerOf(context).scale(14) <= 21;
              return Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1600),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            Expanded(
                                flex: 5, child: _scroll(input, _inputScroll)),
                            VerticalDivider(
                                width: 1,
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: .3)),
                            Expanded(
                                flex: 6, child: _scroll(output, _resultScroll)),
                          ])
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: _scroll(
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  input,
                                  const SizedBox(height: 20),
                                  output
                                ]),
                            _inputScroll)),
              ));
            })),
      );

  void _submit() {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    final focused = FocusManager.instance.primaryFocus?.context;
    final editable = focused?.findAncestorStateOfType<EditableTextState>();
    if (editable?.widget.controller.value.composing.isValid == true) return;
    widget.onSubmit?.call();
  }
}
