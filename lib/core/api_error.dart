import 'package:dio/dio.dart';

class GatewayException implements Exception {
  const GatewayException(this.message);

  final String message;

  @override
  String toString() => message;
}

String friendlyError(Object error, {String fallback = '操作失败，请稍后重试。'}) {
  if (error is GatewayException) {
    return error.message;
  }
  if (error is DioException) {
    return _messageFromDio(error, fallback: fallback);
  }
  final text = error.toString().trim();
  if (text.isEmpty) {
    return fallback;
  }
  return text
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Invalid argument(s): ', '');
}

GatewayException gatewayException(
  Object error, {
  String fallback = '操作失败，请稍后重试。',
}) {
  return GatewayException(friendlyError(error, fallback: fallback));
}

String _messageFromDio(DioException error, {required String fallback}) {
  if (error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    return '连接超时，请检查网络后重试。';
  }
  if (error.type == DioExceptionType.connectionError) {
    return '无法连接服务器，请检查网络或网关地址。';
  }
  if (error.type == DioExceptionType.cancel) {
    return '请求已取消。';
  }

  final statusCode = error.response?.statusCode;
  final detail = _extractDetail(error.response?.data);
  if (detail != null && detail.isNotEmpty) {
    return detail;
  }
  if (statusCode == 401) {
    return '登录已失效，请重新登录。';
  }
  if (statusCode == 403) {
    return '没有权限执行此操作。';
  }
  if (statusCode == 404) {
    return '请求的资源不存在。';
  }
  if (statusCode == 409) {
    return '当前请求与已有数据冲突。';
  }
  if (statusCode != null && statusCode >= 500) {
    return '服务器暂时不可用，请稍后重试。';
  }
  return fallback;
}

String? _extractDetail(dynamic data) {
  if (data == null) {
    return null;
  }
  if (data is String) {
    return data;
  }
  if (data is Map) {
    final detail = data['detail'] ?? data['message'] ?? data['error'] ?? data['msg'];
    return _extractDetail(detail);
  }
  if (data is List && data.isNotEmpty) {
    final messages = data
        .map(_extractDetail)
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .toList();
    if (messages.isNotEmpty) {
      return messages.join('\n');
    }
  }
  return data.toString();
}
