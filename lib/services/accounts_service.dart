import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/social_account.dart';
import 'api_client.dart';

class AccountsService {
  final ApiClient _api;

  const AccountsService(this._api);

  /// Fetch all connected Instagram/social accounts for the current user.
  /// Filters out accounts where status == 'disconnected'.
  /// Throws a descriptive [Exception] on 401 or backend error.
  Future<List<SocialAccount>> getAccounts() async {
    try {
      final response = await _api.getAccounts();

      // Accept accounts from any common wrapper key.
      final raw = response['accounts'] as List? ??
          response['data'] as List? ??
          response['results'] as List? ??
          [];

      final accounts = raw
          .map((e) => SocialAccount.fromJson(e as Map<String, dynamic>))
          .toList();

      // Show all accounts except explicitly disconnected ones.
      return accounts.where((a) => !a.isDisconnected).toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('401');
      }
      // Extract real backend error message if available.
      final backendError = e.response?.data is Map
          ? (e.response!.data['error'] ??
              e.response!.data['message'] ??
              e.message)
          : e.message;
      throw Exception(backendError?.toString() ?? 'Failed to load accounts');
    }
  }

  /// Starts the Instagram OAuth flow.
  /// Returns the URL to open in an external browser.
  Future<String> startInstagramAuth() async {
    final response = await _api.startInstagramAuth();
    final url = response['authUrl'] as String? ?? response['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Backend did not return an auth URL.');
    }
    return url;
  }

  /// Disconnect (delete) a social account by its backend ID.
  Future<void> deleteAccount(String id) async {
    await _api.deleteAccount(id);
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Providers
// ──────────────────────────────────────────────────────────────────────────────

final accountsServiceProvider = Provider<AccountsService>(
  (ref) => AccountsService(ref.watch(apiClientProvider)),
);

/// Reactive list of connected social accounts.
/// Invalidate this provider after connecting/disconnecting to refresh.
final socialAccountsProvider = FutureProvider<List<SocialAccount>>((ref) {
  return ref.watch(accountsServiceProvider).getAccounts();
});

