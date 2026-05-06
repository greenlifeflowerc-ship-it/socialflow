import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;
import '../config/app_config.dart';

class ApiClient {
  final Dio _dio;
  final Logger _logger;

  ApiClient(this._dio, this._logger) {
    _dio.options.baseUrl = AppConfig.backendUrl;
    _dio.options.connectTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout = const Duration(seconds: 180);
    _dio.options.receiveTimeout = const Duration(seconds: 180);
    _dio.options.headers['Content-Type'] = 'application/json';

    // Inject Supabase JWT before every request.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token =
              Supabase.instance.client.auth.currentSession?.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Token expired or invalid — sign the user out.
            await Supabase.instance.client.auth.signOut();
          }
          return handler.next(error);
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Internal helpers
  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _post(String path, {dynamic data}) async {
    final response = await _dio.post(path, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    final response =
        await _dio.get(path, queryParameters: queryParameters);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _delete(String path) async {
    final response = await _dio.delete(path);
    return response.data as Map<String, dynamic>;
  }

  List<dynamic> parseListFromAnyKey(
      Map<String, dynamic> json, List<String> preferredKeys) {
    for (final key in preferredKeys) {
      if (json[key] is List) return json[key] as List;
    }
    for (final key in ['data', 'items', 'results', 'list']) {
      if (json[key] is List) return json[key] as List;
    }
    return [];
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Health
  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getHealth() => _get('/api/health');
  Future<Map<String, dynamic>> getConfigStatus() => _get('/api/config/status');

  // ──────────────────────────────────────────────────────────────────────────
  // Instagram OAuth / Accounts
  // ──────────────────────────────────────────────────────────────────────────

  /// Returns { authUrl: "https://..." } — open in external browser.
  Future<Map<String, dynamic>> startInstagramAuth() =>
      _get('/api/auth/instagram/start');

  /// Returns connected social accounts for the authenticated user.
  Future<Map<String, dynamic>> getAccounts() => _get('/api/accounts');

  /// Disconnect an account.
  Future<Map<String, dynamic>> deleteAccount(String id) =>
      _delete('/api/accounts/$id');

  // ──────────────────────────────────────────────────────────────────────────
  // Media upload
  // ──────────────────────────────────────────────────────────────────────────

  /// Infers the MIME type from a filename extension.
  /// Falls back to 'application/octet-stream' for unknown types.
  static String inferMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    const types = {
      'mp4':  'video/mp4',
      'mov':  'video/quicktime',
      'm4v':  'video/x-m4v',
      'jpg':  'image/jpeg',
      'jpeg': 'image/jpeg',
      'png':  'image/png',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'gif':  'image/gif',
    };
    return types[ext] ?? 'application/octet-stream';
  }

  /// Returns true if the file extension indicates a video.
  static bool isVideoFile(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return {'mp4', 'mov', 'm4v', 'avi', 'mkv'}.contains(ext);
  }

  Future<Map<String, dynamic>> uploadMedia(
    XFile file, {
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final mimeType = inferMimeType(file.name);
    final contentType = MediaType.parse(mimeType);

    debugPrint('UPLOAD MEDIA: ${file.name} | MIME: $mimeType');

    MultipartFile multipartFile;
    if (kIsWeb || file.path.isEmpty) {
      // Web platform: read bytes directly.
      final bytes = await file.readAsBytes();
      multipartFile = MultipartFile.fromBytes(
        bytes,
        filename: file.name,
        contentType: contentType,
      );
    } else {
      multipartFile = await MultipartFile.fromFile(
        file.path,
        filename: file.name,
        contentType: contentType,
      );
    }

    final formData = FormData.fromMap({'file': multipartFile});
    final response = await _dio.post(
      '/api/media/upload',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
    return response.data as Map<String, dynamic>;
  }

  /// Legacy alias kept for compatibility with existing code.
  Future<Map<String, dynamic>> uploadImage(
    XFile file, {
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) =>
      uploadMedia(file,
          onSendProgress: onSendProgress, cancelToken: cancelToken);

  // ──────────────────────────────────────────────────────────────────────────
  // Audio upload
  // ──────────────────────────────────────────────────────────────────────────

  /// Upload an audio file (mp3, m4a, wav, aac) to the backend.
  /// Returns: { ok, asset: { id, media_url, secure_url, resource_type: "audio" } }
  Future<Map<String, dynamic>> uploadAudio(
    XFile file, {
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final mimeType = inferMimeType(file.name);
    final contentType = MediaType.parse(mimeType);

    debugPrint('UPLOAD AUDIO: ${file.name} | MIME: $mimeType');

    MultipartFile multipartFile;
    if (kIsWeb || file.path.isEmpty) {
      final bytes = await file.readAsBytes();
      multipartFile = MultipartFile.fromBytes(
        bytes,
        filename: file.name,
        contentType: contentType,
      );
    } else {
      multipartFile = await MultipartFile.fromFile(
        file.path,
        filename: file.name,
        contentType: contentType,
      );
    }

    final formData = FormData.fromMap({'file': multipartFile});
    try {
      final response = await _dio.post(
        '/api/media/audio/upload',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
        onSendProgress: onSendProgress,
        cancelToken: cancelToken,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('AUDIO UPLOAD FAILED: ${e.requestOptions.uri}');
      debugPrint('AUDIO UPLOAD STATUS: ${e.response?.statusCode}');
      debugPrint('AUDIO UPLOAD DATA: ${e.response?.data}');
      final data = e.response?.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Audio upload failed';
      throw Exception(message);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Render media with audio
  // ──────────────────────────────────────────────────────────────────────────

  /// Render a media asset with a custom audio track via backend ffmpeg.
  /// Body: {
  ///   media_asset_id, audio_asset_id,
  ///   output_type: "story"|"reels",
  ///   duration_seconds: int,
  ///   audio_mode: "replace"|"mix",
  ///   aspect_ratio: "9:16"|"1:1"|"4:5"
  /// }
  /// Returns: { ok, asset: { id, media_url, secure_url, resource_type: "video" }, message }
  Future<Map<String, dynamic>> renderWithAudio(Map<String, dynamic> body) async {
    try {
      debugPrint('RENDER WITH AUDIO PAYLOAD: $body');
      final response = await _dio.post('/api/media/render-with-audio', data: body);
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('RENDER FAILED URL: ${e.requestOptions.uri}');
      debugPrint('RENDER FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('RENDER FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'Failed to render media with audio';
      throw Exception(message);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Posts
  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getPosts() => _get('/api/posts');

  Future<Map<String, dynamic>> schedulePost(Map<String, dynamic> data) =>
      _post('/api/posts/schedule', data: data);

  Future<Map<String, dynamic>> publishNow(Map<String, dynamic> data) =>
      _post('/api/posts/publish-now', data: data);

  Future<Map<String, dynamic>> retryPost(String id) =>
      _post('/api/posts/$id/retry');

  Future<Map<String, dynamic>> cancelPost(String id) =>
      _post('/api/posts/$id/cancel');

  Future<Map<String, dynamic>> deletePost(String postId) =>
      _delete('/api/posts/$postId');

  /// Legacy scheduled-post creator — maps to /api/posts/schedule.
  Future<Map<String, dynamic>> createScheduledPost({
    String? mediaAssetId,
    required String mediaUrl,
    String? imageUrl,
    String? videoUrl,
    required String mediaType,
    required String caption,
    required List<String> hashtags,
    required DateTime scheduledAt,
    String socialAccountId = '',
    String timezone = 'Asia/Dubai',
  }) =>
      schedulePost({
        if (mediaAssetId != null) 'media_asset_id': mediaAssetId,
        'media_url': mediaUrl,
        if (imageUrl != null) 'image_url': imageUrl,
        if (videoUrl != null) 'video_url': videoUrl,
        'media_type': mediaType,
        'caption': caption,
        'hashtags': hashtags,
        'social_account_id': socialAccountId,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'timezone': timezone,
      });

  // ──────────────────────────────────────────────────────────────────────────
  // Insights
  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAccountInsights(String accountId) =>
      _get('/api/insights/account', queryParameters: {'account_id': accountId});

  Future<Map<String, dynamic>> getPostInsights(String postId) =>
      _get('/api/posts/$postId/insights');

  // ──────────────────────────────────────────────────────────────────────────
  // Instagram Media & Comments  (new routes — used by CommentsScreen)
  // ──────────────────────────────────────────────────────────────────────────

  /// GET /api/instagram/media?account_id={accountId}
  Future<Map<String, dynamic>> getInstagramMedia(String accountId) async {
    try {
      return await _get('/api/instagram/media',
          queryParameters: {'account_id': accountId});
    } on DioException catch (e) {
      debugPrint('COMMENTS FAILED URL: ${e.requestOptions.uri}');
      debugPrint('COMMENTS FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('COMMENTS FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('COMMENTS FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Failed to load Instagram media';
      throw Exception(message);
    }
  }

  /// GET /api/instagram/media/{mediaId}/comments?account_id={accountId}
  Future<Map<String, dynamic>> getInstagramMediaComments(
      String mediaId, String accountId) async {
    try {
      return await _get('/api/instagram/media/$mediaId/comments',
          queryParameters: {'account_id': accountId});
    } on DioException catch (e) {
      debugPrint('COMMENTS FAILED URL: ${e.requestOptions.uri}');
      debugPrint('COMMENTS FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('COMMENTS FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('COMMENTS FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Failed to load comments';
      throw Exception(message);
    }
  }

  /// GET /api/instagram/comments/all?account_id={accountId}
  Future<Map<String, dynamic>> getInstagramAllComments(
      String accountId) async {
    try {
      return await _get('/api/instagram/comments/all',
          queryParameters: {'account_id': accountId});
    } on DioException catch (e) {
      debugPrint('COMMENTS FAILED URL: ${e.requestOptions.uri}');
      debugPrint('COMMENTS FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('COMMENTS FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('COMMENTS FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Failed to load all comments';
      throw Exception(message);
    }
  }

  /// POST /api/instagram/comments/{commentId}/reply
  /// Body: { "account_id": accountId, "message": message }
  Future<Map<String, dynamic>> replyToInstagramComment({
    required String commentId,
    required String accountId,
    required String message,
  }) async {
    try {
      return await _post('/api/instagram/comments/$commentId/reply',
          data: {'account_id': accountId, 'message': message});
    } on DioException catch (e) {
      debugPrint('COMMENTS FAILED URL: ${e.requestOptions.uri}');
      debugPrint('COMMENTS FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('COMMENTS FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('COMMENTS FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final msg = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Failed to reply to comment';
      throw Exception(msg);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Comments (legacy — scheduled-post based routes)
  // ──────────────────────────────────────────────────────────────────────────

  /// GET /api/posts/{postId}/comments
  Future<Map<String, dynamic>> getPostComments(String postId) async {
    try {
      return await _get('/api/posts/$postId/comments');
    } on DioException catch (e) {
      debugPrint('COMMENTS FAILED URL: ${e.requestOptions.uri}');
      debugPrint('COMMENTS FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('COMMENTS FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('COMMENTS FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Comments sync failed';
      throw Exception(message);
    }
  }

  /// POST /api/posts/{postId}/comments/{commentId}/reply
  Future<Map<String, dynamic>> replyToComment({
    required String postId,
    required String commentId,
    required String message,
  }) async {
    try {
      return await _post('/api/posts/$postId/comments/$commentId/reply',
          data: {'message': message});
    } on DioException catch (e) {
      debugPrint('COMMENTS FAILED URL: ${e.requestOptions.uri}');
      debugPrint('COMMENTS FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('COMMENTS FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('COMMENTS FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final msg = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Comments sync failed';
      throw Exception(msg);
    }
  }

  // ── Legacy comment helpers ────────────────────────────────────────────────
  // NOTE: Routes below (/api/comments/*, /api/comments/sync-all, etc.) do NOT
  // exist on the current backend. They are kept here only to avoid breaking
  // any references from other screens. Do NOT call these from CommentsScreen.

  @Deprecated('Backend route /api/comments does not exist. Use getPostComments() instead.')
  Future<Map<String, dynamic>> getComments(
          {String? igMediaId, bool? unreplied, String? search}) =>
      _get('/api/comments${_buildCommentQuery(igMediaId, unreplied, search)}');

  @Deprecated('Backend route /api/comments/sync does not exist. Use getPostComments() instead.')
  Future<Map<String, dynamic>> syncComments(String igMediaId) =>
      _post('/api/comments/sync', data: {'igMediaId': igMediaId});

  @Deprecated('Backend route /api/comments/sync-all does not exist. Invalidate commentMediaProvider and allCommentsProvider instead.')
  Future<Map<String, dynamic>> syncAllComments() =>
      _post('/api/comments/sync-all');

  @Deprecated('Backend route /api/comments/sync-media does not exist.')
  Future<Map<String, dynamic>> syncCommentMedia() =>
      _post('/api/comments/sync-media');

  @Deprecated('Backend route /api/comments/media does not exist.')
  Future<Map<String, dynamic>> getCommentMedia() =>
      _get('/api/comments/media');

  String _buildCommentQuery(
      String? igMediaId, bool? unreplied, String? search) {
    final params = <String, String>{};
    if (igMediaId != null) params['igMediaId'] = igMediaId;
    if (unreplied == true) params['unreplied'] = 'true';
    if (search != null) params['search'] = search;
    if (params.isEmpty) return '';
    return '?${Uri(queryParameters: params).query}';
  }

  Future<Map<String, dynamic>> replyToCommentLegacy(
          {required String commentId, required String message}) =>
      _post('/api/comments/$commentId/reply', data: {'message': message});

  Future<Map<String, dynamic>> privateReplyToComment(
          {required String commentId, required String message}) =>
      _post('/api/comments/$commentId/private-reply', data: {'message': message});

  Future<Map<String, dynamic>> likeComment(String commentId) =>
      _post('/api/comments/$commentId/like');

  Future<Map<String, dynamic>> hideComment(
          {required String commentId, required bool hide}) =>
      _post('/api/comments/$commentId/hide', data: {'hide': hide});

  Future<Map<String, dynamic>> deleteComment(String commentId) =>
      _delete('/api/comments/$commentId');

  Future<Map<String, dynamic>> getAutoReplyRules() =>
      _get('/api/comments/auto-reply/rules');

  Future<Map<String, dynamic>> createAutoReplyRule(
          Map<String, dynamic> data) =>
      _post('/api/comments/auto-reply/rules', data: data);

  Future<Map<String, dynamic>> updateAutoReplyRule(
          String id, Map<String, dynamic> data) async =>
      (await _dio.patch('/api/comments/auto-reply/rules/$id', data: data))
          .data as Map<String, dynamic>;

  Future<Map<String, dynamic>> deleteAutoReplyRule(String id) =>
      _delete('/api/comments/auto-reply/rules/$id');

  // ──────────────────────────────────────────────────────────────────────────
  // Messages / Inbox
  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getConversations(String accountId) async {
    try {
      final response = await _dio.get(
        '/api/messages/conversations',
        queryParameters: {'account_id': accountId},
      );
      debugPrint('MESSAGES SYNC OK status=${response.statusCode}');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('MESSAGES SYNC FAILED URL: ${e.requestOptions.uri}');
      debugPrint('MESSAGES SYNC FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('MESSAGES SYNC FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('MESSAGES SYNC FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Messages sync failed';
      throw Exception(message);
    }
  }

  Future<Map<String, dynamic>> sendMessage({
    required String accountId,
    required String recipientId,
    required String message,
  }) async {
    try {
      final response = await _dio.post('/api/messages/send', data: {
        'account_id': accountId,
        'recipient_id': recipientId,
        'message': message,
      });
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('MESSAGES SEND FAILED URL: ${e.requestOptions.uri}');
      debugPrint('MESSAGES SEND FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('MESSAGES SEND FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('MESSAGES SEND FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final msg = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Send message failed';
      throw Exception(msg);
    }
  }

  // Legacy inbox routes — kept for reference, NOT called by InboxScreen.
  // These routes (/api/inbox/*) do not exist on the backend and return 404.
  @Deprecated('Route /api/inbox/conversations does not exist. Use getConversations() instead.')
  Future<Map<String, dynamic>> getConversationsLegacy() =>
      _get('/api/inbox/conversations');

  @Deprecated('Route /api/inbox/sync-conversations does not exist. Use getConversations() instead.')
  Future<Map<String, dynamic>> syncConversations() =>
      _post('/api/inbox/sync-conversations');

  @Deprecated('Route /api/inbox/conversations/{id}/messages does not exist. Messages are embedded in getConversations response.')
  Future<Map<String, dynamic>> getMessages(String conversationId,
          {bool sync = false}) =>
      _get(
          '/api/inbox/conversations/$conversationId/messages${sync ? '?sync=true' : ''}');

  Future<Map<String, dynamic>> sendTextMessage({
    required String conversationId,
    required String recipientId,
    required String text,
  }) =>
      _post('/api/inbox/send-text', data: {
        'conversationId': conversationId,
        'recipientId': recipientId,
        'text': text,
      });

  Future<Map<String, dynamic>> sendImageMessage({
    required String conversationId,
    required String recipientId,
    required String imageUrl,
  }) =>
      _post('/api/inbox/send-image', data: {
        'conversationId': conversationId,
        'recipientId': recipientId,
        'imageUrl': imageUrl,
      });

  // ──────────────────────────────────────────────────────────────────────────
  // Media library (legacy)
  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMedia() => _get('/api/media');

  Future<Map<String, dynamic>> deleteMedia(String mediaId) async {
    try {
      return await _delete('/api/media/$mediaId');
    } on DioException catch (e) {
      debugPrint('DELETE MEDIA FAILED URL: ${e.requestOptions.uri}');
      debugPrint('DELETE MEDIA FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('DELETE MEDIA FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('DELETE MEDIA FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Failed to delete media';
      throw Exception(message);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // AI
  // ──────────────────────────────────────────────────────────────────────────

  /// Converts a [DioException] into a clean [Exception] with the real backend
  /// error message. Prints debug details before throwing.
  Exception _handleAiException(DioException e) {
    debugPrint('AI REQUEST FAILED URL: ${e.requestOptions.uri}');
    debugPrint('AI REQUEST FAILED METHOD: ${e.requestOptions.method}');
    debugPrint('AI REQUEST FAILED STATUS: ${e.response?.statusCode}');
    debugPrint('AI REQUEST FAILED DATA: ${e.response?.data}');
    final data = e.response?.data;
    String message = 'AI generation failed.';
    if (data is Map && data['error'] != null) {
      message = data['error'].toString();
    } else if (data is Map && data['message'] != null) {
      message = data['message'].toString();
    } else if (e.message != null) {
      message = e.message!;
    }
    return Exception(message);
  }

  Future<Map<String, dynamic>> generateCaption({
    required String imageUrl,
    String? mediaUrl,
    String? mediaAssetId,
    required String language,
    required String tone,
    required String provider,
    required String model,
    String captionPreset = 'Instagram Marketing Caption',
    String? customPrompt,
    String businessName = '',
    String location = '',
    String? cta,
    int hashtagCount = 12,
  }) async {
    try {
      final response = await _post('/api/gemini/generate-caption', data: {
        'imageUrl': imageUrl,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (mediaAssetId != null) 'mediaAssetId': mediaAssetId,
        'language': language,
        'tone': tone,
        'provider': provider,
        'model': model,
        'captionPreset': captionPreset,
        if (customPrompt != null) 'customPrompt': customPrompt,
        'businessName': businessName,
        'location': location,
        if (cta != null) 'cta': cta,
        'hashtagCount': hashtagCount,
      });
      if (response['ok'] != true) {
        throw Exception(response['error'] ?? 'Failed to generate caption');
      }
      return response['result'] as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleAiException(e);
    }
  }

  /// POST /api/ai/generate — used by the AI Chat screen.
  /// Body: { "model": ..., "prompt": ..., "api_key": ... }
  /// Sends api_key in body if provided; backend falls back to GEMINI_API_KEY.
  Future<Map<String, dynamic>> aiChat(Map<String, dynamic> data) async {
    final safePayload = Map<String, dynamic>.from(data)..remove('api_key');
    debugPrint('AI CHAT PAYLOAD SAFE: $safePayload');
    try {
      return await _post('/api/ai/generate', data: data);
    } on DioException catch (e) {
      debugPrint('AI CHAT FAILED URL: ${e.requestOptions.uri}');
      debugPrint('AI CHAT FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('AI CHAT FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('AI CHAT FAILED DATA: ${e.response?.data}');
      final data2 = e.response?.data;
      final message = data2 is Map && data2['error'] != null
          ? data2['error'].toString()
          : e.message ?? 'AI Chat failed';
      throw Exception(message);
    }
  }

  /// POST /api/ai/generate — used for all text generation (post ideas, reels, etc.).
  /// Logs payload without the api_key before sending.
  Future<Map<String, dynamic>> aiGenerate(Map<String, dynamic> data) async {
    final safePayload = Map<String, dynamic>.from(data)..remove('api_key');
    debugPrint('AI GENERATE PAYLOAD SAFE: $safePayload');
    try {
      return await _post('/api/ai/generate', data: data);
    } on DioException catch (e) {
      throw _handleAiException(e);
    }
  }

  Future<Map<String, dynamic>> getAiJobs() => _get('/api/ai/jobs');

  Future<Map<String, dynamic>> getAiJobDetails(String id) =>
      _get('/api/ai/jobs/$id');

  Future<Map<String, dynamic>> retryAiJob(String jobId) =>
      _post('/api/ai/jobs/$jobId/retry-failed');

  Future<Map<String, dynamic>> retryAiJobItem(String jobId, String itemId) =>
      _post('/api/ai/jobs/$jobId/items/$itemId/retry');

  Future<Map<String, dynamic>> saveAiResultToLibrary(
          String jobId, String itemId) =>
      _post('/api/ai/jobs/$jobId/items/$itemId/save');

  Future<Map<String, dynamic>> createBulkEditJob(Map<String, dynamic> data) =>
      _post('/api/ai/bulk-edit', data: data);

  Future<Map<String, dynamic>> generateEditPrompt(
          Map<String, dynamic> data) =>
      _post('/api/gemini/generate-edit-prompt', data: data);

  Future<Map<String, dynamic>> editImage(Map<String, dynamic> data) =>
      _post('/api/ai/edit-image', data: data);

  /// GET /api/ai/models — fetches real Gemini models.
  /// If the user provided an API key it is sent as the [x-gemini-api-key]
  /// header (never in the URL). When no key is supplied the backend falls
  /// back to its own GEMINI_API_KEY env variable.
  Future<Map<String, dynamic>> listModels(Map<String, dynamic> data) async {
    final apiKey = data['apiKey'] as String?;
    final hasKey = apiKey != null && apiKey.isNotEmpty;
    try {
      final response = await _dio.get(
        '/api/ai/models',
        options: hasKey
            ? Options(headers: {'x-gemini-api-key': apiKey})
            : null,
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      debugPrint('AI REQUEST FAILED URL: ${e.requestOptions.uri}');
      debugPrint('AI REQUEST FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('AI REQUEST FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('AI REQUEST FAILED DATA: ${e.response?.data}');
      final d = e.response?.data;
      final message = d is Map && d['error'] != null
          ? d['error'].toString()
          : e.message ?? 'AI request failed';
      throw Exception(message);
    }
  }

  /// POST /api/ai/test — tests AI connectivity.
  /// The user API key (if any) is sent in the request body as [api_key].
  /// When omitted the backend falls back to its own GEMINI_API_KEY env variable.
  Future<Map<String, dynamic>> testModel(Map<String, dynamic> data) async {
    final apiKey = data['apiKey'] as String?;
    final model = data['model'] as String?;
    try {
      return await _post('/api/ai/test', data: {
        if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
        if (model != null) 'model': model,
      });
    } on DioException catch (e) {
      debugPrint('AI REQUEST FAILED URL: ${e.requestOptions.uri}');
      debugPrint('AI REQUEST FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('AI REQUEST FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('AI REQUEST FAILED DATA: ${e.response?.data}');
      final d = e.response?.data;
      final message = d is Map && d['error'] != null
          ? d['error'].toString()
          : e.message ?? 'AI request failed';
      throw Exception(message);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Debug (dev only)
  // ──────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDebugWebhookEvents() =>
      _get('/api/debug/webhook-events');

  Future<Map<String, dynamic>> getDebugComments() =>
      _get('/api/debug/comments');

  Future<Map<String, dynamic>> getDebugInbox() => _get('/api/debug/inbox');
}


final dioProvider = Provider<Dio>((_) => Dio());
final loggerProvider = Provider<Logger>((_) => Logger());
final apiClientProvider = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(dioProvider), ref.watch(loggerProvider)));
