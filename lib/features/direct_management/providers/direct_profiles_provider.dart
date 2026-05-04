import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_client.dart';
import '../models/direct_instagram_profile.dart';
import '../repositories/direct_profiles_repository.dart';

final directProfilesRepositoryProvider = Provider<DirectProfilesRepository>(
  (ref) => DirectProfilesRepository(ref.watch(apiClientProvider)),
);

final directProfilesProvider =
    FutureProvider<List<DirectInstagramProfile>>((ref) async {
  return ref.watch(directProfilesRepositoryProvider).getDirectProfiles();
});
