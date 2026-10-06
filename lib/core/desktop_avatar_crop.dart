import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Native desktop cropper, independent of the Android crop activity.
Future<File?> cropDesktopAvatar(BuildContext context, String path) async {
  final codec = await ui.instantiateImageCodec(await File(path).readAsBytes(),
      targetWidth: 1600, allowUpscaling: false);
  final image = (await codec.getNextFrame()).image;
  codec.dispose();
  try {
    if (!context.mounted) return null;
    final route = DialogRoute<File>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _AvatarCropDialog(image: image));
    final result = await Navigator.of(context).push(route);
    await route.completed;
    return result;
  } finally {
    image.dispose();
  }
}

class _AvatarCropDialog extends StatefulWidget {
  const _AvatarCropDialog({required this.image});
  final ui.Image image;
  @override
  State<_AvatarCropDialog> createState() => _AvatarCropDialogState();
}

class _AvatarCropDialogState extends State<_AvatarCropDialog> {
  double _zoom = 1;
  Offset _offset = Offset.zero;
  bool _saving = false;
  Rect _source() {
    final side = math.min(widget.image.width, widget.image.height) / _zoom;
    final left = ((widget.image.width - side) / 2 + _offset.dx)
        .clamp(0.0, widget.image.width - side)
        .toDouble();
    final top = ((widget.image.height - side) / 2 + _offset.dy)
        .clamp(0.0, widget.image.height - side)
        .toDouble();
    return Rect.fromLTWH(left, top, side, side);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
          widget.image,
          _source(),
          const Rect.fromLTWH(0, 0, 512, 512),
          Paint()..filterQuality = FilterQuality.high);
      final picture = recorder.endRecording();
      final image = await picture.toImage(512, 512);
      picture.dispose();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final directory = await getTemporaryDirectory();
      final file = File(
          '${directory.path}/re0-avatar-${DateTime.now().microsecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
      if (mounted) Navigator.pop(context, file);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('裁剪失败，请换一张图片重试。')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('裁剪头像'),
        content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('拖动图片调整位置，滑动下方滑块缩放。'),
              const SizedBox(height: 16),
              AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                      builder: (context, constraints) => MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: GestureDetector(
                                onPanUpdate: _saving
                                    ? null
                                    : (details) => setState(() {
                                          final previous = _source();
                                          final desired = previous.topLeft -
                                              details.delta *
                                                  (previous.width /
                                                      constraints.maxWidth);
                                          _offset = Offset(
                                              desired.dx.clamp(
                                                      0.0,
                                                      widget.image.width -
                                                          previous.width) -
                                                  (widget.image.width -
                                                          previous.width) /
                                                      2,
                                              desired.dy.clamp(
                                                      0.0,
                                                      widget.image.height -
                                                          previous.height) -
                                                  (widget.image.height -
                                                          previous.height) /
                                                      2);
                                        }),
                                child: CustomPaint(
                                    painter:
                                        _CropPainter(widget.image, _source()))),
                          ))),
              Slider(
                  value: _zoom,
                  min: 1,
                  max: 4,
                  label: '${_zoom.toStringAsFixed(1)}×',
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _zoom = value)),
            ]))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('取消')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '处理中…' : '使用头像')),
        ],
      ));
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.image, this.source);
  final ui.Image image;
  final Rect source;
  @override
  void paint(Canvas canvas, Size size) => canvas.drawImageRect(image, source,
      Offset.zero & size, Paint()..filterQuality = FilterQuality.high);
  @override
  bool shouldRepaint(_CropPainter old) =>
      old.image != image || old.source != source;
}
