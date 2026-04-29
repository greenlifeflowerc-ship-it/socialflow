// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_studio_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiEditJob _$AiEditJobFromJson(Map<String, dynamic> json) => AiEditJob(
      id: json['id'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      prompt: json['prompt'] as String?,
      autoPromptUsed: json['autoPromptUsed'] as bool?,
      provider: json['provider'] as String?,
      model: json['model'] as String?,
      aspectRatio: json['aspectRatio'] as String?,
      resolution: json['resolution'] as String?,
      quality: json['quality'] as String?,
      realism: json['realism'] as String?,
      preserveProduct: json['preserveProduct'] as bool?,
      preservePlanter: json['preservePlanter'] as bool?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      successCount: (json['successCount'] as num?)?.toInt() ?? 0,
      failedCount: (json['failedCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$AiEditJobToJson(AiEditJob instance) => <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'status': instance.status,
      'prompt': instance.prompt,
      'autoPromptUsed': instance.autoPromptUsed,
      'provider': instance.provider,
      'model': instance.model,
      'aspectRatio': instance.aspectRatio,
      'resolution': instance.resolution,
      'quality': instance.quality,
      'realism': instance.realism,
      'preserveProduct': instance.preserveProduct,
      'preservePlanter': instance.preservePlanter,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'itemCount': instance.itemCount,
      'successCount': instance.successCount,
      'failedCount': instance.failedCount,
    };

AiEditItem _$AiEditItemFromJson(Map<String, dynamic> json) => AiEditItem(
      id: json['id'] as String,
      jobId: json['jobId'] as String,
      mediaAssetId: json['mediaAssetId'] as String?,
      originalMediaUrl: json['originalMediaUrl'] as String?,
      originalImageUrl: json['originalImageUrl'] as String?,
      prompt: json['prompt'] as String?,
      generatedPrompt: json['generatedPrompt'] as String?,
      aspectRatio: json['aspectRatio'] as String?,
      resolution: json['resolution'] as String?,
      status: json['status'] as String,
      errorMessage: json['errorMessage'] as String?,
      resultMediaUrl: json['resultMediaUrl'] as String?,
      resultImageUrl: json['resultImageUrl'] as String?,
      resultMediaAssetId: json['resultMediaAssetId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$AiEditItemToJson(AiEditItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'jobId': instance.jobId,
      'mediaAssetId': instance.mediaAssetId,
      'originalMediaUrl': instance.originalMediaUrl,
      'originalImageUrl': instance.originalImageUrl,
      'prompt': instance.prompt,
      'generatedPrompt': instance.generatedPrompt,
      'aspectRatio': instance.aspectRatio,
      'resolution': instance.resolution,
      'status': instance.status,
      'errorMessage': instance.errorMessage,
      'resultMediaUrl': instance.resultMediaUrl,
      'resultImageUrl': instance.resultImageUrl,
      'resultMediaAssetId': instance.resultMediaAssetId,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

AiChatConversation _$AiChatConversationFromJson(Map<String, dynamic> json) =>
    AiChatConversation(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$AiChatConversationToJson(AiChatConversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

AiChatMessage _$AiChatMessageFromJson(Map<String, dynamic> json) =>
    AiChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      role: json['role'] as String,
      text: json['text'] as String,
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$AiChatMessageToJson(AiChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'conversationId': instance.conversationId,
      'role': instance.role,
      'text': instance.text,
      'attachments': instance.attachments,
      'createdAt': instance.createdAt.toIso8601String(),
    };
