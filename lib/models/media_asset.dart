import 'package:flutter/foundation.dart';
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
    // Backend returns: { ok: true, asset: { id, secure_url, media_url, resource_type } }
    // Also support legacy wrappers: { media: { ... } } or flat { id, url, ... }
    final mediaData = json['asset'] as Map<String, dynamic>?
        ?? json['media'] as Map<String, dynamic>?
        ?? json;

    final backendId   = mediaData['id']?.toString();
    final secureUrl   = mediaData['secure_url']?.toString();
    final mediaUrl    = (secureUrl ?? mediaData['media_url'] ?? mediaData['mediaUrl'] ?? mediaData['url'])?.toString();
    final resourceType = (mediaData['resource_type'] ?? mediaData['mediaType'] ?? mediaData['media_type'])?.toString();
    final isVideo     = resourceType?.toLowerCase() == 'video';

    debugPrint('UPLOAD RESPONSE: $json');
    debugPrint('BACKEND MEDIA ASSET ID: $backendId');
    debugPrint('MEDIA URL: $mediaUrl');
    debugPrint('RESOURCE TYPE: $resourceType');

    return MediaAsset()
      // id is the real backend asset ID — never a local placeholder
      ..id          = backendId ?? 'media_${DateTime.now().millisecondsSinceEpoch}'
      ..mediaUrl    = mediaUrl
      ..imageUrl    = isVideo ? (mediaData['imageUrl'] ?? mediaData['image_url'])?.toString() : (secureUrl ?? mediaData['imageUrl'] ?? mediaData['image_url'])?.toString()
      ..videoUrl    = isVideo ? (secureUrl ?? mediaData['videoUrl'] ?? mediaData['video_url'])?.toString() : (mediaData['videoUrl'] ?? mediaData['video_url'])?.toString()
      ..mediaType   = _mediaTypeFromString(resourceType)
      ..mimeType    = (mediaData['mimeType'] ?? mediaData['mime_type'])?.toString()
      ..caption     = mediaData['caption']?.toString()
      ..hashtags    = (mediaData['hashtags'] as List?)?.map((e) => e.toString()).toList()
      ..isPublished = (mediaData['is_published'] as bool?) ?? false
      ..createdAt   = DateTime.now()
      ..uploadedAt  = DateTime.now()
      ..isUploaded  = true;
  }

  static MediaType _mediaTypeFromString(String? type) {
    return type?.toLowerCase() == 'video' ? MediaType.video : MediaType.image;
  }
}
