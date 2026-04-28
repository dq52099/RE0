import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'compact_save_notice.dart';
import 'image_cache_service.dart';
import 'providers.dart';

Future<SavedImage?> saveImageWithUserFlow(
  BuildContext context,
  WidgetRef ref,
  String url,
) async {
  final imageUrl = url.trim();
  if (imageUrl.isEmpty) return null;

  final brand = ref.read(brandProvider);
  final cache = ref.read(imageCacheProvider);
  final alreadySaved = await cache.hasSavedImageForUrl(
    imageUrl,
    albumName: brand.galleryAlbumName,
  );
  if (alreadySaved && context.mounted) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('已保存过这张图片'),
        content: const Text('系统相册中已有这张图片，是否重新保存并覆盖之前的下载？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('重新保存'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return null;
    }
  }

  final saved = await cache.saveImageToDevice(
    imageUrl,
    albumName: brand.galleryAlbumName,
    overwrite: alreadySaved,
  );
  if (context.mounted) {
    showCompactSaveNotice(
      context,
      saved.savedToGallery ? '已保存到系统相册' : '已保存到本地',
    );
  }
  return saved;
}
