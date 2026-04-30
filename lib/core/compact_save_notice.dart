import 'package:flutter/material.dart';

OverlayEntry? _activeNotice;

void showCompactSaveNotice(BuildContext context, String message) {
  showCenterNotice(context, message);
}

void showCenterNotice(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  _activeNotice?.remove();
  final anchor = MediaQuery.viewInsetsOf(context).bottom > 0
      ? _NoticeAnchor.top
      : _NoticeAnchor.center;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CenterNotice(
      message: message,
      anchor: anchor,
      onDismissed: () {
        if (_activeNotice == entry) {
          _activeNotice = null;
        }
        if (entry.mounted) {
          entry.remove();
        }
      },
    ),
  );
  _activeNotice = entry;
  overlay.insert(entry);
}

class _CenterNotice extends StatefulWidget {
  const _CenterNotice({
    required this.message,
    required this.anchor,
    required this.onDismissed,
  });

  final String message;
  final _NoticeAnchor anchor;
  final VoidCallback onDismissed;

  @override
  State<_CenterNotice> createState() => _CenterNoticeState();
}

class _CenterNoticeState extends State<_CenterNotice>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 360),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.96, end: 1).animate(_fade);
    _run();
  }

  Future<void> _run() async {
    await _controller.forward();
    await Future<void>.delayed(const Duration(milliseconds: 1250));
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) {
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topAligned = widget.anchor == _NoticeAnchor.top;
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: topAligned ? Alignment.topCenter : Alignment.center,
          child: Padding(
            padding: EdgeInsets.only(
              top: topAligned ? 18 : 0,
              left: 24,
              right: 24,
            ),
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: 132,
                    maxWidth: topAligned ? 320 : 280,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xF2E8E8E8),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.72)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    maxLines: topAligned ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xDD111111),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _NoticeAnchor { center, top }
