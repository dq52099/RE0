import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';

class GatewayClient {
  late Dio _dio;
  String baseUrl = '';
  PersistCookieJar? cookieJar;

  GatewayClient() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      contentType: 'application/json',
    ));
  }

  Future<void> init(String url) async {
    baseUrl = url;
    _dio.options.baseUrl = url;
    final dir = await getApplicationDocumentsDirectory();
    cookieJar = PersistCookieJar(storage: FileStorage('${dir.path}/.cookies/'));
    _dio.interceptors.removeWhere((interceptor) => interceptor is CookieManager);
    _dio.interceptors.add(CookieManager(cookieJar!));
  }

  Future<void> updateBaseUrl(String url) async {
    baseUrl = url;
    _dio.options.baseUrl = url;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _dio.post('/api/auth/login', data: {
      'username': username,
      'password': password,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> checkAuth() async {
    final res = await _dio.get('/api/auth/me');
    return res.data;
  }

  Future<void> logout() async {
    await _dio.post('/api/auth/logout');
    await cookieJar?.deleteAll();
  }

  Future<List<Cookie>> webViewCookies() async {
    if (cookieJar == null || baseUrl.isEmpty) {
      return [];
    }
    return cookieJar!.loadForRequest(Uri.parse(baseUrl));
  }

  Future<Map<String, dynamic>> checkAppUpdate(
    String appId,
    int currentVersionCode,
  ) async {
    final res = await _dio.get(
      '/api/mobile/apps/$appId/update',
      queryParameters: {'current_version_code': currentVersionCode},
    );
    return res.data;
  }

  Future<void> downloadFile(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
  }) async {
    await _dio.download(
      url,
      savePath,
      deleteOnError: true,
      onReceiveProgress: onReceiveProgress,
      options: Options(responseType: ResponseType.bytes),
    );
  }

  Future<Map<String, dynamic>> materialize(String runes, int count, String size, String quality, String background) async {
    final res = await _dio.post('/api/images/generate', data: {
      'prompt': runes,
      'n': count,
      'size': size,
      'quality': quality,
      'background': background,
      'response_format': 'url',
    });
    return res.data;
  }

  Future<Map<String, dynamic>> recall(String runes, String imagePath, int count, String size) async {
    final formData = FormData.fromMap({
      'prompt': runes,
      'n': count,
      'size': size,
      'response_format': 'url',
      'image': await MultipartFile.fromFile(imagePath),
    });
    final res = await _dio.post('/api/images/edit', data: formData);
    return res.data;
  }

  Future<Map<String, dynamic>> getHistory(int page) async {
    final res = await _dio.get('/api/images/history', queryParameters: {
      'page': page,
      'page_size': 20,
    });
    return res.data;
  }
}
