import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re0/core/api_error.dart';
import 'package:re0/core/app_update_service.dart';
import 'package:re0/core/gateway_client.dart';
import 'package:re0/core/providers.dart';

class BatchGateway extends GatewayClient {
  int calls = 0;
  Completer<Map<String, dynamic>>? gate;

  Future<Map<String, dynamic>> result() async {
    calls++;
    if (gate != null) return gate!.future;
    if (calls == 2) throw const GatewayException('请求超时');
    return {
      'data': [
        {'url': 'https://example.test/first.png'}
      ]
    };
  }

  @override
  Future<Map<String, dynamic>> materialize(String runes, int count, String size,
          String quality, String background, String outputFormat,
          {int? clientBatchIndex, String? imageMode}) =>
      result();

  @override
  Future<Map<String, dynamic>> recall(String runes, String imagePath, int count,
          String size, String quality, String background, String outputFormat,
          {int? clientBatchIndex, String? imageMode}) =>
      result();
}

void main() {
  for (final edit in [false, true]) {
    for (final candidates in [false, true]) {
      test(
          'Keeps completed images after ${edit ? 'edit' : 'generate'} ${candidates ? 'candidates' : 'batch'} fails',
          () async {
        final gateway = BatchGateway();
        final container = ProviderContainer(
            overrides: [gatewayClientProvider.overrideWithValue(gateway)]);
        addTearDown(container.dispose);
        final provider = edit ? editImagesProvider : generateImagesProvider;
        await container.read(provider.future);
        final String? notice;
        if (edit) {
          final notifier = container.read(editImagesProvider.notifier);
          notice = candidates
              ? await notifier.recallPrompts(['one', 'two'], 'reference.png',
                  'auto', 'high', 'auto', 'png', 'vip')
              : await notifier.recall('one', 'reference.png', 2, 'auto', 'high',
                  'auto', 'png', 'vip');
        } else {
          final notifier = container.read(generateImagesProvider.notifier);
          notice = candidates
              ? await notifier.materializePrompts(
                  ['one', 'two'], 'auto', 'high', 'auto', 'png', 'vip')
              : await notifier.materialize(
                  'one', 2, 'auto', 'high', 'auto', 'png', 'vip');
        }
        expect(notice, contains('已完成 1 张'));
        expect(container.read(provider).valueOrNull!.single['url'],
            endsWith('first.png'));
        expect(container.read(activeImageTaskProvider), isNull);
        expect(container.read(imageTaskProgressProvider), isNull);
      });
    }
  }
  test('Rejects duplicate submissions while tracking actual progress',
      () async {
    final gateway = BatchGateway()..gate = Completer<Map<String, dynamic>>();
    final container = ProviderContainer(
        overrides: [gatewayClientProvider.overrideWithValue(gateway)]);
    addTearDown(container.dispose);
    await container.read(generateImagesProvider.future);
    final notifier = container.read(generateImagesProvider.notifier);
    final running =
        notifier.materialize('one', 1, 'auto', 'high', 'auto', 'png', 'vip');
    expect(container.read(imageTaskProgressProvider)!.completed, 0);
    expect(container.read(imageTaskProgressProvider)!.total, 1);
    await expectLater(
        notifier.materialize('two', 1, 'auto', 'high', 'auto', 'png', 'vip'),
        throwsA(isA<GatewayException>()));
    expect(gateway.calls, 1);
    gateway.gate!.complete({
      'data': [
        {'url': 'https://example.test/one.png'}
      ]
    });
    await running;
    expect(container.read(generateImagesProvider).valueOrNull, hasLength(1));
    expect(container.read(activeImageTaskProvider), isNull);
  });

  test('Uses gateway version codes and validates incomplete update metadata',
      () {
    final service = AppUpdateService(
        repository: 'example/re0',
        assetNamePrefix: 'RE0',
        appId: 're0',
        appName: 'RE0',
        packageName: 'com.dq52099.re0',
        currentVersionName: '1.2.33',
        currentVersionCode: 10233,
        currentReleaseTag: 'v1.2.33');
    final info = service.fromGatewayData({
      'available': true,
      'latest_version_code': 10234,
      'latest_version_name': '1.2.34',
      'download_url': 'https://example.test/latest.apk',
      'force_update': true
    });
    expect(info.latestVersionCode, 10234);
    expect(info.currentVersionCode, 10233);
    expect(info.forceUpdate, isTrue);
    expect(
        () => service.fromGatewayData({'available': true}), throwsStateError);
    expect(
        () => service.fromGatewayData({
              'available': true,
              'latest_version_code': 10232,
              'download_url': 'https://example.test/old.apk'
            }),
        throwsStateError);
    expect(service.fromGatewayData({'available': false}).available, isFalse);
  });
}
