// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media_asset.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MediaAssetAdapter extends TypeAdapter<MediaAsset> {
  @override
  final int typeId = 0;

  @override
  MediaAsset read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MediaAsset()
      ..id = fields[0] as String
      ..localPath = fields[1] as String?
      ..mediaUrl = fields[2] as String?
      ..imageUrl = fields[3] as String?
      ..videoUrl = fields[4] as String?
      ..mediaType = fields[5] as MediaType
      ..mimeType = fields[6] as String?
      ..fileName = fields[7] as String?
      ..caption = fields[8] as String?
      ..hashtags = (fields[9] as List?)?.cast<String>()
      ..isUploaded = fields[10] as bool
      ..isPublished = fields[11] as bool
      ..publishedAt = fields[12] as DateTime?
      ..scheduledPostId = fields[13] as String?
      ..createdAt = fields[14] as DateTime
      ..uploadedAt = fields[15] as DateTime?
      ..lastError = fields[16] as String?;
  }

  @override
  void write(BinaryWriter writer, MediaAsset obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.localPath)
      ..writeByte(2)
      ..write(obj.mediaUrl)
      ..writeByte(3)
      ..write(obj.imageUrl)
      ..writeByte(4)
      ..write(obj.videoUrl)
      ..writeByte(5)
      ..write(obj.mediaType)
      ..writeByte(6)
      ..write(obj.mimeType)
      ..writeByte(7)
      ..write(obj.fileName)
      ..writeByte(8)
      ..write(obj.caption)
      ..writeByte(9)
      ..write(obj.hashtags)
      ..writeByte(10)
      ..write(obj.isUploaded)
      ..writeByte(11)
      ..write(obj.isPublished)
      ..writeByte(12)
      ..write(obj.publishedAt)
      ..writeByte(13)
      ..write(obj.scheduledPostId)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.uploadedAt)
      ..writeByte(16)
      ..write(obj.lastError);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaAssetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MediaTypeAdapter extends TypeAdapter<MediaType> {
  @override
  final int typeId = 1;

  @override
  MediaType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MediaType.image;
      case 1:
        return MediaType.video;
      default:
        return MediaType.image;
    }
  }

  @override
  void write(BinaryWriter writer, MediaType obj) {
    switch (obj) {
      case MediaType.image:
        writer.writeByte(0);
        break;
      case MediaType.video:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
