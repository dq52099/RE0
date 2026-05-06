import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:re0/core/image_cache_service.dart';

const _pngBytes = <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImageCacheService', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('re0-image-cache-test-');
      PathProviderPlatform.instance = _FakePathProviderPlatform(root.path);
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    test('redownloads when cached file is not an image', () async {
      var downloadCount = 0;
      final cache = ImageCacheService(
        downloader: (_, savePath) async {
          downloadCount += 1;
          await File(savePath).writeAsBytes(_pngBytes);
        },
      );

      const url = 'https://image.6688667.xyz/files/history-image.png';
      final first = await cache.cachedFileFor(url);
      expect(downloadCount, 1);
      expect(await first.readAsBytes(), _pngBytes);

      await first.writeAsString('<html>login required</html>');
      final second = await cache.cachedFileFor(url);

      expect(downloadCount, 2);
      expect(second.path, first.path);
      expect(await second.readAsBytes(), _pngBytes);
    });
  });
}

class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform(this.rootPath);

  final String rootPath;

  @override
  Future<String?> getApplicationSupportPath() async => '$rootPath/support';

  @override
  Future<String?> getApplicationDocumentsPath() async => '$rootPath/documents';
}
