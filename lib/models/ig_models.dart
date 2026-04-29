import 'package:json_annotation/json_annotation.dart';

part 'ig_models.g.dart';

@JsonSerializable()
class IgConversation {
  final String id;
  final String? metaConversationId;
  final String? igScopedUserId;
  final String? username;
  final String? userFullName;
  final String? profilePicUrl;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final String status;

  IgConversation({
    required this.id,
    this.metaConversationId,
    this.igScopedUserId,
    this.username,
    this.userFullName,
    this.profilePicUrl,
    this.lastMessageText,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.status = 'active',
  });

  factory IgConversation.fromJson(Map<String, dynamic> json) {
    // Manual fallbacks for snake_case vs camelCase from different backend versions
    final map = Map<String, dynamic>.from(json);
    map['lastMessageText'] ??= json['last_message_text'];
    map['lastMessageAt'] ??= json['last_message_at'];
    map['igScopedUserId'] ??= json['ig_scoped_user_id'];
    map['metaConversationId'] ??= json['meta_conversation_id'];
    map['profilePicUrl'] ??= json['profile_pic_url'];
    map['userFullName'] ??= json['user_full_name'];
    return _$IgConversationFromJson(map);
  }
  Map<String, dynamic> toJson() => _$IgConversationToJson(this);
}

@JsonSerializable()
class IgMessage {
  final String id;
  final String conversationId;
  final String? metaMessageId;
  final String direction; // inbound, outbound
  final String messageType; // text, image
  final String? text;
  final String? mediaUrl;
  final DateTime sentAt;
  final Map<String, dynamic>? raw;

  IgMessage({
    required this.id,
    required this.conversationId,
    this.metaMessageId,
    required this.direction,
    required this.messageType,
    this.text,
    this.mediaUrl,
    required this.sentAt,
    this.raw,
  });

  factory IgMessage.fromJson(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);
    map['conversationId'] ??= json['conversation_id'];
    map['metaMessageId'] ??= json['meta_message_id'];
    map['messageType'] ??= json['message_type'];
    map['sentAt'] ??= json['sent_at'];
    map['mediaUrl'] ??= json['media_url'];
    return _$IgMessageFromJson(map);
  }
  Map<String, dynamic> toJson() => _$IgMessageToJson(this);
}

@JsonSerializable()
class IgMediaComment {
  final String id;
  final String? igCommentId;
  final String? igMediaId;
  final String? parentCommentId;
  final String? username;
  final String? userId;
  final String text;
  final int likeCount;
  final DateTime timestamp;
  final bool isReply;
  final bool isHidden;
  final bool isDeleted;
  final bool repliedByApp;
  final bool privateRepliedByApp;

  IgMediaComment({
    required this.id,
    this.igCommentId,
    this.igMediaId,
    this.parentCommentId,
    this.username,
    this.userId,
    required this.text,
    this.likeCount = 0,
    required this.timestamp,
    this.isReply = false,
    this.isHidden = false,
    this.isDeleted = false,
    this.repliedByApp = false,
    this.privateRepliedByApp = false,
  });

  factory IgMediaComment.fromJson(Map<String, dynamic> json) => _$IgMediaCommentFromJson(json);
  Map<String, dynamic> toJson() => _$IgMediaCommentToJson(this);
}

@JsonSerializable()
class AutoReplyRule {
  final String id;
  final String name;
  final bool isEnabled;
  final String triggerType; // any_comment, keyword, exact_match
  final List<String> keywords;
  final String replyMode; // public_reply, private_reply, both
  final String? publicReplyText;
  final String? privateReplyText;
  final bool onlyOncePerUser;

  AutoReplyRule({
    required this.id,
    required this.name,
    this.isEnabled = true,
    required this.triggerType,
    this.keywords = const [],
    required this.replyMode,
    this.publicReplyText,
    this.privateReplyText,
    this.onlyOncePerUser = false,
  });

  factory AutoReplyRule.fromJson(Map<String, dynamic> json) => _$AutoReplyRuleFromJson(json);
  Map<String, dynamic> toJson() => _$AutoReplyRuleToJson(this);
}
