import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/api_client.dart';

final instagramAuthServiceProvider =
    Provider<InstagramAuthService>((ref) => InstagramAuthService(ref));

/// Handles the server-side Instagram OAuth flow.
/// Flutter NEVER touches access tokens — all secrets live on the backend.
///
/// Flow:
///   1. [signInWithInstagram] → GET /api/auth/instagram/start
///      → opens the returned authUrl in the external browser.
///   2. The backend exchanges the OAuth code and stores the token.
///   3. The backend redirects to `socialflow://auth`.
///   4. The app catches that deep link via AppLinks in InstagramAccountsScreen
///      and calls GET /api/accounts to refresh.
class InstagramAuthService {
  final Ref _ref;

  InstagramAuthService(this._ref);

  Future<void> signInWithInstagram() async {
    final apiClient = _ref.read(apiClientProvider);
    final response = await apiClient.startInstagramAuth();
    final url = response['authUrl'] as String? ?? response['url'] as String?;
    if (url == null || url.isEmpty) {
      throw 'Backend did not return an auth URL. '
          'Check that /api/auth/instagram/start is configured.';
    }
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not open $url';
    }
  }
}
