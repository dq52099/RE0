import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:re0/core/api_error.dart';
import 'package:re0/core/gateway_client.dart';
import 'package:re0/core/image_request_recovery.dart';
import 'package:re0/core/providers.dart';

ResponseBody jsonBody(Map<String, dynamic> body, [int code = 200]) =>
    ResponseBody.fromString(jsonEncode(body), code, headers: {
      Headers.contentTypeHeader: ['application/json']
    });

class ScriptedAdapter implements HttpClientAdapter {
  ScriptedAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions, Stream<Uint8List>?)
      handler;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      handler(options, requestStream);
  @override
  void close({bool force = false}) {}
}

Dio network(
        Future<ResponseBody> Function(RequestOptions, Stream<Uint8List>?)
            handler) =>
    Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = ScriptedAdapter(handler);

Never disconnected(RequestOptions options) => throw DioException(
    requestOptions: options, type: DioExceptionType.connectionError);

final result = {
  'data': [
    {'url': 'https://example.test/result.png'}
  ]
};

Map<String, dynamic> outcome() => {
      'status': 'completed',
      'response_status': 200,
      'response': result,
    };

Future<SharedPreferences> freshPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

class ResumeGateway extends GatewayClient {
  ResumeGateway(this.action);
  final String action;
  int reads = 0;
  final ready = Completer<Map<String, dynamic>>();
  @override
  Future<Map<String, dynamic>?> pendingImageRequest() async => {
        'request_id': 'saved_request_example',
        'action': action,
        'prompt': '原来的图片描述',
        'count': 1,
      };
  @override
  Future<Map<String, dynamic>?> recoverPendingImageRequest() {
    reads++;
    return ready.future;
  }
}

class RetryingResumeGateway extends ResumeGateway {
  RetryingResumeGateway(super.action);
  @override
  Future<Map<String, dynamic>?> recoverPendingImageRequest() async {
    reads++;
    if (reads == 1) throw const GatewayException('登录已失效', statusCode: 401);
    return result;
  }
}

void main() {
  test('normal image call stays synchronous and does not poll', () async {
    final prefs = await freshPrefs();
    var posts = 0;
    final dio = network((options, _) async {
      expect(options.method, 'POST');
      posts++;
      expect(jsonDecode(prefs.getString('pending')!)['request_id'],
          options.headers['X-Image-Request-Id']);
      return jsonBody(result);
    });
    final recovery =
        ImageRequestRecovery(dio: dio, prefs: prefs, storageKey: 'pending');
    final value = await recovery.run(
        action: 'generate',
        prompt: 'hello',
        count: 1,
        submit: (id) => dio.post('/api/images/generate',
            options: Options(headers: {'X-Image-Request-Id': id})));
    expect(value, result);
    expect(posts, 1);
    expect(recovery.pending, isNull);
  });

  test('lost response and repeated outages only query the accepted image',
      () async {
    final prefs = await freshPrefs();
    var posts = 0, queries = 0;
    final messages = <String?>[];
    final dio = network((options, _) async {
      if (options.method == 'POST') {
        posts++;
        disconnected(options);
      }
      queries++;
      if (queries == 1) disconnected(options);
      return jsonBody(queries == 2 ? {'status': 'running'} : outcome());
    });
    final recovery = ImageRequestRecovery(
        dio: dio,
        prefs: prefs,
        storageKey: 'pending',
        onStatus: messages.add,
        retryDelay: Duration.zero);
    final value = await recovery.run(
        action: 'generate',
        prompt: 'hello',
        count: 1,
        submit: (id) => dio.post('/api/images/generate'));
    expect(value, result);
    expect(posts, 1);
    expect(queries, 3);
    expect(
        messages.whereType<String>().any((s) => s.contains('网络暂不可用')), isTrue);
    expect(recovery.pending, isNull);
  });

  test('an incomplete response is recovered instead of losing its request ID',
      () async {
    final prefs = await freshPrefs();
    var posts = 0, queries = 0;
    final dio = network((options, _) async {
      if (options.method == 'POST') {
        posts++;
        return jsonBody({'unexpected': 'proxy response'});
      }
      queries++;
      return jsonBody(outcome());
    });
    final recovery =
        ImageRequestRecovery(dio: dio, prefs: prefs, storageKey: 'pending');
    expect(
        await recovery.run(
            action: 'generate',
            prompt: 'hello',
            count: 1,
            submit: (id) => dio.post('/api/images/generate')),
        result);
    expect(posts, 1);
    expect(queries, 1);
    expect(recovery.pending, isNull);
  });

  test('confirmed provider failure is not retried as a network failure',
      () async {
    final prefs = await freshPrefs();
    var calls = 0;
    final dio = network((options, _) async {
      calls++;
      return jsonBody({
        'detail': '线路额度不足',
        'image_request_id': options.headers['X-Image-Request-Id']
      }, 502);
    });
    final recovery =
        ImageRequestRecovery(dio: dio, prefs: prefs, storageKey: 'pending');
    await expectLater(
        recovery.run(
            action: 'generate',
            prompt: 'hello',
            count: 1,
            submit: (id) => dio.post('/api/images/generate',
                options: Options(headers: {'X-Image-Request-Id': id}))),
        throwsA(isA<DioException>()));
    expect(calls, 1);
    expect(recovery.pending, isNull);
  });

  test('reopening the application restores an accepted result without POST',
      () async {
    final prefs = await freshPrefs();
    final first = ImageRequestRecovery(
        dio: network((_, __) async => jsonBody(result)),
        prefs: prefs,
        storageKey: 'pending');
    final sent = Completer<void>();
    final waiting = first.run(
        action: 'edit',
        prompt: '原图编辑',
        count: 1,
        submit: (id) {
          sent.complete();
          return Completer<Response<dynamic>>().future;
        });
    final stopped = expectLater(waiting, throwsA(isA<GatewayException>()));
    await sent.future;
    first.stop();
    await stopped;
    expect(first.pending!['action'], 'edit');
    final second = ImageRequestRecovery(
        dio: network((options, _) async {
          expect(options.method, 'GET');
          return jsonBody(outcome());
        }),
        prefs: prefs,
        storageKey: 'pending');
    expect(await second.resume(), result);
    expect(second.pending, isNull);
  });

  test(
      'unknown and interrupted requests are not silently regenerated after restart',
      () async {
    for (final interrupted in [false, true]) {
      final prefs = await freshPrefs();
      await prefs.setString(
          'pending', jsonEncode({'request_id': 'existing_request_example'}));
      final dio = network((options, _) async {
        expect(options.method, 'GET');
        return interrupted
            ? jsonBody({'status': 'interrupted', 'detail': '请先查看图片记录'})
            : jsonBody({'detail': '图片请求不存在。'}, 404);
      });
      final recovery =
          ImageRequestRecovery(dio: dio, prefs: prefs, storageKey: 'pending');
      await expectLater(recovery.resume(), throwsA(isA<GatewayException>()));
      expect(recovery.pending, isNull);
    }
  });

  test('a dropped upload gets a fresh multipart body with the same request ID',
      () async {
    await freshPrefs();
    final temporary = await Directory.systemTemp.createTemp('re0-upload-test-');
    addTearDown(() => temporary.delete(recursive: true));
    final file = await File('${temporary.path}/reference.png')
        .writeAsBytes([1, 2, 3, 4]);
    final forms = <FormData>[];
    final ids = <String>[];
    final uploads = <List<int>>[];
    final dio = network((options, stream) async {
      if (options.path == '/api/auth/me') return jsonBody({'id': 'test-user'});
      if (options.path == '/api/meta/image-capabilities') {
        return jsonBody({
          'request_recovery': {'enabled': true}
        });
      }
      if (options.method == 'GET') return jsonBody({'detail': '图片请求不存在。'}, 404);
      forms.add(options.data as FormData);
      ids.add(options.headers['X-Image-Request-Id'] as String);
      uploads.add([for (final part in await stream!.toList()) ...part]);
      if (forms.length == 1) disconnected(options);
      return jsonBody(result);
    });
    final client = GatewayClient(dio: dio);
    await client.updateBaseUrl('https://example.test');
    await client.checkAuth();
    expect(
        await client.recall(
            'hello', file.path, 1, 'auto', 'auto', 'auto', 'png'),
        result);
    expect(forms, hasLength(2));
    expect(identical(forms[0], forms[1]), isFalse);
    expect(ids[0], ids[1]);
    for (final upload in uploads) {
      expect(upload.join(','), contains('1,2,3,4'));
    }
  });

  test(
      'expired login retains the pending request in its original account scope',
      () async {
    final prefs = await freshPrefs();
    await prefs.setString(
        'account-one', jsonEncode({'request_id': 'existing_request_example'}));
    final dio = network((_, __) async => jsonBody({'detail': '登录已失效'}, 401));
    final one =
        ImageRequestRecovery(dio: dio, prefs: prefs, storageKey: 'account-one');
    await expectLater(one.resume(), throwsA(isA<DioException>()));
    expect(one.pending, isNotNull);
    final two =
        ImageRequestRecovery(dio: dio, prefs: prefs, storageKey: 'account-two');
    expect(two.pending, isNull);
  });

  for (final switchServer in [false, true]) {
    test(
        'changing ${switchServer ? 'server' : 'account'} during capability lookup stops submission',
        () async {
      await freshPrefs();
      final started = Completer<void>();
      final capability = Completer<ResponseBody>();
      var account = 'first-user';
      var posts = 0;
      var capabilityReads = 0;
      final dio = network((options, _) async {
        if (options.path == '/api/auth/me') return jsonBody({'id': account});
        if (options.path == '/api/meta/image-capabilities') {
          capabilityReads++;
          if (capabilityReads > 1) return jsonBody({});
          started.complete();
          return capability.future;
        }
        posts++;
        return jsonBody(result);
      });
      final client = GatewayClient(dio: dio);
      await client.updateBaseUrl('https://example.test');
      await client.checkAuth();
      final waiting =
          client.materialize('hello', 1, 'auto', 'auto', 'auto', 'png');
      final failed = expectLater(waiting, throwsA(isA<GatewayException>()));
      await started.future;
      if (switchServer) {
        await client.updateBaseUrl('https://other.example.test');
      } else {
        account = 'second-user';
      }
      await client.checkAuth();
      capability.complete(jsonBody({
        'request_recovery': {'enabled': true}
      }));
      await failed;
      expect(posts, 0);
      expect(
          await client.materialize(
              'new request', 1, 'auto', 'auto', 'auto', 'png'),
          result);
      expect(capabilityReads, 2);
      expect(posts, 1);
    });
  }

  for (final action in ['generate', 'edit']) {
    test('a previous $action recovery error does not block later recovery',
        () async {
      final client = RetryingResumeGateway(action);
      final container = ProviderContainer(
          overrides: [gatewayClientProvider.overrideWithValue(client)]);
      addTearDown(container.dispose);
      await container.read(imageRequestResumeProvider.future);
      expect(
          action == 'edit'
              ? container.read(editImagesProvider).hasError
              : container.read(generateImagesProvider).hasError,
          isTrue);
      container.invalidate(imageRequestResumeProvider);
      await container.read(imageRequestResumeProvider.future);
      final values = action == 'edit'
          ? container.read(editImagesProvider).valueOrNull
          : container.read(generateImagesProvider).valueOrNull;
      expect(values!.single['url'], 'https://example.test/result.png');
      expect(client.reads, 2);
      expect(container.read(activeImageTaskProvider), isNull);
    });

    test(
        'restored $action result reaches the frontend and releases the task lock',
        () async {
      final client = ResumeGateway(action);
      final container = ProviderContainer(
          overrides: [gatewayClientProvider.overrideWithValue(client)]);
      addTearDown(container.dispose);
      final restoring = container.read(imageRequestResumeProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(activeImageTaskProvider),
          action == 'edit' ? ImageTaskKind.edit : ImageTaskKind.generate);
      client.ready.complete(result);
      await restoring;
      await Future<void>.delayed(Duration.zero);
      final values = action == 'edit'
          ? container.read(editImagesProvider).valueOrNull
          : container.read(generateImagesProvider).valueOrNull;
      expect(values!.single['url'], 'https://example.test/result.png');
      expect(values.single['prompt'], '原来的图片描述');
      expect(client.reads, 1);
      expect(container.read(activeImageTaskProvider), isNull);
    });
  }
}
