import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.appName,
    required this.packageName,
    required this.latestVersionName,
    required this.latestVersionCode,
    required this.currentVersionCode,
    required this.available,
    required this.downloadUrl,
    required this.fileSize,
    required this.sha256,
    required this.releaseNotes,
    required this.releaseUrl,
  });

  final String appName;
  final String packageName;
  final String latestVersionName;
  final int latestVersionCode;
  final int currentVersionCode;
  final bool available;
  final String downloadUrl;
  final int fileSize;
  final String sha256;
  final String releaseNotes;
  final String releaseUrl;
}

class AppUpdateService {
  AppUpdateService({
    required this.repository,
    required this.assetNamePrefix,
    required this.appId,
    required this.appName,
    required this.packageName,
    required this.currentVersionName,
    required this.currentVersionCode,
  }) : _dio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(minutes: 5),
            headers: {'Accept': 'application/vnd.github+json'},
          ),
        );

  static const MethodChannel _channel = MethodChannel('re0/downloads');

  final Dio _dio;
  final String repository;
  final String assetNamePrefix;
  final String appId;
  final String appName;
  final String packageName;
  final String currentVersionName;
  final int currentVersionCode;

  Future<AppUpdateInfo> checkForUpdate() async {
    final response = await _dio.get(
      'https://api.github.com/repos/$repository/releases/latest',
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final latestVersionName =
        _normalizeVersion(data['tag_name']?.toString() ?? '');
    final asset = _selectApkAsset(data['assets'] as List? ?? []);
    final releaseNotes = data['body']?.toString().trim();

    return AppUpdateInfo(
      appName: appName,
      packageName: packageName,
      latestVersionName: latestVersionName,
      latestVersionCode: _versionToCode(latestVersionName),
      currentVersionCode: currentVersionCode,
      available: _compareVersions(latestVersionName, currentVersionName) > 0,
      downloadUrl: asset['browser_download_url']?.toString() ?? '',
      fileSize: _asInt(asset['size']),
      sha256: '',
      releaseNotes: (releaseNotes == null || releaseNotes.isEmpty)
          ? 'GitHub Release 最新安装包。'
          : releaseNotes,
      releaseUrl: data['html_url']?.toString() ?? '',
    );
  }

  Future<File> downloadUpdate(
    AppUpdateInfo info, {
    void Function(int received, int total)? onProgress,
  }) async {
    final directory = await getTemporaryDirectory();
    final updatesDirectory = Directory('${directory.path}/app_updates');
    if (!await updatesDirectory.exists()) {
      await updatesDirectory.create(recursive: true);
    }

    final apkFile = File(
      '${updatesDirectory.path}/$appId-${info.latestVersionCode}.apk',
    );
    if (await apkFile.exists()) {
      await apkFile.delete();
    }

    await _dio.download(
      info.downloadUrl,
      apkFile.path,
      deleteOnError: true,
      onReceiveProgress: onProgress,
      options: Options(responseType: ResponseType.bytes),
    );
    return apkFile;
  }

  Future<void> openInstaller(File apkFile) async {
    await _channel.invokeMethod<bool>(
      'openApk',
      {'path': apkFile.path},
    );
  }

  Map<String, dynamic> _selectApkAsset(List<dynamic> assets) {
    final typedAssets = assets
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) {
      final name = item['name']?.toString().toLowerCase() ?? '';
      return name.endsWith('.apk');
    }).toList();
    if (typedAssets.isEmpty) {
      throw StateError('Release 中没有 APK 安装包。');
    }
    return typedAssets.firstWhere(
      (item) => item['name'].toString().contains(assetNamePrefix),
      orElse: () => typedAssets.first,
    );
  }

  String _normalizeVersion(String value) {
    final normalized = value.trim();
    return normalized.startsWith('v') ? normalized.substring(1) : normalized;
  }

  int _compareVersions(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    for (var index = 0; index < 3; index += 1) {
      final diff = leftParts[index] - rightParts[index];
      if (diff != 0) return diff;
    }
    return 0;
  }

  List<int> _versionParts(String value) {
    final normalized = _normalizeVersion(value).split('+').first;
    final parts = normalized.split('.');
    return List<int>.generate(3, (index) {
      if (index >= parts.length) return 0;
      return int.tryParse(parts[index].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    });
  }

  int _versionToCode(String value) {
    final parts = _versionParts(value);
    return (parts[0] * 10000) + (parts[1] * 100) + parts[2];
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
