import 'package:json_annotation/json_annotation.dart';

part 'ai_studio_models.g.dart';

@JsonSerializable(explicitToJson: true)
class AiEditJob {
  final String id;
  final String type; // single, bulk, chat_edit
  final String status; // pending, running, completed, failed, cancelled
  final String? prompt;
  final bool? autoPromptUsed;
  final String? provider;
  final String? model;
  final String? aspectRatio;
  final String? resolution;
  final String? quality;
  final String? realism;
  final bool? preserveProduct;
  final bool? preservePlanter;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final int itemCount;
  final int successCount;
  final int failedCount;

  AiEditJob({
    required this.id,
    required this.type,
    required this.status,
    this.prompt,
    this.autoPromptUsed,
    this.provider,
    this.model,
    this.aspectRatio,
    this.resolution,
    this.quality,
    this.realism,
    this.preserveProduct,
    this.preservePlanter,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.itemCount = 0,
    this.successCount = 0,
    this.failedCount = 0,
  });

  factory AiEditJob.fromJson(Map<String, dynamic> json) => _$AiEditJobFromJson(json);
  Map<String, dynamic> toJson() => _$AiEditJobToJson(this);
}

@JsonSerializable()
class AiEditItem {
  final String id;
  final String jobId;
  final String? mediaAssetId;
  final String? originalMediaUrl;
  final String? originalImageUrl;
  final String? prompt;
  final String? generatedPrompt;
  final String? aspectRatio;
  final String? resolution;
  final String status;
  final String? errorMessage;
  final String? resultMediaUrl;
  final String? resultImageUrl;
  final String? resultMediaAssetId;
  final DateTime createdAt;
  final DateTime updatedAt;

  AiEditItem({
    required this.id,
    required this.jobId,
    this.mediaAssetId,
    this.originalMediaUrl,
    this.originalImageUrl,
    this.prompt,
    this.generatedPrompt,
    this.aspectRatio,
    this.resolution,
    required this.status,
    this.errorMessage,
    this.resultMediaUrl,
    this.resultImageUrl,
    this.resultMediaAssetId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiEditItem.fromJson(Map<String, dynamic> json) => _$AiEditItemFromJson(json);
  Map<String, dynamic> toJson() => _$AiEditItemToJson(this);
}

@JsonSerializable()
class AiChatConversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  AiChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AiChatConversation.fromJson(Map<String, dynamic> json) => _$AiChatConversationFromJson(json);
  Map<String, dynamic> toJson() => _$AiChatConversationToJson(this);
}

@JsonSerializable()
class AiChatMessage {
  final String id;
  final String conversationId;
  final String role; // user, assistant
  final String text;
  final List<Map<String, dynamic>>? attachments;
  final DateTime createdAt;

  AiChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.text,
    this.attachments,
    required this.createdAt,
  });

  factory AiChatMessage.fromJson(Map<String, dynamic> json) => _$AiChatMessageFromJson(json);
  Map<String, dynamic> toJson() => _$AiChatMessageToJson(this);
}
