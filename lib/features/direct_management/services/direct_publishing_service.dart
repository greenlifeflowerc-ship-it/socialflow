import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final directPublishingServiceProvider = Provider((ref) => DirectPublishingService());

class DirectPublishingService {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://graph.facebook.com/v19.0'));

  /// Publishes a photo or video to Instagram using a stored access token
  Future<String> publishMedia({
    required String accessToken,
    required String igBusinessAccountId,
    required String mediaUrl,
    required String caption,
    bool isVideo = false,
  }) async {
    try {
      // 1. Create Media Container
      final Map<String, dynamic> params = {
        'caption': caption,
        'access_token': accessToken,
      };

      if (isVideo) {
        params['media_type'] = 'REELS'; // Or 'VIDEO' for feed
        params['video_url'] = mediaUrl;
      } else {
        params['image_url'] = mediaUrl;
      }

      final containerResponse = await _dio.post('/$igBusinessAccountId/media', queryParameters: params);
      final creationId = containerResponse.data['id'];

      // 2. Wait for processing if it's a video
      if (isVideo) {
        bool isReady = false;
        int attempts = 0;
        const maxAttempts = 20; // Max 2 minutes (20 * 6s)

        while (!isReady && attempts < maxAttempts) {
          attempts++;
          await Future.delayed(const Duration(seconds: 6));
          
          final statusResponse = await _dio.get('/$creationId', queryParameters: {
            'fields': 'status_code',
            'access_token': accessToken,
          });

          final statusCode = statusResponse.data['status_code'];
          if (statusCode == 'FINISHED') {
            isReady = true;
          } else if (statusCode == 'ERROR' || statusCode == 'EXPIRED') {
            throw 'Video processing failed: $statusCode';
          }
        }

        if (!isReady) {
          throw 'Video processing timed out. Please try publishing again in a few minutes.';
        }
      }

      // 3. Publish Container
      final publishResponse = await _dio.post('/$igBusinessAccountId/media_publish', queryParameters: {
        'creation_id': creationId,
        'access_token': accessToken,
      });

      return publishResponse.data['id']; // ID of the published post
    } catch (e) {
      String errorMessage = e.toString();
      if (e is DioException && e.response?.data != null) {
        final errorData = e.response?.data['error'];
        if (errorData != null) {
          errorMessage = errorData['message'] ?? errorMessage;
        }
      }
      print('Direct Publishing Error: $errorMessage');
      throw errorMessage;
    }
  }
}
