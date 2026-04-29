import 'package:dio/dio.dart';

final RegExp _minLengthPattern = RegExp(
  r'string should have at least (\d+) characters',
  caseSensitive: false,
);
final RegExp _maxLengthPattern = RegExp(
  r'string should have at most (\d+) characters',
  caseSensitive: false,
);

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
  return _polishMessage(
      text
          .replaceFirst('Exception: ', '')
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Invalid argument(s): ', ''),
      fallback);
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
  if (statusCode == 404 &&
      (detail == null ||
          detail.trim().isEmpty ||
          detail.trim().toLowerCase() == 'not found')) {
    return '接口或资源不存在，请确认后端已部署最新版本。';
  }
  if (detail != null && detail.isNotEmpty) {
    return _polishMessage(detail, fallback);
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

String _polishMessage(String message, String fallback) {
  final text = message.trim();
  if (text.isEmpty) {
    return fallback;
  }

  final normalized = text.toLowerCase();
  if (normalized.contains('invalid username') ||
      normalized.contains('invalid password') ||
      normalized.contains('incorrect username') ||
      normalized.contains('incorrect password') ||
      normalized.contains('invalid credentials') ||
      normalized.contains('bad credentials')) {
    return '账号或密码不正确，请重新输入。';
  }
  if (normalized.contains('quota') ||
      normalized.contains('insufficient credits') ||
      normalized.contains('not enough credits')) {
    return '当前额度不足，请检查剩余额度或联系管理员。';
  }
  final minLengthMatch = _minLengthPattern.firstMatch(normalized);
  if (minLengthMatch != null) {
    return '输入内容至少需要 ${minLengthMatch.group(1)} 个字符。';
  }
  final maxLengthMatch = _maxLengthPattern.firstMatch(normalized);
  if (maxLengthMatch != null) {
    return '输入内容不能超过 ${maxLengthMatch.group(1)} 个字符。';
  }
  if (normalized.contains('string should match pattern')) {
    return '输入格式不正确，请按要求重新填写。';
  }
  if (normalized.contains('field required')) {
    return '请完整填写必填信息。';
  }
  if (normalized.contains('开放自助注册')) {
    return '当前网关暂未开放自助注册。';
  }
  if (normalized.contains('邀请码')) {
    return text;
  }
  if (normalized.contains('保留名称')) {
    return '这个账号名属于保留名称，请更换一个账号名。';
  }
  if (normalized.contains('already exists') ||
      normalized.contains('已存在') ||
      normalized.contains('已被占用')) {
    return '这个账号名已经被占用，请换一个。';
  }
  if (normalized.contains('已经发布到画廊')) {
    return '这张图片已经发布到画廊了。';
  }
  if (normalized.contains('今日已签到') || normalized.contains('already signed')) {
    return '已经签到过了，明天再来。';
  }
  if (normalized == 'not found') {
    return '接口或资源不存在，请确认后端已部署最新版本。';
  }
  if (normalized.contains('timed out') || normalized.contains('timeout')) {
    return '请求超时，请稍后重试。';
  }
  if (normalized.contains('rate limit') ||
      normalized.contains('too many requests')) {
    return '请求过于频繁，请稍后再试。';
  }
  if (normalized.contains('prompt') && normalized.contains('invalid')) {
    return '提示词格式不正确，请调整后再试。';
  }
  if (normalized.contains('image') &&
      (normalized.contains('failed') || normalized.contains('error'))) {
    return '图片处理失败，请更换图片或稍后重试。';
  }

  return text;
}

String? _extractDetail(dynamic data) {
  if (data == null) {
    return null;
  }
  if (data is String) {
    return data;
  }
  if (data is Map) {
    final detail =
        data['detail'] ?? data['message'] ?? data['error'] ?? data['msg'];
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
