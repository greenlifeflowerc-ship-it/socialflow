import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_studio_models.dart';
import 'api_client.dart';

final aiStudioServiceProvider = Provider((ref) => AiStudioService(ref.watch(apiClientProvider)));

class AiStudioService {
  final ApiClient _apiClient;
  AiStudioService(this._apiClient);

  Future<Map<String, dynamic>> chat(String message, {List<Map<String, dynamic>>? attachments, String? conversationId, String? provider, String? model}) async {
    return await _apiClient.aiChat({
      'message': message,
      if (attachments != null) 'attachments': attachments,
      if (conversationId != null) 'conversationId': conversationId,
      if (provider != null) 'provider': provider,
      if (model != null) 'model': model,
    });
  }

  Future<List<AiEditJob>> getJobs() async {
    try {
      final response = await _apiClient.getAiJobs();
      final list = _apiClient.parseListFromAnyKey(response, ['jobs', 'data', 'items', 'results']);
      return list.map((e) => AiEditJob.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>> getJobDetails(String id) async {
    return await _apiClient.getAiJobDetails(id);
  }
}
