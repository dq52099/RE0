import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';

import 'api_error.dart';

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

  Future<T> _guard<T>(
    Future<T> Function() request, {
    String fallback = '请求失败，请稍后重试。',
  }) async {
    try {
      return await request();
    } catch (error) {
      throw gatewayException(error, fallback: fallback);
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    return _guard(() async {
      final res = await _dio.post('/api/auth/login', data: {
        'username': username,
        'password': password,
      });
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '登录失败，请检查账号和密码。');
  }

  Future<Map<String, dynamic>> bootstrap() async {
    return _guard(() async {
      final res = await _dio.get('/api/bootstrap');
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '读取登录配置失败。');
  }

  Future<Map<String, dynamic>> register(
    String username,
    String displayName,
    String password,
  ) async {
    return _guard(() async {
      final res = await _dio.post('/api/auth/register', data: {
        'username': username,
        'display_name': displayName,
        'password': password,
      });
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '注册失败，请稍后重试。');
  }

  Future<Map<String, dynamic>> checkAuth() async {
    return _guard(() async {
      final res = await _dio.get('/api/auth/me');
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '登录状态已失效。');
  }

  Future<void> logout() async {
    await _guard(() async {
      await _dio.post('/api/auth/logout');
      await cookieJar?.deleteAll();
    }, fallback: '退出登录失败。');
  }

  Future<Map<String, dynamic>> checkAppUpdate(
    String appId,
    int currentVersionCode,
  ) async {
    return _guard(() async {
      final res = await _dio.get(
        '/api/mobile/apps/$appId/update',
        queryParameters: {'current_version_code': currentVersionCode},
      );
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '检查更新失败。');
  }

  Future<void> downloadFile(
    String url,
    String savePath, {
    ProgressCallback? onReceiveProgress,
  }) async {
    await _guard(() async {
      await _dio.download(
        url,
        savePath,
        deleteOnError: true,
        onReceiveProgress: onReceiveProgress,
        options: Options(responseType: ResponseType.bytes),
      );
    }, fallback: '下载失败。');
  }

  Future<Map<String, dynamic>> imageCapabilities() async {
    return _guard(() async {
      final res = await _dio.get('/api/meta/image-capabilities');
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '读取图片参数失败。');
  }

  Future<Map<String, dynamic>> materialize(
    String runes,
    int count,
    String size,
    String quality,
    String background,
    String outputFormat,
  ) async {
    return _guard(() async {
      final res = await _dio.post('/api/images/generate', data: {
        'prompt': runes,
        'n': count,
        'size': size,
        'quality': quality,
        'background': background,
        'output_format': outputFormat,
        'response_format': 'url',
      });
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '图片生成失败。');
  }

  Future<Map<String, dynamic>> recall(
    String runes,
    String imagePath,
    int count,
    String size,
    String quality,
    String background,
    String outputFormat,
  ) async {
    return _guard(() async {
      final formData = FormData.fromMap({
        'prompt': runes,
        'n': count,
        'size': size,
        'quality': quality,
        'background': background,
        'output_format': outputFormat,
        'response_format': 'url',
        'image': await MultipartFile.fromFile(imagePath),
      });
      final res = await _dio.post('/api/images/edit', data: formData);
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '图片修改失败。');
  }

  Future<Map<String, dynamic>> getHistory(
    int page, {
    int pageSize = 30,
    String? keyword,
    String? action,
    String? status,
  }) async {
    return _guard(() async {
      final queryParameters = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      final search = keyword?.trim();
      if (search != null && search.isNotEmpty) {
        queryParameters['keyword'] = search;
        queryParameters['q'] = search;
        queryParameters['query'] = search;
      }
      if (action != null && action.isNotEmpty) {
        queryParameters['action'] = action;
      }
      if (status != null && status.isNotEmpty) {
        queryParameters['status'] = status;
      }
      final res = await _dio.get(
        '/api/images/history',
        queryParameters: queryParameters,
      );
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '读取历史失败。');
  }

  Future<void> deleteHistoryItem(String id) async {
    await _guard(() async {
      await _dio.delete('/api/images/history/$id');
    }, fallback: '删除图片记录失败。');
  }

  Future<Map<String, dynamic>> updateMyProfile(
    String username,
    String displayName,
  ) async {
    return _guard(() async {
      final res = await _dio.post('/api/me/profile', data: {
        'username': username,
        'display_name': displayName,
      });
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '保存个人资料失败。');
  }

  Future<void> changeMyPassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _guard(() async {
      await _dio.post('/api/me/password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
    }, fallback: '修改密码失败。');
  }

  Future<Map<String, dynamic>> adminOverview() async {
    return _getMap('/api/admin/overview', fallback: '读取系统概览失败。');
  }

  Future<List<dynamic>> adminUsers() async {
    return _getList('/api/admin/users', fallback: '读取用户列表失败。');
  }

  Future<dynamic> saveAdminUser(String? id, Map<String, dynamic> payload) async {
    return _guard(() async {
      final res = id == null
          ? await _dio.post('/api/admin/users', data: payload)
          : await _dio.put('/api/admin/users/$id', data: payload);
      return res.data;
    }, fallback: '保存用户失败。');
  }

  Future<List<dynamic>> adminGroups() async {
    return _getList('/api/admin/groups', fallback: '读取用户组失败。');
  }

  Future<dynamic> saveAdminGroup(String? id, Map<String, dynamic> payload) async {
    return _guard(() async {
      final res = id == null
          ? await _dio.post('/api/admin/groups', data: payload)
          : await _dio.put('/api/admin/groups/$id', data: payload);
      return res.data;
    }, fallback: '保存用户组失败。');
  }

  Future<List<dynamic>> adminRoles() async {
    return _getList('/api/admin/roles', fallback: '读取角色失败。');
  }

  Future<dynamic> saveAdminRole(String? id, Map<String, dynamic> payload) async {
    return _guard(() async {
      final res = id == null
          ? await _dio.post('/api/admin/roles', data: payload)
          : await _dio.put('/api/admin/roles/$id', data: payload);
      return res.data;
    }, fallback: '保存角色失败。');
  }

  Future<List<dynamic>> adminPermissions() async {
    return _getList('/api/admin/permissions', fallback: '读取权限字典失败。');
  }

  Future<Map<String, dynamic>> adminSystemSettings() async {
    return _getMap('/api/admin/system-settings', fallback: '读取系统设置失败。');
  }

  Future<Map<String, dynamic>> saveAdminSystemSettings(
    Map<String, dynamic> payload,
  ) async {
    return _guard(() async {
      final res = await _dio.post('/api/admin/system-settings', data: payload);
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '保存系统设置失败。');
  }

  Future<Map<String, dynamic>> probeImageCapabilities() async {
    return _guard(() async {
      final res = await _dio.post(
        '/api/admin/image-capabilities/probe',
        data: {'save_results': true},
      );
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '探测图片尺寸失败。');
  }

  Future<List<dynamic>> adminApiKeys() async {
    return _getList('/api/admin/api-keys', fallback: '读取 API Key 失败。');
  }

  Future<dynamic> saveAdminApiKey(String? id, Map<String, dynamic> payload) async {
    return _guard(() async {
      final res = id == null
          ? await _dio.post('/api/admin/api-keys', data: payload)
          : await _dio.put('/api/admin/api-keys/$id', data: payload);
      return res.data;
    }, fallback: '保存 API Key 失败。');
  }

  Future<Map<String, dynamic>> rotateAdminApiKey(
    String id,
    String rawKey,
  ) async {
    return _guard(() async {
      final res = await _dio.post(
        '/api/admin/api-keys/$id/rotate',
        data: {'raw_key': rawKey},
      );
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '轮换 API Key 失败。');
  }

  Future<List<dynamic>> adminAuditLogs() async {
    return _getList('/api/admin/audit-logs', fallback: '读取审计日志失败。');
  }

  Future<Map<String, dynamic>> _getMap(
    String path, {
    required String fallback,
  }) async {
    return _guard(() async {
      final res = await _dio.get(path);
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: fallback);
  }

  Future<List<dynamic>> _getList(
    String path, {
    required String fallback,
  }) async {
    return _guard(() async {
      final res = await _dio.get(path);
      return List<dynamic>.from(res.data as List);
    }, fallback: fallback);
  }
}
