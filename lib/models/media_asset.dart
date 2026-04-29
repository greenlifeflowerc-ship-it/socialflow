import 'package:hive/hive.dart';

part 'media_asset.g.dart';

@HiveType(typeId: 1)
enum MediaType {
  @HiveField(0)
  image,
  @HiveField(1)
  video,
}

@HiveType(typeId: 0)
class MediaAsset extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  String? localPath;

  @HiveField(2)
  String? mediaUrl;

  @HiveField(3)
  String? imageUrl;

  @HiveField(4)
  String? videoUrl;
  
  @HiveField(5)
  late MediaType mediaType;

  @HiveField(6)
  String? mimeType;

  @HiveField(7)
  String? fileName;

  @HiveField(8)
  String? caption;

  @HiveField(9)
  List<String>? hashtags;

  @HiveField(10)
  bool isUploaded = false;

  @HiveField(11)
  bool isPublished = false;

  @HiveField(12)
  DateTime? publishedAt;

  @HiveField(13)
  String? scheduledPostId;

  @HiveField(14)
  late DateTime createdAt;

  @HiveField(15)
  DateTime? uploadedAt;

  @HiveField(16)
  String? lastError;

  MediaAsset();

  factory MediaAsset.fromUploadResponse(Map<String, dynamic> json) {
    // Check for 'media' object first, then fallback to top-level
    final mediaData = json['media'] as Map<String, dynamic>? ?? json;
    
    return MediaAsset()
      ..id = mediaData['id']?.toString() ?? 'media_${DateTime.now().millisecondsSinceEpoch}'
      ..mediaUrl = mediaData['mediaUrl'] ?? mediaData['url'] ?? mediaData['media_url']
      ..imageUrl = mediaData['imageUrl'] ?? mediaData['image_url']
      ..videoUrl = mediaData['videoUrl'] ?? mediaData['video_url']
      ..mediaType = _mediaTypeFromString(mediaData['mediaType'] ?? mediaData['media_type'])
      ..mimeType = mediaData['mimeType'] ?? mediaData['mime_type']
      ..caption = mediaData['caption']
      ..hashtags = (mediaData['hashtags'] as List?)?.map((e) => e.toString()).toList()
      ..isPublished = mediaData['is_published'] ?? false
      ..createdAt = DateTime.now()
      ..uploadedAt = DateTime.now()
      ..isUploaded = true;
  }

  static MediaType _mediaTypeFromString(String? type) {
    return type?.toLowerCase() == 'video' ? MediaType.video : MediaType.image;
  }
}
