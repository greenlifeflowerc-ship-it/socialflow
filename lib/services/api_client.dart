import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'settings_service.dart';

class ApiClient {
  final Dio _dio;
  final Logger _logger;
  final Ref _ref;

  ApiClient(this._dio, this._logger, this._ref) {
    _dio.options.connectTimeout = const Duration(seconds: 60);
    _dio.options.sendTimeout = const Duration(seconds: 180);
    _dio.options.receiveTimeout = const Duration(seconds: 180);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final settings = await _ref.read(settingsProvider.notifier).load();
          final backendUrl = settings.backendUrl;
          if (backendUrl == null || backendUrl.isEmpty) {
            return handler.reject(DioException(requestOptions: options, message: 'Backend URL is not set.'));
          }
          options.baseUrl = backendUrl;
          return handler.next(options);
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _post(String path, {dynamic data}) async => (await _dio.post(path, data: data)).data;
  Future<Map<String, dynamic>> _get(String path) async => (await _dio.get(path)).data;
  Future<Map<String, dynamic>> _delete(String path) async => (await _dio.delete(path)).data;

  List<dynamic> parseListFromAnyKey(Map<String, dynamic> json, List<String> preferredKeys) {
    for (final key in preferredKeys) {
      if (json[key] is List) return json[key];
    }
    // Check common fallbacks
    for (final key in ['data', 'items', 'results', 'list']) {
      if (json[key] is List) return json[key];
    }
    return [];
  }

  Future<Map<String, dynamic>> uploadImage(XFile file, {ProgressCallback? onSendProgress, CancelToken? cancelToken}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.name),
    });
    final response = await _dio.post(
      '/api/upload',
      data: formData,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );
    return response.data;
  }

  Future<Map<String, dynamic>> generateCaption({
    required String imageUrl, String? mediaUrl, String? mediaAssetId,
    required String language, required String tone, required String provider, required String model,
    String captionPreset = 'Luxury Product Caption', String? customPrompt,
    String businessName = 'Flower Center', String location = 'UAE', String? cta, int hashtagCount = 10,
  }) async {
    final response = await _post('/api/gemini/generate-caption', data: {
      'imageUrl': imageUrl, if (mediaUrl != null) 'mediaUrl': mediaUrl, if (mediaAssetId != null) 'mediaAssetId': mediaAssetId,
      'language': language, 'tone': tone, 'provider': provider, 'model': model,
      'captionPreset': captionPreset, if (customPrompt != null) 'customPrompt': customPrompt,
      'businessName': businessName, 'location': location, if (cta != null) 'cta': cta,
      'hashtagCount': hashtagCount,
    });
    if (response['ok'] != true) throw Exception(response['error'] ?? 'Failed to generate caption');
    return response['result'];
  }

  Future<Map<String, dynamic>> createScheduledPost({
    String? mediaAssetId, required String mediaUrl, String? imageUrl, String? videoUrl,
    required String mediaType, required String caption, required List<String> hashtags, required DateTime scheduledAt,
  }) async {
    final response = await _post('/api/posts', data: {
      if (mediaAssetId != null) 'mediaAssetId': mediaAssetId,
      'mediaUrl': mediaUrl, if (imageUrl != null) 'imageUrl': imageUrl, if (videoUrl != null) 'videoUrl': videoUrl,
      'mediaType': mediaType, 'caption': caption, 'hashtags': hashtags,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
    });
    if (response['ok'] != true) throw Exception('Failed to create post');
    return response['post'];
  }
  
  // Other methods
  Future<Map<String, dynamic>> getPosts() => _get('/api/posts');
  Future<Map<String, dynamic>> getMedia() => _get('/api/media');
  Future<Map<String, dynamic>> deletePost(String postId) => _delete('/api/posts/$postId');
  Future<Map<String, dynamic>> deleteMedia(String mediaId) => _delete('/api/media/$mediaId');
  Future<Map<String, dynamic>> generateEditPrompt(Map<String, dynamic> data) => _post('/api/gemini/generate-edit-prompt', data: data);
  Future<Map<String, dynamic>> editImage(Map<String, dynamic> data) => _post('/api/ai/edit-image', data: data);
  Future<Map<String, dynamic>> listModels(Map<String, dynamic> data) => _post('/api/ai/list-models', data: data);
  Future<Map<String, dynamic>> testModel(Map<String, dynamic> data) => _post('/api/ai/test-model', data: data);
  Future<Map<String, dynamic>> getHealth() => _get('/api/health');
  Future<Map<String, dynamic>> testMeta() => _get('/api/meta/test-connection');
  Future<Map<String, dynamic>> publishNow(Map<String, dynamic> data) => _post('/api/meta/publish-now', data: data);

  // AI Studio Methods
  Future<Map<String, dynamic>> aiChat(Map<String, dynamic> data) => _post('/api/ai/chat', data: data);
  Future<Map<String, dynamic>> getAiJobs() => _get('/api/ai/jobs');
  Future<Map<String, dynamic>> getAiJobDetails(String id) => _get('/api/ai/jobs/$id');
  Future<Map<String, dynamic>> retryAiJob(String jobId) => _post('/api/ai/jobs/$jobId/retry-failed');
  Future<Map<String, dynamic>> retryAiJobItem(String jobId, String itemId) => _post('/api/ai/jobs/$jobId/items/$itemId/retry');
  Future<Map<String, dynamic>> saveAiResultToLibrary(String jobId, String itemId) => _post('/api/ai/jobs/$jobId/items/$itemId/save');
  Future<Map<String, dynamic>> createBulkEditJob(Map<String, dynamic> data) => _post('/api/ai/bulk-edit', data: data);

  // Inbox & Comments Methods
  Future<Map<String, dynamic>> getConversations() => _get('/api/inbox/conversations');
  Future<Map<String, dynamic>> syncConversations() => _post('/api/inbox/sync-conversations');
  Future<Map<String, dynamic>> syncInstagramInbox() => _post('/api/inbox/sync-conversations');
  Future<Map<String, dynamic>> getMessages(String conversationId, {bool sync = false}) =>
      _get('/api/inbox/conversations/$conversationId/messages${sync ? '?sync=true' : ''}');
  
  Future<Map<String, dynamic>> sendTextMessage({
    required String conversationId,
    required String recipientId,
    required String text,
  }) => _post('/api/inbox/send-text', data: {
    'conversationId': conversationId,
    'recipientId': recipientId,
    'text': text,
  });

  Future<Map<String, dynamic>> sendImageMessage({
    required String conversationId,
    required String recipientId,
    required String imageUrl,
  }) => _post('/api/inbox/send-image', data: {
    'conversationId': conversationId,
    'recipientId': recipientId,
    'imageUrl': imageUrl,
  });

  Future<Map<String, dynamic>> syncCommentMedia() => _post('/api/comments/sync-media');
  Future<Map<String, dynamic>> syncAllComments() => _post('/api/comments/sync-all');
  Future<Map<String, dynamic>> getCommentMedia() => _get('/api/comments/media');
  Future<Map<String, dynamic>> syncComments(String igMediaId) => _post('/api/comments/sync', data: {'igMediaId': igMediaId});
  
  Future<Map<String, dynamic>> getComments({String? igMediaId, bool? unreplied, String? search}) =>
      _get('/api/comments${_buildCommentQuery(igMediaId, unreplied, search)}');

  String _buildCommentQuery(String? igMediaId, bool? unreplied, String? search) {
    final params = <String, String>{};
    if (igMediaId != null) params['igMediaId'] = igMediaId;
    if (unreplied == true) params['unreplied'] = 'true';
    if (search != null) params['search'] = search;
    if (params.isEmpty) return '';
    return '?${Uri(queryParameters: params).query}';
  }

  Future<Map<String, dynamic>> replyToComment({required String commentId, required String message}) =>
      _post('/api/comments/$commentId/reply', data: {'message': message});
  
  Future<Map<String, dynamic>> privateReplyToComment({required String commentId, required String message}) =>
      _post('/api/comments/$commentId/private-reply', data: {'message': message});
  
  Future<Map<String, dynamic>> likeComment(String commentId) => _post('/api/comments/$commentId/like');
  
  Future<Map<String, dynamic>> hideComment({required String commentId, required bool hide}) =>
      _post('/api/comments/$commentId/hide', data: {'hide': hide});
  
  Future<Map<String, dynamic>> deleteComment(String commentId) => _delete('/api/comments/$commentId');

  Future<Map<String, dynamic>> getAutoReplyRules() => _get('/api/comments/auto-reply/rules');
  Future<Map<String, dynamic>> createAutoReplyRule(Map<String, dynamic> data) => _post('/api/comments/auto-reply/rules', data: data);
  Future<Map<String, dynamic>> updateAutoReplyRule(String id, Map<String, dynamic> data) =>
      _dio.patch('/api/comments/auto-reply/rules/$id', data: data).then((r) => r.data);
  Future<Map<String, dynamic>> deleteAutoReplyRule(String id) => _delete('/api/comments/auto-reply/rules/$id');

  // Debug Methods
  Future<Map<String, dynamic>> getDebugWebhookEvents() => _get('/api/debug/webhook-events');
  Future<Map<String, dynamic>> getDebugComments() => _get('/api/debug/comments');
  Future<Map<String, dynamic>> getDebugInbox() => _get('/api/debug/inbox');
}

final dioProvider = Provider((ref) => Dio());
final loggerProvider = Provider((ref) => Logger());
final apiClientProvider = Provider((ref) => ApiClient(ref.watch(dioProvider), ref.watch(loggerProvider), ref));
