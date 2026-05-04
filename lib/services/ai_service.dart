import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/ai/prompt_builder.dart';
import '../models/brand_profile.dart';
import 'api_client.dart';

class AiService {
  final ApiClient _apiClient;
  AiService(this._apiClient);

  /// Generate a caption using explicit parameters.
  /// Prefer [generateCaptionWithProfile] for personalised output.
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
  }) {
    return _apiClient.generateCaption(
      imageUrl: imageUrl,
      mediaUrl: mediaUrl,
      mediaAssetId: mediaAssetId,
      language: language,
      tone: tone,
      provider: provider,
      model: model,
      captionPreset: captionPreset,
      customPrompt: customPrompt,
      businessName: businessName,
      location: location,
      cta: cta,
      hashtagCount: hashtagCount,
    );
  }

  /// Preferred: generate a caption from a saved [BrandProfile] + optional per-post context.
  Future<Map<String, dynamic>> generateCaptionWithProfile({
    required String imageUrl,
    String? mediaUrl,
    String? mediaAssetId,
    required String provider,
    required String model,
    required BrandProfile profile,
    String? postAbout,
    String? productName,
    String? offer,
    String? postAudience,
    String? postTone,
    String? postLanguage,
    String? postCta,
    String? extraNotes,
  }) {
    final params = AiPromptBuilder.buildCaptionParams(
      profile,
      postAbout: postAbout,
      productName: productName,
      offer: offer,
      postAudience: postAudience,
      postTone: postTone,
      postLanguage: postLanguage,
      postCta: postCta,
      extraNotes: extraNotes,
    );
    debugPrint('GENERATE CAPTION language=${params['language']}, '
        'tone=${params['tone']}, business=${params['businessName']}');
    return _apiClient.generateCaption(
      imageUrl: imageUrl,
      mediaUrl: mediaUrl,
      mediaAssetId: mediaAssetId,
      language: params['language'] as String,
      tone: params['tone'] as String,
      provider: provider,
      model: model,
      captionPreset: params['captionPreset'] as String,
      customPrompt: params['customPrompt'] as String?,
      businessName: params['businessName'] as String,
      location: params['location'] as String,
      cta: params['cta'] as String?,
      hashtagCount: params['hashtagCount'] as int,
    );
  }

  /// Generate Instagram post ideas via POST /api/ai/generate.
  Future<String> generatePostIdeas({
    required String provider,
    required String model,
    required BrandProfile profile,
    String? apiKey,
    int count = 5,
    String goal = 'sales',
    String contentType = 'image post',
    String? overrideLanguage,
    String? overrideTone,
  }) async {
    final prompt = AiPromptBuilder.buildPostIdeasPrompt(
      profile,
      count: count,
      goal: goal,
      contentType: contentType,
      overrideLanguage: overrideLanguage,
      overrideTone: overrideTone,
    );
    debugPrint('POST IDEAS PROMPT length=${prompt.length}');
    final response = await _apiClient.aiGenerate({
      'prompt': prompt,
      'model': model,
      if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
    });
    if (response['ok'] == true) {
      return response['text'] as String? ?? '';
    }
    throw Exception(response['error'] ?? 'AI generation failed');
  }

  /// Generate Instagram Reels ideas via POST /api/ai/generate.
  Future<String> generateReelsIdeas({
    required String provider,
    required String model,
    required BrandProfile profile,
    String? apiKey,
    int count = 3,
    String? topic,
    String? overrideLanguage,
    String? overrideTone,
  }) async {
    final prompt = AiPromptBuilder.buildReelsIdeasPrompt(
      profile,
      count: count,
      topic: topic,
      overrideLanguage: overrideLanguage,
      overrideTone: overrideTone,
    );
    debugPrint('REELS IDEAS PROMPT length=${prompt.length}');
    final response = await _apiClient.aiGenerate({
      'prompt': prompt,
      'model': model,
      if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
    });
    if (response['ok'] == true) {
      return response['text'] as String? ?? '';
    }
    throw Exception(response['error'] ?? 'AI generation failed');
  }

  // ── Unchanged methods ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> listModels({required String provider, String? apiKey}) =>
      _apiClient.listModels({'provider': provider, 'apiKey': apiKey});

  Future<Map<String, dynamic>> testModel(
          {required String provider, required String model, String? apiKey}) =>
      _apiClient.testModel({'provider': provider, 'model': model, 'apiKey': apiKey});

  Future<String> generateEditPrompt({
    required String imageUrl,
    required String editStyle,
    required String provider,
    required String model,
  }) async {
    final response = await _apiClient.generateEditPrompt({
      'imageUrl': imageUrl,
      'editStyle': editStyle,
      'provider': provider,
      'model': model,
      'language': 'english',
    });
    final result = response['result'];
    if (result is Map<String, dynamic> && result['prompt'] != null) {
      return result['prompt'] as String;
    }
    return response['prompt'] as String? ?? '';
  }

  Future<String> editImage({
    required String originalImageUrl,
    required String prompt,
    String? size,
    required String provider,
    required String model,
  }) async {
    final response = await _apiClient.editImage({
      'originalImageUrl': originalImageUrl,
      'prompt': prompt,
      if (size != null) 'size': size,
      'provider': provider,
      'model': model,
    });
    final result = response['result'];
    String? url;
    if (result is Map<String, dynamic>) {
      url = result['editedImageUrl'] as String? ?? result['edited_image_url'] as String?;
    }
    url ??= response['editedImageUrl'] as String? ?? response['edited_image_url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('No edited image URL returned from AI provider. '
          'The image editing feature may not be fully configured on the backend.');
    }
    return url;
  }
}

final aiServiceProvider = Provider((ref) => AiService(ref.watch(apiClientProvider)));
