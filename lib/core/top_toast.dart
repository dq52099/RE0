import 'package:flutter/material.dart';

void showTopToast(
  BuildContext context,
  String message, {
  Duration duration = const Duration(milliseconds: 1600),
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) {
      final top = MediaQuery.of(context).padding.top + 14;
      return Positioned(
        top: top,
        left: 16,
        right: 16,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.82),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
  Future.delayed(duration, () {
    if (entry.mounted) {
      entry.remove();
    }
  });
}
