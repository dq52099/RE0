import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';

import 'api_error.dart';
import 'prompt_assist.dart';

class GatewayClient {
  static const Duration _imageRequestTimeout = Duration(minutes: 20);

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
    _dio.interceptors
        .removeWhere((interceptor) => interceptor is CookieManager);
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

  Future<Map<String, dynamic>> sendEmailCode(
    String email,
    String purpose,
  ) async {
    return _guard(() async {
      final res = await _dio.post('/api/auth/email-code', data: {
        'email': email,
        'purpose': purpose,
      });
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '发送邮箱验证码失败。');
  }

  Future<Map<String, dynamic>> emailLogin(String email, String code) async {
    return _guard(() async {
      final res = await _dio.post('/api/auth/email-login', data: {
        'email': email,
        'code': code,
      });
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '邮箱验证码登录失败。');
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    return _guard(() async {
      final res = await _dio.post('/api/auth/password-reset', data: {
        'email': email,
      });
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '发送找回密码验证码失败。');
  }

  Future<Map<String, dynamic>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    return _guard(() async {
      final res = await _dio.post('/api/auth/password-reset/confirm', data: {
        'email': email,
        'code': code,
        'new_password': newPassword,
      });
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '重置密码失败。');
  }

  Future<Map<String, dynamic>> register(
    String username,
    String displayName,
    String invitationCode,
    String password, {
    String? email,
    String? emailCode,
  }) async {
    return _guard(() async {
      final emailText = email?.trim();
      final codeText = emailCode?.trim();
      final invitationText = invitationCode.trim();
      final res = await _dio.post('/api/auth/register', data: {
        'username': username,
        'display_name': displayName,
        if (invitationText.isNotEmpty) 'invitation_code': invitationText,
        'password': password,
        if (emailText != null && emailText.isNotEmpty) 'email': emailText,
        if (codeText != null && codeText.isNotEmpty) 'email_code': codeText,
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

  Future<void> clearLocalSession() async {
    await cookieJar?.deleteAll();
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
      final downloadUrl = normalizeGatewayDownloadUrl(url, baseUrl);
      await _dio.download(
        downloadUrl,
        savePath,
        deleteOnError: true,
        onReceiveProgress: onReceiveProgress,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: false,
          headers: {
            'Accept':
                'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
          },
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
        ),
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
    String outputFormat, {
    int? clientBatchIndex,
    String? imageMode,
  }) async {
    try {
      final res = await _dio.post(
        '/api/images/generate',
        data: {
          'prompt': runes,
          'n': count,
          'size': size,
          'quality': quality,
          'background': background,
          'output_format': outputFormat,
          'response_format': 'url',
          if (clientBatchIndex != null) 'client_batch_index': clientBatchIndex,
          if (imageMode != null && imageMode.isNotEmpty)
            'image_mode': imageMode,
        },
        options: Options(
          receiveTimeout: _imageRequestTimeout,
          sendTimeout: _imageRequestTimeout,
        ),
      );
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (error) {
      final partial = _partialImageResponse(error.response?.data);
      if (partial != null) return partial;
      throw gatewayException(error, fallback: '图片生成失败。');
    } catch (error) {
      throw gatewayException(error, fallback: '图片生成失败。');
    }
  }

  Future<Map<String, dynamic>> recall(
    String runes,
    String imagePath,
    int count,
    String size,
    String quality,
    String background,
    String outputFormat, {
    int? clientBatchIndex,
    String? imageMode,
  }) async {
    try {
      final formData = FormData.fromMap({
        'prompt': runes,
        'n': count,
        'size': size,
        'quality': quality,
        'background': background,
        'output_format': outputFormat,
        'response_format': 'url',
        if (clientBatchIndex != null) 'client_batch_index': clientBatchIndex,
        if (imageMode != null && imageMode.isNotEmpty) 'image_mode': imageMode,
        'image': await MultipartFile.fromFile(imagePath),
      });
      final res = await _dio.post(
        '/api/images/edit',
        data: formData,
        options: Options(
          receiveTimeout: _imageRequestTimeout,
          sendTimeout: _imageRequestTimeout,
        ),
      );
      return Map<String, dynamic>.from(res.data as Map);
    } on DioException catch (error) {
      final partial = _partialImageResponse(error.response?.data);
      if (partial != null) return partial;
      throw gatewayException(error, fallback: '图片修改失败。');
    } catch (error) {
      throw gatewayException(error, fallback: '图片修改失败。');
    }
  }

  Future<List<String>> generatePromptCandidates(String idea) async {
    return _guard(() async {
      final res = await _dio.post(
        '/api/ai/prompt-candidates',
        data: {
          'idea': idea,
          'count': 3,
        },
      );
      return _promptCandidates(res.data);
    }, fallback: 'AI 生成咒文失败。');
  }

  Future<List<String>> identifyImagePromptCandidates(
    String imagePath, {
    String? idea,
  }) async {
    return _guard(() async {
      final ideaText = idea?.trim();
      final formData = FormData.fromMap({
        'count': 3,
        if (ideaText != null && ideaText.isNotEmpty) 'idea': ideaText,
        'image': await MultipartFile.fromFile(imagePath),
      });
      final res = await _dio.post(
        '/api/ai/image-prompt-candidates',
        data: formData,
      );
      return _promptCandidates(res.data);
    }, fallback: '图片识别咒文失败。');
  }

  Future<List<String>> generateEditPromptCandidates({
    required String idea,
    required String imagePath,
  }) async {
    final ideaText = idea.trim();
    if (ideaText.isEmpty) return const [];

    try {
      return await identifyImagePromptCandidates(imagePath, idea: ideaText);
    } catch (error) {
      throw gatewayException(error, fallback: '结合图片推荐提示词失败。');
    }
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

  Future<Map<String, dynamic>> deleteHistoryItem(String id) async {
    return _guard(() async {
      final res = await _dio.delete('/api/images/history/$id');
      return _mapResponse(res.data);
    }, fallback: '删除图片记录失败。');
  }

  Future<Map<String, dynamic>> retryHistoryGenerate(String id) async {
    return _guard(() async {
      final res = await _dio.post('/api/images/history/$id/retry');
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '重试生成失败。');
  }

  Future<Map<String, dynamic>> createImageShareLink({
    String? historyId,
    String? relativeUrl,
    String? url,
  }) async {
    return _guard(() async {
      final data = <String, dynamic>{
        if (historyId != null && historyId.trim().isNotEmpty)
          'history_id': historyId.trim(),
        if (relativeUrl != null && relativeUrl.trim().isNotEmpty)
          'relative_url': relativeUrl.trim(),
        if (url != null && url.trim().isNotEmpty) 'url': url.trim(),
      };
      final res = await _dio.post('/api/images/share-links', data: data);
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '创建分享链接失败。');
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

  Future<Map<String, dynamic>> bindMyEmail(String email, String code) async {
    return _guard(() async {
      final res = await _dio.post('/api/me/email', data: {
        'email': email,
        'code': code,
      });
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '绑定邮箱失败。');
  }

  Future<Map<String, dynamic>> updateMyAvatar(String imagePath) async {
    return _guard(() async {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(imagePath),
      });
      final res = await _dio.post('/api/me/avatar', data: formData);
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '头像上传失败。');
  }

  Future<Map<String, dynamic>> getDailyCheckInStatus() async {
    return _guard(() async {
      final res = await _dio.get(
        '/api/me/check-in',
        queryParameters: _timezoneParameters(),
      );
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '读取签到状态失败。');
  }

  Future<Map<String, dynamic>> performDailyCheckIn() async {
    return _guard(() async {
      final res = await _dio.post(
        '/api/me/check-in',
        data: _timezoneParameters(),
      );
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '签到失败，请稍后重试。');
  }

  Future<Map<String, dynamic>> getPointsSummary() async {
    return _guard(() async {
      final res = await _dio.get(
        '/api/me/points',
        queryParameters: _timezoneParameters(),
      );
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '读取积分明细失败。');
  }

  Future<Map<String, dynamic>> getMyFeedback({
    String? type,
    String? category,
    String? status,
    String? keyword,
    int page = 1,
    int pageSize = 30,
  }) async {
    return _guard(() async {
      final res = await _dio.get(
        '/api/me/feedback',
        queryParameters: _feedbackQuery(
          type: type,
          category: category,
          status: status,
          keyword: keyword,
          page: page,
          pageSize: pageSize,
        ),
      );
      return _mapResponse(res.data);
    }, fallback: '读取反馈列表失败。');
  }

  Future<Map<String, dynamic>> createMyFeedback({
    required String type,
    String? category,
    required String title,
    required String content,
  }) async {
    return _guard(() async {
      final res = await _dio.post('/api/me/feedback', data: {
        'type': type,
        if (category != null && category.isNotEmpty) 'category': category,
        'title': title,
        'content': content,
      });
      return _mapResponse(res.data);
    }, fallback: '提交反馈失败。');
  }

  Future<Map<String, dynamic>> getMyFeedbackDetail(String id) async {
    return _getMap('/api/me/feedback/$id', fallback: '读取反馈详情失败。');
  }

  Future<Map<String, dynamic>> getAdminFeedback({
    String? type,
    String? category,
    String? status,
    String? keyword,
    DateTime? startAt,
    DateTime? endAt,
    int page = 1,
    int pageSize = 30,
  }) async {
    return _guard(() async {
      final query = _feedbackQuery(
        type: type,
        category: category,
        status: status,
        keyword: keyword,
        page: page,
        pageSize: pageSize,
      );
      if (startAt != null) query['start_at'] = startAt.toIso8601String();
      if (endAt != null) query['end_at'] = endAt.toIso8601String();
      final res = await _dio.get('/api/admin/feedback', queryParameters: query);
      return _mapResponse(res.data);
    }, fallback: '读取用户反馈失败。');
  }

  Future<Map<String, dynamic>> getAdminFeedbackDetail(String id) async {
    return _getMap('/api/admin/feedback/$id', fallback: '读取反馈详情失败。');
  }

  Future<Map<String, dynamic>> updateAdminFeedbackStatus(
    String id,
    String status, {
    String? note,
  }) async {
    return _guard(() async {
      final res = await _dio.post('/api/admin/feedback/$id/status', data: {
        'status': status,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });
      return _mapResponse(res.data);
    }, fallback: '更新反馈状态失败。');
  }

  Future<Map<String, dynamic>> replyAdminFeedback(
    String id,
    String reply,
  ) async {
    return _guard(() async {
      final res = await _dio.post('/api/admin/feedback/$id/reply', data: {
        'reply': reply,
      });
      return _mapResponse(res.data);
    }, fallback: '回复反馈失败。');
  }

  Future<Map<String, dynamic>> summarizeAdminFeedback(String id) async {
    return _guard(() async {
      final res = await _dio.post('/api/admin/feedback/$id/ai-summary');
      return _mapResponse(res.data);
    }, fallback: 'AI 整理反馈失败。');
  }

  Future<Map<String, dynamic>> getAdminFeedbackAutomation() async {
    return _getMap('/api/admin/feedback/automation',
        fallback: '读取反馈 AI 自动整理设置失败。');
  }

  Future<Map<String, dynamic>> saveAdminFeedbackAutomation({
    required bool autoEnabled,
    required String automationLimit,
    required int intervalMinutes,
    required bool autoReplyEnabled,
    required bool autoExportEnabled,
  }) async {
    return _guard(() async {
      final res = await _dio.post('/api/admin/feedback/automation', data: {
        'auto_enabled': autoEnabled,
        'automation_limit': automationLimit,
        'interval_minutes': intervalMinutes,
        'auto_reply_enabled': autoReplyEnabled,
        'auto_export_enabled': autoExportEnabled,
      });
      return _mapResponse(res.data);
    }, fallback: '保存反馈 AI 自动整理设置失败。');
  }

  Future<Map<String, dynamic>> runAdminFeedbackAutomation() async {
    return _guard(() async {
      final res = await _dio.post('/api/admin/feedback/auto-run');
      return _mapResponse(res.data);
    }, fallback: '执行反馈 AI 自动整理失败。');
  }

  Future<Map<String, dynamic>> runAdminFeedbackAutoReply() async {
    return _guard(() async {
      final res = await _dio.post('/api/admin/feedback/auto-reply');
      return _mapResponse(res.data);
    }, fallback: '执行反馈 AI 自动回复失败。');
  }

  Future<Map<String, dynamic>> getAdminFeedbackInsights(String period) async {
    return _guard(() async {
      final res = await _dio.get(
        '/api/admin/feedback/insights',
        queryParameters: {'period': period},
      );
      return _mapResponse(res.data);
    }, fallback: '读取反馈需求清单失败。');
  }

  Future<Map<String, dynamic>> exportAdminFeedbackInsights(
      String period) async {
    return _guard(() async {
      final res = await _dio.post(
        '/api/admin/feedback/export',
        queryParameters: {'period': period},
      );
      return _mapResponse(res.data);
    }, fallback: '导出反馈需求清单失败。');
  }

  Future<Map<String, dynamic>> getMyNotifications({
    int limit = 80,
    String? readState,
  }) async {
    return _guard(() async {
      final queryParameters = <String, dynamic>{'limit': limit};
      if (readState != null && readState.isNotEmpty) {
        queryParameters['read_state'] = readState;
      }
      final res = await _dio.get(
        '/api/me/notifications',
        queryParameters: queryParameters,
      );
      return _mapResponse(res.data);
    }, fallback: '读取通知失败。');
  }

  Future<Map<String, dynamic>> getMyNotificationsByCategory(
    String category, {
    int limit = 50,
    String? readState,
  }) async {
    return _guard(() async {
      final queryParameters = <String, dynamic>{
        'limit': limit,
        'category': category,
      };
      if (readState != null && readState.isNotEmpty) {
        queryParameters['read_state'] = readState;
      }
      final res = await _dio.get(
        '/api/me/notifications',
        queryParameters: queryParameters,
      );
      return _mapResponse(res.data);
    }, fallback: '读取通知失败。');
  }

  Future<Map<String, dynamic>> markNotificationRead(String id) async {
    return _guard(() async {
      final res = await _dio.post('/api/me/notifications/$id/read');
      return _mapResponse(res.data);
    }, fallback: '标记通知失败。');
  }

  Future<Map<String, dynamic>> markAllNotificationsRead() async {
    return _guard(() async {
      final res = await _dio.post('/api/me/notifications/read-all');
      return _mapResponse(res.data);
    }, fallback: '标记通知失败。');
  }

  Future<Map<String, dynamic>> getGalleryPosts({
    required String view,
    String? keyword,
    String? action,
    String sort = 'time',
    int page = 1,
    int pageSize = 30,
  }) async {
    return _guard(() async {
      final res = await _dio.get(
        '/api/gallery/posts',
        queryParameters: {
          'view': view,
          if (keyword != null && keyword.trim().isNotEmpty)
            'keyword': keyword.trim(),
          if (action != null && action.isNotEmpty) 'action': action,
          'sort': sort,
          'page': page,
          'page_size': pageSize,
        },
      );
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '读取画廊失败。');
  }

  Future<Map<String, dynamic>> publishGalleryPost(String historyId) async {
    return _guard(() async {
      final res = await _dio.post('/api/gallery/posts/history/$historyId');
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '发布到画廊失败。');
  }

  Future<Map<String, dynamic>> getGalleryPost(String postId) async {
    return _guard(() async {
      final res = await _dio.get('/api/gallery/posts/$postId');
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '读取作品详情失败。');
  }

  Future<Map<String, dynamic>> toggleGalleryLike(String postId) async {
    return _guard(() async {
      final res = await _dio.post('/api/gallery/posts/$postId/like');
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '点赞失败。');
  }

  Future<Map<String, dynamic>> toggleGalleryFavorite(String postId) async {
    return _guard(() async {
      final res = await _dio.post('/api/gallery/posts/$postId/favorite');
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '收藏失败。');
  }

  Future<List<Map<String, dynamic>>> getGalleryComments(String postId) async {
    return _guard(() async {
      final res = await _dio.get('/api/gallery/posts/$postId/comments');
      return (res.data as List? ?? [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }, fallback: '读取评论失败。');
  }

  Future<void> deleteGalleryComment(String commentId) async {
    await _guard(() async {
      await _dio.delete('/api/gallery/comments/$commentId');
    }, fallback: '删除评论失败。');
  }

  Future<void> deleteGalleryPost(String postId) async {
    await _guard(() async {
      await _dio.delete('/api/gallery/posts/$postId');
    }, fallback: '删除作品失败。');
  }

  Future<Map<String, dynamic>> unpublishGalleryPost(String postId) async {
    return _guard(() async {
      final res = await _dio.delete('/api/gallery/posts/$postId');
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '取消发布失败。');
  }

  Future<Map<String, dynamic>> unpublishGalleryPostByHistory(
      String historyId) async {
    return _guard(() async {
      final res = await _dio.delete('/api/gallery/posts/history/$historyId');
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '取消发布失败。');
  }

  Future<Map<String, dynamic>> addGalleryComment(
    String postId,
    String content, {
    String? parentCommentId,
  }) async {
    return _guard(() async {
      final formData = FormData.fromMap({
        'content': content,
        if (parentCommentId != null && parentCommentId.isNotEmpty)
          'parent_comment_id': parentCommentId,
      });
      final res = await _dio.post('/api/gallery/posts/$postId/comments',
          data: formData);
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '发表评论失败。');
  }

  Future<Map<String, dynamic>> recordGalleryDownload(String postId) async {
    return _guard(() async {
      final res = await _dio.post('/api/gallery/posts/$postId/download');
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '下载图片失败。');
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

  Future<List<dynamic>> adminInvitationCodes() async {
    return _getList('/api/admin/invitation-codes', fallback: '读取邀请码失败。');
  }

  Future<List<dynamic>> createAdminInvitationCodes(int count) async {
    return _guard(() async {
      final res = await _dio.post(
        '/api/admin/invitation-codes',
        data: {'count': count},
      );
      return List<dynamic>.from(res.data as List);
    }, fallback: '生成邀请码失败。');
  }

  Future<Map<String, dynamic>> getLevelRewards() async {
    return _getMap('/api/me/level-rewards', fallback: '读取等级奖励失败。');
  }

  Future<Map<String, dynamic>> claimLevelReward(int level) async {
    return _guard(() async {
      final res = await _dio.post('/api/me/level-rewards/$level/claim');
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '领取等级奖励失败。');
  }

  Future<Map<String, dynamic>> adminAnnouncements() async {
    return _getMap('/api/admin/announcements', fallback: '读取公告福利失败。');
  }

  Future<Map<String, dynamic>> publishAdminAnnouncement({
    required String title,
    required String body,
    required bool notify,
  }) async {
    return _guard(() async {
      final res = await _dio.post('/api/admin/announcements', data: {
        'title': title,
        'body': body,
        'notify': notify,
      });
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '发布公告失败。');
  }

  Future<Map<String, dynamic>> updateAdminAnnouncement({
    required String id,
    required String title,
    required String body,
    required bool isPublished,
  }) async {
    return _guard(() async {
      final res = await _dio.put('/api/admin/announcements/$id', data: {
        'title': title,
        'body': body,
        'is_published': isPublished,
      });
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '修改公告失败。');
  }

  Future<Map<String, dynamic>> deleteAdminAnnouncement(String id) async {
    return _guard(() async {
      final res = await _dio.delete('/api/admin/announcements/$id');
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '删除公告失败。');
  }

  Future<Map<String, dynamic>> grantAdminWelfare({
    required String title,
    required String body,
    required int generateBonus,
    required int editBonus,
    required bool notify,
  }) async {
    return _guard(() async {
      final res = await _dio.post('/api/admin/welfare-grants', data: {
        'title': title,
        if (body.trim().isNotEmpty) 'body': body.trim(),
        'generate_bonus': generateBonus,
        'edit_bonus': editBonus,
        'notify': notify,
      });
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '发放福利失败。');
  }

  Future<dynamic> saveAdminUser(
      String? id, Map<String, dynamic> payload) async {
    return _guard(() async {
      final res = id == null
          ? await _dio.post('/api/admin/users', data: payload)
          : await _dio.put('/api/admin/users/$id', data: payload);
      return res.data;
    }, fallback: '保存用户失败。');
  }

  Future<void> deleteAdminUser(String id) async {
    await _guard(() async {
      await _dio.delete('/api/admin/users/$id');
    }, fallback: '删除用户失败。');
  }

  Future<List<dynamic>> adminGroups() async {
    return _getList('/api/admin/groups', fallback: '读取用户组失败。');
  }

  Future<dynamic> saveAdminGroup(
      String? id, Map<String, dynamic> payload) async {
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

  Future<dynamic> saveAdminRole(
      String? id, Map<String, dynamic> payload) async {
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

  Future<Map<String, dynamic>> providerHealthcheck({
    bool applySwitch = false,
  }) async {
    return _guard(() async {
      final res = await _dio.post(
        '/api/admin/provider-healthcheck',
        data: {'apply_switch': applySwitch},
      );
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '上游测活失败。');
  }

  Future<Map<String, dynamic>> adminLocalBackups() async {
    return _getMap('/api/admin/local-backups', fallback: '读取备份记录失败。');
  }

  Future<Map<String, dynamic>> runAdminLocalBackup() async {
    return _guard(() async {
      final res = await _dio.post('/api/admin/local-backups/run');
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '执行数据备份失败。');
  }

  Future<Map<String, dynamic>> restoreAdminLocalBackup(String id) async {
    return _guard(() async {
      final res = await _dio.post('/api/admin/local-backups/$id/restore');
      return Map<String, dynamic>.from(res.data as Map);
    }, fallback: '恢复数据备份失败。');
  }

  Future<List<dynamic>> adminApiKeys() async {
    return _getList('/api/admin/api-keys', fallback: '读取 API Key 失败。');
  }

  Future<dynamic> saveAdminApiKey(
      String? id, Map<String, dynamic> payload) async {
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

  Map<String, dynamic> _feedbackQuery({
    String? type,
    String? category,
    String? status,
    String? keyword,
    required int page,
    required int pageSize,
  }) {
    return {
      'page': page,
      'page_size': pageSize,
      if (type != null && type.isNotEmpty) 'type': type,
      if (category != null && category.isNotEmpty) 'category': category,
      if (status != null && status.isNotEmpty) 'status': status,
      if (keyword != null && keyword.trim().isNotEmpty)
        'keyword': keyword.trim(),
    };
  }

  Map<String, dynamic> _timezoneParameters() {
    final now = DateTime.now();
    return {
      'timezone': now.timeZoneName,
      'timezone_offset_minutes': now.timeZoneOffset.inMinutes,
    };
  }

  Map<String, dynamic>? _partialImageResponse(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (!_hasUsableImage(map)) return null;
    final errors = <dynamic>[
      ...(map['errors'] as List? ?? const []),
      if (map['detail'] != null) map['detail'],
      if (map['message'] != null) map['message'],
      if (map['error'] != null) map['error'],
    ];
    map['errors'] = errors
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    map['partial_success'] = true;
    return map;
  }

  bool _hasUsableImage(dynamic value) {
    if (value is List) {
      return value.any(_hasUsableImage);
    }
    if (value is! Map) return false;
    final map = Map<dynamic, dynamic>.from(value);
    for (final key in ['url', 'image_url', 'b64_json', 'image', 'src']) {
      final raw = map[key];
      if (raw is String && raw.trim().isNotEmpty) {
        return true;
      }
      if (raw is Map && _hasUsableImage(raw)) {
        return true;
      }
    }
    for (final key in ['data', 'images', 'items', 'results', 'output']) {
      final raw = map[key];
      if (_hasUsableImage(raw)) return true;
    }
    return false;
  }

  Map<String, dynamic> _mapResponse(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is List) return {'items': data};
    return <String, dynamic>{};
  }

  List<String> _promptCandidates(dynamic data) {
    return parsePromptCandidates(data);
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

String normalizeGatewayDownloadUrl(String url, String baseUrl) {
  final trimmedUrl = url.trim();
  final trimmedBase = baseUrl.trim();
  if (trimmedUrl.isEmpty || trimmedBase.isEmpty) {
    return trimmedUrl;
  }

  final parsed = Uri.tryParse(trimmedUrl);
  final base = Uri.tryParse(trimmedBase);
  if (parsed == null || base == null || !base.hasScheme || !base.hasAuthority) {
    return trimmedUrl;
  }

  final path = parsed.path;
  if (!_isGatewayMediaPath(path)) {
    return trimmedUrl;
  }

  if (!parsed.hasScheme && !parsed.hasAuthority) {
    return parsed.toString();
  }

  return base
      .replace(
        path: path,
        query: parsed.hasQuery ? parsed.query : null,
        fragment: parsed.hasFragment ? parsed.fragment : null,
      )
      .toString();
}

bool _isGatewayMediaPath(String path) {
  return path.startsWith('/files/') || path.startsWith('/s/') || path == '/s';
}
