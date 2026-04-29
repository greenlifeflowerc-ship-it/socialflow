import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';

class AiService {
  final ApiClient _apiClient;
  AiService(this._apiClient);

  Future<Map<String, dynamic>> generateCaption({
    required String imageUrl,
    String? mediaUrl,
    String? mediaAssetId,
    required String language,
    required String tone,
    required String provider,
    required String model,
    String captionPreset = 'Luxury Product Caption',
    String? customPrompt,
    String businessName = 'Flower Center',
    String location = 'UAE',
    String? cta,
    int hashtagCount = 10,
  }) {
    return _apiClient.generateCaption(
      imageUrl: imageUrl, mediaUrl: mediaUrl, mediaAssetId: mediaAssetId,
      language: language, tone: tone, provider: provider, model: model,
      captionPreset: captionPreset, customPrompt: customPrompt,
      businessName: businessName, location: location, cta: cta, hashtagCount: hashtagCount,
    );
  }
  
  // Other methods remain...
  Future<Map<String, dynamic>> listModels({required String provider, String? apiKey}) => _apiClient.listModels({'provider': provider, 'apiKey': apiKey});
  Future<Map<String, dynamic>> testModel({required String provider, required String model, String? apiKey}) => _apiClient.testModel({'provider': provider, 'model': model, 'apiKey': apiKey});
  Future<String> generateEditPrompt({ required String imageUrl, required String editStyle, required String provider, required String model}) async {
    final response = await _apiClient.generateEditPrompt({'imageUrl': imageUrl, 'editStyle': editStyle, 'provider': provider, 'model': model, 'language': 'english'});
    final result = response['result'];
    if (result is Map<String, dynamic> && result['prompt'] != null) {
      return result['prompt'] as String;
    }
    return response['prompt'] as String? ?? '';
  }

  Future<String> editImage({ required String originalImageUrl, required String prompt, String? size, required String provider, required String model}) async {
    final response = await _apiClient.editImage({'originalImageUrl': originalImageUrl, 'prompt': prompt, if (size != null) 'size': size, 'provider': provider, 'model': model});
    final result = response['result'];
    String? url;
    if (result is Map<String, dynamic>) {
      url = result['editedImageUrl'] as String? ?? result['edited_image_url'] as String?;
    }
    url ??= response['editedImageUrl'] as String? ?? response['edited_image_url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('No edited image URL returned from AI provider. The image editing feature may not be fully configured on the backend.');
    }
    return url;
  }
}

final aiServiceProvider = Provider((ref) => AiService(ref.watch(apiClientProvider)));
