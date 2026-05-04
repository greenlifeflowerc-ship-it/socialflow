import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/scheduled_post.dart';
import 'api_client.dart';
import '../models/media_asset.dart';

class PostService {
  final ApiClient _apiClient;
  PostService(this._apiClient);

  Future<List<ScheduledPost>> getPosts() async {
    try {
      final response = await _apiClient.getPosts();
      final postsList = response['posts'] as List<dynamic>? ?? [];
      return postsList.map((p) => ScheduledPost.fromJson(p)).toList();
    } on DioException catch (e) {
      debugPrint('POSTS FAILED URL: ${e.requestOptions.uri}');
      debugPrint('POSTS FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('POSTS FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Posts request failed';
      throw Exception(message);
    }
  }

  /// Cancels/removes an unpublished post via POST /api/posts/:id/cancel.
  /// The old DELETE /api/posts/:id route does not exist on the backend (404).
  Future<void> cancelPost(String postId) async {
    try {
      await _apiClient.cancelPost(postId);
    } on DioException catch (e) {
      debugPrint('POST ACTION FAILED URL: ${e.requestOptions.uri}');
      debugPrint('POST ACTION FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('POST ACTION FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('POST ACTION FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Post action failed';
      throw Exception(message);
    }
  }

  Future<void> retryPost(String postId) async {
    try {
      await _apiClient.retryPost(postId);
    } on DioException catch (e) {
      debugPrint('POST ACTION FAILED URL: ${e.requestOptions.uri}');
      debugPrint('POST ACTION FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('POST ACTION FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('POST ACTION FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Post action failed';
      throw Exception(message);
    }
  }

  Future<void> schedulePost({
    required MediaAsset mediaAsset,
    required String caption,
    required String hashtags,
    required DateTime scheduledAt,
  }) async {
    if (mediaAsset.mediaUrl == null) throw Exception("Media URL is null");
    await _apiClient.createScheduledPost(
      mediaUrl: mediaAsset.mediaUrl!,
      imageUrl: mediaAsset.imageUrl,
      videoUrl: mediaAsset.videoUrl,
      mediaType: mediaAsset.mediaType.name,
      caption: caption,
      hashtags: hashtags.split(' ').where((h) => h.startsWith('#')).toList(),
      scheduledAt: scheduledAt,
    );
  }

  Future<Map<String, dynamic>> publishNow(Map<String, dynamic> data) async {
    try {
      return await _apiClient.publishNow(data);
    } on DioException catch (e) {
      debugPrint('PUBLISH NOW FAILED URL: ${e.requestOptions.uri}');
      debugPrint('PUBLISH NOW FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('PUBLISH NOW FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('PUBLISH NOW FAILED DATA: ${e.response?.data}');
      final respData = e.response?.data;
      final message = respData is Map && respData['error'] != null
          ? respData['error'].toString()
          : e.message ?? 'Publish Now failed';
      throw Exception(message);
    }
  }
}

final postServiceProvider =
    Provider((ref) => PostService(ref.watch(apiClientProvider)));

final postsProvider =
    StateNotifierProvider<PostsNotifier, AsyncValue<List<ScheduledPost>>>(
        (ref) {
  return PostsNotifier(ref.watch(postServiceProvider));
});

class PostsNotifier
    extends StateNotifier<AsyncValue<List<ScheduledPost>>> {
  final PostService _service;
  PostsNotifier(this._service) : super(const AsyncValue.loading()) {
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    state = const AsyncValue.loading();
    try {
      final posts = await _service.getPosts();
      state = AsyncValue.data(posts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Cancels/removes an unpublished post. Uses POST /api/posts/:id/cancel.
  /// Returns null on success, human-readable error string on failure.
  Future<String?> deletePost(String postId) async {
    try {
      await _service.cancelPost(postId);
      fetchPosts();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Returns null on success, human-readable error string on failure.
  Future<String?> retryPost(String postId) async {
    try {
      await _service.retryPost(postId);
      fetchPosts();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Returns null on success, human-readable error string on failure.
  Future<String?> cancelPost(String postId) async {
    try {
      await _service.cancelPost(postId);
      fetchPosts();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Publish an already-created post immediately via POST /api/posts/publish-now.
  /// Returns null on success, human-readable error string on failure.
  Future<String?> publishNow(String postId) async {
    try {
      final body = {'post_id': postId};
      debugPrint('PUBLISH NOW PAYLOAD: $body');
      await _service.publishNow(body);
      fetchPosts();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }
}
