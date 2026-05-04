import '../../../services/api_client.dart';
import '../models/direct_instagram_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetches connected Instagram profiles from the Node.js backend.
/// Tokens and secrets are NEVER returned to the Flutter client.
class DirectProfilesRepository {
  final ApiClient _apiClient;

  DirectProfilesRepository(this._apiClient);

  Future<List<DirectInstagramProfile>> getDirectProfiles() async {
    final response = await _apiClient.getAccounts();
    final currentUserId =
        Supabase.instance.client.auth.currentUser?.id ?? '';
    final list = response['accounts'] as List? ??
        response['data'] as List? ??
        [];
    return list
        .map((e) => DirectInstagramProfile.fromJson({
              ...(e as Map<String, dynamic>),
              'user_id': currentUserId,
            }))
        .toList();
  }

  Future<void> deleteProfile(String id) async {
    await _apiClient.deleteAccount(id);
  }
}
