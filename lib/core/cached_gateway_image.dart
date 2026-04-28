import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_error.dart';
import 'image_cache_service.dart';
import 'providers.dart';
import 'top_toast.dart';

class CachedGatewayImage extends ConsumerStatefulWidget {
  const CachedGatewayImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.showDownload = true,
    this.accentColor,
    this.cacheWidth,
    this.cacheHeight,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool showDownload;
  final Color? accentColor;
  final int? cacheWidth;
  final int? cacheHeight;

  @override
  ConsumerState<CachedGatewayImage> createState() => _CachedGatewayImageState();
}

class _CachedGatewayImageState extends ConsumerState<CachedGatewayImage>
    with AutomaticKeepAliveClientMixin {
  late Future<File> _imageFuture;
  bool _isSaving = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _imageFuture = ref.read(imageCacheProvider).cachedFileFor(widget.url);
  }

  @override
  void didUpdateWidget(CachedGatewayImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _imageFuture = ref.read(imageCacheProvider).cachedFileFor(widget.url);
    }
  }

  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    try {
      final brand = ref.read(brandProvider);
      final saved = await ref
          .read(imageCacheProvider)
          .saveImageToDevice(widget.url, albumName: brand.galleryAlbumName);
      if (!mounted) return;
      final message = saved.savedToGallery
          ? '已保存到系统相册'
          : '已保存到本地: ${saved.file.path}';
      showTopToast(context, message);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(error, fallback: '图片下载失败，请稍后重试。'))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final image = FutureBuilder<File>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.file(
            snapshot.data!,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            cacheWidth: widget.cacheWidth,
            cacheHeight: widget.cacheHeight,
            filterQuality: FilterQuality.low,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _networkFallback(),
          );
        }

        if (snapshot.hasError) {
          return _networkFallback();
        }

        return Container(
          width: widget.width,
          height: widget.height ?? 220,
          alignment: Alignment.center,
          color: Theme.of(context).colorScheme.surface.withOpacity(0.25),
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );

    final clipped = widget.borderRadius == null
        ? image
        : ClipRRect(borderRadius: widget.borderRadius!, child: image);

    if (!widget.showDownload) {
      return clipped;
    }

    return Stack(
      children: [
        clipped,
        Positioned(
          right: 8,
          bottom: 8,
          child: Material(
            color: Colors.black.withOpacity(0.62),
            shape: CircleBorder(
              side: BorderSide(
                color: widget.accentColor ?? Theme.of(context).colorScheme.primary,
                width: 1,
              ),
            ),
            child: IconButton(
              tooltip: '下载到手机',
              color: Colors.white,
              onPressed: _isSaving ? null : _saveImage,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
            ),
          ),
        ),
      ],
    );
  }

  Widget _networkFallback() {
    return Image.network(
      widget.url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      filterQuality: FilterQuality.low,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(
        width: widget.width,
        height: widget.height ?? 220,
        alignment: Alignment.center,
        color: Theme.of(context).colorScheme.surface.withOpacity(0.25),
        child: const Icon(Icons.broken_image_outlined),
      ),
    );
  }
}
