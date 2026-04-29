import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class SavedImage {
  const SavedImage({
    required this.file,
    this.galleryUri,
  });

  final File file;
  final String? galleryUri;

  bool get savedToGallery => galleryUri != null && galleryUri!.isNotEmpty;
}

class ImageCacheService {
  ImageCacheService()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(minutes: 5),
          ),
        );

  static const MethodChannel _downloadsChannel = MethodChannel('re0/downloads');

  final Dio _dio;

  Future<File> cachedFileFor(String url, {bool forceRefresh = false}) async {
    final directory = await _cacheDirectory();
    final file = File('${directory.path}/${_cacheFileName(url)}');
    if (!forceRefresh && await file.exists()) {
      return file;
    }

    final tempFile = File('${file.path}.download');
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    await _dio.download(
      url,
      tempFile.path,
      deleteOnError: true,
      options: Options(responseType: ResponseType.bytes),
    );

    if (await file.exists()) {
      await file.delete();
    }
    return tempFile.rename(file.path);
  }

  Future<SavedImage> saveImageToDevice(
    String url, {
    required String albumName,
    bool overwrite = false,
  }) async {
    final cachedFile = await cachedFileFor(url);
    final downloadDirectory = await _downloadDirectory();
    final targetName = _downloadFileName(url);
    final targetFile = File('${downloadDirectory.path}/$targetName');
    if (overwrite && await targetFile.exists()) {
      await targetFile.delete();
    }
    final savedFile = await cachedFile.copy(targetFile.path);

    String? galleryUri;
    if (Platform.isAndroid) {
      try {
        galleryUri = await _downloadsChannel.invokeMethod<String>(
          'saveImageToGallery',
          {
            'path': savedFile.path,
            'fileName': _baseName(savedFile.path),
            'albumName': albumName,
            'overwrite': overwrite,
          },
        );
      } on PlatformException {
        galleryUri = null;
      } on MissingPluginException {
        galleryUri = null;
      }
    }

    return SavedImage(file: savedFile, galleryUri: galleryUri);
  }

  Future<bool> hasSavedImageForUrl(
    String url, {
    required String albumName,
  }) async {
    final downloadDirectory = await _downloadDirectory();
    final targetName = _downloadFileName(url);
    final targetFile = File('${downloadDirectory.path}/$targetName');
    if (await targetFile.exists()) {
      return true;
    }
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final uri = await _downloadsChannel.invokeMethod<String>(
        'findImageInGallery',
        {
          'fileName': targetName,
          'albumName': albumName,
        },
      );
      return uri != null && uri.isNotEmpty;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<int> cacheSizeBytes() async {
    final directory = await _cacheDirectory();
    var total = 0;
    if (!await directory.exists()) {
      return total;
    }

    await for (final entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total;
  }

  Future<void> removeCachedFileFor(String url) async {
    final directory = await _cacheDirectory();
    final file = File('${directory.path}/${_cacheFileName(url)}');
    final tempFile = File('${file.path}.download');
    if (await file.exists()) {
      await file.delete();
    }
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  }

  Future<void> clearCache() async {
    final directory = await _cacheDirectory();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await directory.create(recursive: true);
  }

  Future<Directory> _cacheDirectory() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/gateway_image_cache');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<Directory> _downloadDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory('${base.path}/downloads');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _cacheFileName(String url) {
    return 'img-${_stableHash(url)}${_extensionFromUrl(url)}';
  }

  String _downloadFileName(String url) {
    return 're0-${_stableHash(url)}${_extensionFromUrl(url)}';
  }

  String _extensionFromUrl(String url) {
    final parsed = Uri.tryParse(url);
    final path = parsed?.path.toLowerCase() ?? '';
    const extensions = ['.png', '.jpg', '.jpeg', '.webp', '.gif'];
    for (final extension in extensions) {
      if (path.endsWith(extension)) {
        return extension;
      }
    }
    return '.png';
  }

  String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  String _baseName(String path) {
    return path.split(Platform.pathSeparator).last;
  }
}
