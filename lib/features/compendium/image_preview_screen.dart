import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cached_gateway_image.dart';
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
  });

  final List<PreviewImageEntry> items;
  final int initialIndex;

  @override
  ConsumerState<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends ConsumerState<ImagePreviewScreen> {
  late final PageController _pageController;
  late int _currentIndex;

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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(current.title ?? '图片预览'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          PageView.builder(
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
                          showDownload: true,
                          accentColor: brand.primaryColor,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          if (widget.items.length > 1)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Row(
                children: [
                  _navButton(
                    icon: Icons.chevron_left,
                    enabled: _currentIndex > 0,
                    onTap: () => _pageController.previousPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.58),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.items.length}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        if ((current.caption ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.52),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              current.caption!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _navButton(
                    icon: Icons.chevron_right,
                    enabled: _currentIndex < widget.items.length - 1,
                    onTap: () => _pageController.nextPage(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _navButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withOpacity(enabled ? 0.52 : 0.22),
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: enabled ? onTap : null,
        color: Colors.white,
        icon: Icon(icon),
      ),
    );
  }
}
