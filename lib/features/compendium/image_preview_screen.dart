import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/app_brand.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/image_save_flow.dart';
import '../../core/providers.dart';

class PreviewImageEntry {
  const PreviewImageEntry({
    required this.url,
    this.filePath,
    this.title,
    this.caption,
  });

  final String url;
  final String? filePath;
  final String? title;
  final String? caption;
}

class ImagePreviewScreen extends ConsumerStatefulWidget {
  const ImagePreviewScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.showDownload = true,
  });

  final List<PreviewImageEntry> items;
  final int initialIndex;
  final bool showDownload;

  @override
  ConsumerState<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends ConsumerState<ImagePreviewScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _isSaving = false;
  final Map<int, TransformationController> _transforms = {};

  TransformationController _transform(int index) =>
      _transforms.putIfAbsent(index, () => TransformationController());

  void _move(int delta) {
    final next = _currentIndex + delta;
    if (next < 0 || next >= widget.items.length) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(next);
    } else {
      _pageController.animateToPage(next,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic);
    }
  }

  void _zoom(double factor) {
    final controller = _transform(_currentIndex);
    final scale =
        (controller.value.getMaxScaleOnAxis() * factor).clamp(1.0, 5.0);
    final size = MediaQuery.sizeOf(context);
    controller.value = Matrix4.identity()
      ..translateByDouble(
          size.width * (1 - scale) / 2, size.height * (1 - scale) / 2, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    if (widget.items.isEmpty) {
      _currentIndex = 0;
      _pageController = PageController();
      return;
    }
    _currentIndex =
        widget.initialIndex.clamp(0, widget.items.length - 1).toInt();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _transforms.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('图片预览'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text(
            '没有可预览的图片',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    final brand = ref.watch(brandProvider);
    final current = widget.items[_currentIndex];
    final caption = (current.caption ?? '').trim();
    final canDownload = widget.showDownload && current.url.trim().isNotEmpty;
    final desktop = MediaQuery.sizeOf(context).width >= 840;
    return CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.maybePop(context),
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(-1),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(1),
          const SingleActivator(LogicalKeyboardKey.equal): () => _zoom(1.25),
          const SingleActivator(LogicalKeyboardKey.minus): () => _zoom(.8),
          const SingleActivator(LogicalKeyboardKey.digit0): () =>
              _transform(_currentIndex).value = Matrix4.identity(),
        },
        child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                title: Text(current.title ?? '图片预览'),
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                actions: [
                  if (desktop) ...[
                    IconButton(
                        tooltip: '上一张（←）',
                        onPressed: _currentIndex > 0 ? () => _move(-1) : null,
                        icon: const Icon(Icons.chevron_left)),
                    IconButton(
                        tooltip: '下一张（→）',
                        onPressed: _currentIndex < widget.items.length - 1
                            ? () => _move(1)
                            : null,
                        icon: const Icon(Icons.chevron_right)),
                    IconButton(
                        tooltip: '缩小（−）',
                        onPressed: () => _zoom(.8),
                        icon: const Icon(Icons.remove)),
                    IconButton(
                        tooltip: '适应窗口（0）',
                        onPressed: () => _transform(_currentIndex).value =
                            Matrix4.identity(),
                        icon: const Icon(Icons.fit_screen)),
                    IconButton(
                        tooltip: '放大（+）',
                        onPressed: () => _zoom(1.25),
                        icon: const Icon(Icons.add)),
                  ],
                  if (widget.items.length > 1)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14)),
                        ),
                        child: Text(
                          '${_currentIndex + 1}/${widget.items.length}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ),
                ],
              ),
              body: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics:
                          desktop ? const NeverScrollableScrollPhysics() : null,
                      itemCount: widget.items.length,
                      onPageChanged: (index) {
                        setState(() => _currentIndex = index);
                      },
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            return InteractiveViewer(
                              transformationController: _transform(index),
                              trackpadScrollCausesScale: desktop,
                              minScale: 0.8,
                              maxScale: 5,
                              child: SizedBox(
                                width: constraints.maxWidth,
                                height: constraints.maxHeight,
                                child: Center(
                                  child: _previewImage(
                                    brand: brand,
                                    item: item,
                                    width: constraints.maxWidth,
                                    height: constraints.maxHeight,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (caption.isNotEmpty || canDownload)
                    _bottomPanel(
                      caption: caption,
                      accentColor: brand.primaryColor,
                      showDownload: canDownload,
                    ),
                ],
              ),
            )));
  }

  Widget _previewImage({
    required AppBrand brand,
    required PreviewImageEntry item,
    required double width,
    required double height,
  }) {
    final filePath = item.filePath?.trim() ?? '';
    if (filePath.isNotEmpty) {
      return Image.file(
        File(filePath),
        width: width,
        height: height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      );
    }
    return CachedGatewayImage(
      url: item.url,
      width: width,
      height: height,
      fit: BoxFit.contain,
      showDownload: false,
      accentColor: brand.primaryColor,
      cacheWidth: _previewCacheWidth(width),
    );
  }

  int _previewCacheWidth(double viewportWidth) {
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final targetWidth = (viewportWidth * devicePixelRatio).round();
    return targetWidth.clamp(1080, 2160).toInt();
  }

  Widget _bottomPanel({
    required String caption,
    required Color accentColor,
    required bool showDownload,
  }) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.86),
          border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: caption.isEmpty
                  ? const SizedBox.shrink()
                  : Text(
                      caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.35,
                      ),
                    ),
            ),
            if (showDownload) ...[
              const SizedBox(width: 12),
              _downloadButton(accentColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _downloadButton(Color accentColor) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _isSaving ? null : _saveCurrentImage,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accentColor.withValues(alpha: 0.26)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isSaving)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accentColor,
                  ),
                )
              else
                Icon(Icons.download_rounded, color: accentColor),
              const SizedBox(width: 6),
              Text(
                _isSaving ? '保存中' : '保存',
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveCurrentImage() async {
    if (_isSaving || widget.items.isEmpty) return;
    final current = widget.items[_currentIndex];
    if (current.url.trim().isEmpty) return;
    setState(() => _isSaving = true);
    try {
      await saveImageWithUserFlow(
          context, ref, widget.items[_currentIndex].url);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(friendlyError(error, fallback: '图片下载失败，请稍后重试。'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
