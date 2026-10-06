import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_error.dart';

bool isRecoverableImageConnection(Object error) {
  if (error is! DioException) return false;
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout ||
      (error.type == DioExceptionType.unknown && error.response == null)) {
    return true;
  }
  return [502, 503, 504].contains(error.response?.statusCode);
}

class ImageRequestRecovery {
  ImageRequestRecovery({
    required this.dio,
    required this.prefs,
    required this.storageKey,
    this.onStatus,
    this.retryDelay = const Duration(seconds: 3),
  });

  final Dio dio;
  final SharedPreferences prefs;
  final String storageKey;
  final void Function(String?)? onStatus;
  final Duration retryDelay;
  bool busy = false;
  bool _stopped = false;
  final Completer<void> _stop = Completer<void>();

  Map<String, dynamic>? get pending {
    final text = prefs.getString(storageKey);
    if (text == null) return null;
    return Map<String, dynamic>.from(jsonDecode(text) as Map);
  }

  void stop() {
    _stopped = true;
    if (!_stop.isCompleted) _stop.complete();
    onStatus?.call(null);
  }

  void _checkSession() {
    if (_stopped) throw const GatewayException('当前会话已结束；原图片请求保留在原账号下。');
  }

  Future<T> _untilStop<T>(Future<T> future) => Future.any<T>([
        future,
        _stop.future.then<T>((_) => throw const GatewayException('当前会话已结束。')),
      ]);

  Future<void> _pause() async {
    await Future.any([Future<void>.delayed(retryDelay), _stop.future]);
    _checkSession();
  }

  Future<void> _clear() async {
    _checkSession();
    if (!await prefs.remove(storageKey)) {
      throw const GatewayException('无法保存图片请求状态，请重新打开应用核对结果。');
    }
  }

  Future<Map<String, dynamic>> run({
    required String action,
    required String prompt,
    required int count,
    required Future<Response<dynamic>> Function(String id) submit,
  }) async {
    if (busy || pending != null) {
      throw const GatewayException('已有图片结果等待找回，请先恢复原请求。');
    }
    busy = true;
    final random = Random.secure();
    final id =
        're0_${List.generate(20, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
    try {
      _checkSession();
      final saved = await prefs.setString(
          storageKey,
          jsonEncode({
            'request_id': id,
            'action': action,
            'prompt': prompt,
            'count': count,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          }));
      if (!saved) throw const GatewayException('无法保存图片请求，请稍后重试。');
      _checkSession();
      try {
        final response = await _untilStop(submit(id));
        _checkSession();
        if (response.statusCode != 202 &&
            response.data is Map &&
            response.data['data'] is List) {
          await _clear();
          return Map<String, dynamic>.from(response.data as Map);
        }
      } catch (error) {
        _checkSession();
        final data = error is DioException ? error.response?.data : null;
        final confirmed = data is Map && data['image_request_id'] == id;
        if (confirmed || !isRecoverableImageConnection(error)) {
          await _clear();
          rethrow;
        }
      }
      return await _recover(id, submit: submit);
    } finally {
      busy = false;
      onStatus?.call(null);
    }
  }

  Future<Map<String, dynamic>?> resume() async {
    if (busy) return null;
    final job = pending;
    if (job == null) return null;
    busy = true;
    try {
      return await _recover(job['request_id'] as String);
    } finally {
      busy = false;
      onStatus?.call(null);
    }
  }

  Future<Map<String, dynamic>> _recover(
    String id, {
    Future<Response<dynamic>> Function(String id)? submit,
  }) async {
    onStatus?.call('连接中断，正在找回原请求的图片结果，请勿重复提交。');
    while (true) {
      _checkSession();
      Map<String, dynamic> item;
      try {
        final response = await _untilStop(dio.get('/api/images/requests/$id',
            options: Options(receiveTimeout: const Duration(seconds: 15))));
        _checkSession();
        item = Map<String, dynamic>.from(response.data as Map);
      } on DioException catch (error) {
        _checkSession();
        final data = error.response?.data;
        final missing = error.response?.statusCode == 404 &&
            data is Map &&
            data['detail'] == '图片请求不存在。';
        if (missing) {
          if (submit == null) {
            await _clear();
            throw const GatewayException('原请求未送达服务器，请重新提交图片生成。');
          }
          // The server confirmed that it never accepted this request. Reuse
          // its ID, including a fresh multipart body, so retries stay safe.
          try {
            final response = await _untilStop(submit(id));
            _checkSession();
            if (response.statusCode != 202 &&
                response.data is Map &&
                response.data['data'] is List) {
              await _clear();
              return Map<String, dynamic>.from(response.data as Map);
            }
          } catch (submissionError) {
            _checkSession();
            final body = submissionError is DioException
                ? submissionError.response?.data
                : null;
            if ((body is Map && body['image_request_id'] == id) ||
                !isRecoverableImageConnection(submissionError)) {
              await _clear();
              rethrow;
            }
          }
        } else if (!isRecoverableImageConnection(error)) {
          // Retain the ID on authentication or incompatible-server errors.
          // A later login can recover it without paying for another image.
          rethrow;
        }
        onStatus?.call('网络暂不可用，恢复连接后会继续找回图片结果。');
        await _pause();
        continue;
      }
      if (item['status'] == 'completed' || item['status'] == 'failed') {
        final body = Map<String, dynamic>.from(item['response'] as Map);
        final code = (item['response_status'] as num).toInt();
        await _clear();
        if (code >= 400) {
          throw DioException(
            requestOptions: RequestOptions(path: '/api/images/requests/$id'),
            response: Response(
                requestOptions:
                    RequestOptions(path: '/api/images/requests/$id'),
                statusCode: code,
                data: body),
            type: DioExceptionType.badResponse,
          );
        }
        return body;
      }
      if (item['status'] == 'interrupted') {
        await _clear();
        throw GatewayException(
            item['detail']?.toString() ?? '图片结果尚未确认，请先查看图片记录。');
      }
      if (item['status'] != 'running') {
        throw const GatewayException('无法确认图片请求状态，请先查看图片记录。');
      }
      onStatus?.call('服务器仍在处理原请求，完成后会自动显示图片。');
      await _pause();
    }
  }
}
