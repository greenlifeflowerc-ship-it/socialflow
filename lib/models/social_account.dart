/// Represents a connected Instagram/social account returned by the backend.
/// Tokens are NEVER sent to the Flutter client – they live only on the backend.
class SocialAccount {
  final String id;
  final String? username;
  final String? accountType;   // BUSINESS | CREATOR | PERSONAL
  final String? status;        // connected | active | error | pending | disconnected
  final String? profilePictureUrl;
  final String? instagramUserId; // IG user ID (ig_user_id from backend)
  final DateTime? connectedAt;

  const SocialAccount({
    required this.id,
    this.username,
    this.accountType,
    this.status,
    this.profilePictureUrl,
    this.instagramUserId,
    this.connectedAt,
  });

  factory SocialAccount.fromJson(Map<String, dynamic> json) {
    return SocialAccount(
      id: json['id']?.toString() ?? '',
      username: _emptyToNull(json['username']?.toString()),
      accountType: _emptyToNull(
        (json['account_type'] ?? json['accountType'])?.toString(),
      ),
      status: json['status']?.toString(),
      profilePictureUrl: _emptyToNull(
        (json['profile_picture_url'] ?? json['profilePictureUrl'])?.toString(),
      ),
      // Accept both 'ig_user_id' (backend) and 'instagram_user_id' (legacy)
      instagramUserId: _emptyToNull(
        (json['ig_user_id'] ??
                json['instagram_user_id'] ??
                json['instagramUserId'])
            ?.toString(),
      ),
      connectedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  static String? _emptyToNull(String? v) =>
      (v == null || v.isEmpty) ? null : v;

  /// The display name shown in the UI.
  /// Falls back to "Instagram ID: <id>" when username is unavailable.
  String get displayName {
    if (username != null && username!.isNotEmpty) return '@$username';
    if (instagramUserId != null && instagramUserId!.isNotEmpty) {
      return 'Instagram ID: $instagramUserId';
    }
    return 'Account $id';
  }

  /// True for any status that means the account is usable.
  bool get isActive =>
      status == 'active' || status == 'connected' || status == null;

  /// True only if the backend explicitly marks it disconnected.
  bool get isDisconnected => status == 'disconnected';
}
