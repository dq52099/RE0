import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_error.dart';
import '../../core/cached_gateway_image.dart';
import '../../core/image_save_flow.dart';
import '../../core/providers.dart';

class PreviewImageEntry {
  const PreviewImageEntry({
    required this.url,
    this.title,
    this.caption,
  });

  final String url;
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(current.title ?? '图片预览'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (widget.items.length > 1)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.14)),
                ),
                child: Text(
                  '${_currentIndex + 1}/${widget.items.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
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
              itemCount: widget.items.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 5,
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        child: Center(
                          child: CachedGatewayImage(
                            url: item.url,
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            fit: BoxFit.contain,
                            showDownload: false,
                            accentColor: brand.primaryColor,
                            cacheWidth:
                                _previewCacheWidth(constraints.maxWidth),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (caption.isNotEmpty || widget.showDownload)
            _bottomPanel(
              caption: caption,
              accentColor: brand.primaryColor,
            ),
        ],
      ),
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
            if (widget.showDownload) ...[
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
