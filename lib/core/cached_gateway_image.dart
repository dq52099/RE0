import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  static const int _maxAutoRetries = 2;

  late Future<File> _imageFuture;
  bool _isSaving = false;
  int _retryCount = 0;
  Timer? _retryTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _imageFuture = _loadImage();
  }

  @override
  void didUpdateWidget(CachedGatewayImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _retryTimer?.cancel();
      _retryCount = 0;
      _imageFuture = _loadImage();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<File> _loadImage({bool forceRefresh = false}) {
    return ref
        .read(imageCacheProvider)
        .cachedFileFor(widget.url, forceRefresh: forceRefresh);
  }

  void _scheduleRetry() {
    if (_retryCount >= _maxAutoRetries || _retryTimer?.isActive == true) {
      return;
    }
    final nextRetry = _retryCount + 1;
    _retryTimer = Timer(Duration(milliseconds: 600 * nextRetry), () {
      if (!mounted) return;
      setState(() {
        _retryCount = nextRetry;
        _imageFuture = _loadImage(forceRefresh: true);
      });
    });
  }

  void _retryNow() {
    _retryTimer?.cancel();
    setState(() {
      _retryCount = 0;
      _imageFuture = _loadImage(forceRefresh: true);
    });
  }

  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    try {
      await saveImageWithUserFlow(context, ref, widget.url);
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final memoryBytes = _dataUriBytes(widget.url);
    if (memoryBytes != null) {
      final memoryImage = Image.memory(
        memoryBytes,
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
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.25),
          child: const Icon(Icons.broken_image_outlined),
        ),
      );
      return widget.borderRadius == null
          ? memoryImage
          : ClipRRect(borderRadius: widget.borderRadius!, child: memoryImage);
    }

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
          _scheduleRetry();
          return _networkFallback();
        }

        return Container(
          width: widget.width,
          height: widget.height ?? 220,
          alignment: Alignment.center,
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.25),
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
            color: Colors.black.withValues(alpha: 0.42),
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(13),
            child: Ink(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: IconButton(
                tooltip: '下载到手机',
                color: Colors.white,
                onPressed: _isSaving ? null : _saveImage,
                icon: _isSaving
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 21),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _networkFallback() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _retryNow,
        child: Container(
          width: widget.width,
          height: widget.height ?? 220,
          alignment: Alignment.center,
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.25),
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }

  Uint8List? _dataUriBytes(String value) {
    final url = value.trim();
    if (!url.startsWith('data:image/')) return null;
    final marker = url.indexOf('base64,');
    if (marker < 0) return null;
    try {
      return base64Decode(url.substring(marker + 'base64,'.length));
    } catch (_) {
      return null;
    }
  }
}
