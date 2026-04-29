import 'media_asset.dart';

enum PostStatus {
  draft,
  caption_ready,
  approved,
  scheduled,
  publishing,
  published,
  failed
}

class ScheduledPost {
  final String id;
  final String mediaUrl;
  final String? imageUrl;
  final String? videoUrl;
  final MediaType mediaType;
  final String? caption;
  final List<String> hashtags;
  final DateTime? scheduledAt;
  final PostStatus status;
  final String? errorMessage;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;

  ScheduledPost({
    required this.id,
    required this.mediaUrl,
    this.imageUrl,
    this.videoUrl,
    required this.mediaType,
    this.caption,
    required this.hashtags,
    this.scheduledAt,
    required this.status,
    this.errorMessage,
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
  });

  factory ScheduledPost.fromJson(Map<String, dynamic> json) {
    return ScheduledPost(
      id: json['id'] ?? json['_id'], // Support for different ID fields
      mediaUrl: json['mediaUrl'] ?? json['media_url'],
      imageUrl: json['imageUrl'] ?? json['image_url'],
      videoUrl: json['videoUrl'] ?? json['video_url'],
      mediaType: MediaType.values.firstWhere(
        (e) => e.name == (json['mediaType'] ?? json['media_type']),
        orElse: () => MediaType.image,
      ),
      caption: json['caption'],
      hashtags: List<String>.from(json['hashtags'] ?? []),
      scheduledAt: _parseDate(json['scheduledAt'] ?? json['scheduled_at']),
      status: PostStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PostStatus.draft,
      ),
      errorMessage: json['errorMessage'] ?? json['error_message'],
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
      publishedAt: _parseDate(json['publishedAt'] ?? json['published_at']),
    );
  }

  static DateTime? _parseDate(String? dateStr) {
    if (dateStr == null) return null;
    return DateTime.tryParse(dateStr);
  }
}
