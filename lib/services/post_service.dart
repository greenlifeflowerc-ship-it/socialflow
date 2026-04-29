import 'package:dio/dio.dart';
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
    } on DioException {
      rethrow;
    }
  }
  
  Future<void> deletePost(String postId) async {
    await _apiClient.deletePost(postId);
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
  
  Future<void> publishNow(Map<String, dynamic> data) async {
    await _apiClient.publishNow(data);
  }
}

final postServiceProvider = Provider((ref) => PostService(ref.watch(apiClientProvider)));

final postsProvider = StateNotifierProvider<PostsNotifier, AsyncValue<List<ScheduledPost>>>((ref) {
  return PostsNotifier(ref.watch(postServiceProvider));
});

class PostsNotifier extends StateNotifier<AsyncValue<List<ScheduledPost>>> {
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

  Future<void> deletePost(String postId) async {
    try {
      await _service.deletePost(postId);
      fetchPosts();
    } catch (e) { /* Handle error in UI */ }
  }
}
