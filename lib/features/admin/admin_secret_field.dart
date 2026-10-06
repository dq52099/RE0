import 'package:flutter/material.dart';

/// Credentials are write-only; a blank field preserves the server's value.
class AdminSecretField extends StatefulWidget {
  const AdminSecretField(
      {super.key,
      required this.controller,
      required this.decoration,
      this.maxLines = 1});

  final TextEditingController controller;
  final InputDecoration decoration;
  final int maxLines;

  @override
  State<AdminSecretField> createState() => _AdminSecretFieldState();
}

class _AdminSecretFieldState extends State<AdminSecretField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        obscureText: _hidden,
        maxLines: _hidden ? 1 : widget.maxLines,
        autocorrect: false,
        enableSuggestions: false,
        decoration: widget.decoration.copyWith(
            suffixIcon: IconButton(
          tooltip: _hidden ? '显示输入内容' : '隐藏输入内容',
          icon: Icon(_hidden
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _hidden = !_hidden),
        )),
      );
}
