import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cached_gateway_image.dart';
import '../../core/providers.dart';

class ImagePreviewScreen extends ConsumerWidget {
  const ImagePreviewScreen({
    super.key,
    required this.url,
    this.title,
  });

  final String url;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = ref.watch(brandProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title ?? '图片预览'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Center(
                child: CachedGatewayImage(
                  url: url,
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
      ),
    );
  }
}
