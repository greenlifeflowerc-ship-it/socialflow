class MediaItem {
  final String id;
  final String originalUrl;
  final String? editedUrl;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  MediaItem({
    required this.id,
    required this.originalUrl,
    this.editedUrl,
    required this.createdAt,
    this.metadata,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'],
      originalUrl: json['original_url'],
      editedUrl: json['edited_url'],
      createdAt: DateTime.parse(json['created_at']),
      metadata: json['metadata'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'original_url': originalUrl,
    'edited_url': editedUrl,
    'created_at': createdAt.toIso8601String(),
    'metadata': metadata,
  };
}
