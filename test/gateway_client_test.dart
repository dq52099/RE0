import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/gateway_client.dart';

void main() {
  group('normalizeGatewayDownloadUrl', () {
    test('keeps relative gateway media paths on the configured gateway', () {
      expect(
        normalizeGatewayDownloadUrl(
          '/files/2026/05/06/avatar.png',
          'https://image.6688667.xyz',
        ),
        '/files/2026/05/06/avatar.png',
      );
    });

    test('rewrites absolute gateway media urls to the configured gateway', () {
      expect(
        normalizeGatewayDownloadUrl(
          'http://internal.example.test/files/2026/05/06/avatar.png?token=1',
          'https://image.6688667.xyz',
        ),
        'https://image.6688667.xyz/files/2026/05/06/avatar.png?token=1',
      );
    });

    test('rewrites share image urls to the configured gateway', () {
      expect(
        normalizeGatewayDownloadUrl(
          'http://testserver/s/abc123/image',
          'https://image.6688667.xyz',
        ),
        'https://image.6688667.xyz/s/abc123/image',
      );
    });

    test('does not rewrite non-gateway urls', () {
      expect(
        normalizeGatewayDownloadUrl(
          'https://cdn.example.test/assets/avatar.png',
          'https://image.6688667.xyz',
        ),
        'https://cdn.example.test/assets/avatar.png',
      );
    });
  });
}
