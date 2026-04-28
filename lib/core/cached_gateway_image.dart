import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_error.dart';
import 'image_save_flow.dart';
import 'providers.dart';

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
      await saveImageWithUserFlow(context, ref, widget.url);
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
            color: Colors.white.withOpacity(0.88),
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.22),
            shape: const CircleBorder(),
            child: Ink(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (widget.accentColor ?? Theme.of(context).colorScheme.primary)
                      .withOpacity(0.28),
                ),
              ),
              child: IconButton(
                tooltip: '下载到手机',
                color: widget.accentColor ?? Theme.of(context).colorScheme.primary,
                onPressed: _isSaving ? null : _saveImage,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
              ),
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
