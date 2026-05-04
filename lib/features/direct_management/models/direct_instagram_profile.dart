/// Represents a connected Instagram profile fetched from the backend.
/// The access token is NEVER sent to Flutter — it lives only on the backend.
class DirectInstagramProfile {
  final String id;
  final String userId;
  final String igBusinessAccountId;
  final String? username;
  final String? profilePictureUrl;
  final String? status;
  final String? accountType;
  final DateTime? createdAt;

  const DirectInstagramProfile({
    required this.id,
    required this.userId,
    required this.igBusinessAccountId,
    this.username,
    this.profilePictureUrl,
    this.status,
    this.accountType,
    this.createdAt,
  });

  factory DirectInstagramProfile.fromJson(Map<String, dynamic> json) {
    return DirectInstagramProfile(
      id: json['id']?.toString() ?? '',
      userId: (json['user_id'] ?? json['userId'] ?? '')?.toString() ?? '',
      igBusinessAccountId: (json['instagram_user_id'] ??
              json['ig_business_account_id'] ??
              json['igBusinessAccountId'] ??
              '')
          .toString(),
      username: json['username'] as String?,
      profilePictureUrl:
          (json['profile_picture_url'] ?? json['profilePictureUrl'])
              as String?,
      status: json['status'] as String?,
      accountType:
          (json['account_type'] ?? json['accountType']) as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'ig_business_account_id': igBusinessAccountId,
      'username': username,
      'profile_picture_url': profilePictureUrl,
      'status': status,
      'account_type': accountType,
    };
  }
}
