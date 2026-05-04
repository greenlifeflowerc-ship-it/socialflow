// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ig_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

IgConversation _$IgConversationFromJson(Map<String, dynamic> json) =>
    IgConversation(
      id: json['id'] as String,
      metaConversationId: json['metaConversationId'] as String?,
      igScopedUserId: json['igScopedUserId'] as String?,
      username: json['username'] as String?,
      userFullName: json['userFullName'] as String?,
      profilePicUrl: json['profilePicUrl'] as String?,
      lastMessageText: json['lastMessageText'] as String?,
      lastMessageAt: json['lastMessageAt'] == null
          ? null
          : DateTime.parse(json['lastMessageAt'] as String),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'active',
      rawParticipants: const [], // populated manually in IgConversation.fromJson
      messages: const [],        // populated manually in IgConversation.fromJson
    );

Map<String, dynamic> _$IgConversationToJson(IgConversation instance) =>
    <String, dynamic>{
      'id': instance.id,
      'metaConversationId': instance.metaConversationId,
      'igScopedUserId': instance.igScopedUserId,
      'username': instance.username,
      'userFullName': instance.userFullName,
      'profilePicUrl': instance.profilePicUrl,
      'lastMessageText': instance.lastMessageText,
      'lastMessageAt': instance.lastMessageAt?.toIso8601String(),
      'unreadCount': instance.unreadCount,
      'status': instance.status,
    };

IgMessage _$IgMessageFromJson(Map<String, dynamic> json) => IgMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      metaMessageId: json['metaMessageId'] as String?,
      direction: json['direction'] as String,
      messageType: json['messageType'] as String,
      text: json['text'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      sentAt: DateTime.parse(json['sentAt'] as String),
      raw: json['raw'] as Map<String, dynamic>?,
      fromId: json['fromId'] as String?,
    );

Map<String, dynamic> _$IgMessageToJson(IgMessage instance) => <String, dynamic>{
      'id': instance.id,
      'conversationId': instance.conversationId,
      'metaMessageId': instance.metaMessageId,
      'direction': instance.direction,
      'messageType': instance.messageType,
      'text': instance.text,
      'mediaUrl': instance.mediaUrl,
      'sentAt': instance.sentAt.toIso8601String(),
      'raw': instance.raw,
      'fromId': instance.fromId,
    };

IgMediaComment _$IgMediaCommentFromJson(Map<String, dynamic> json) =>
    IgMediaComment(
      id: json['id'] as String,
      igCommentId: json['igCommentId'] as String?,
      igMediaId: json['igMediaId'] as String?,
      parentCommentId: json['parentCommentId'] as String?,
      username: json['username'] as String?,
      userId: json['userId'] as String?,
      text: json['text'] as String,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isReply: json['isReply'] as bool? ?? false,
      isHidden: json['isHidden'] as bool? ?? false,
      isDeleted: json['isDeleted'] as bool? ?? false,
      repliedByApp: json['repliedByApp'] as bool? ?? false,
      privateRepliedByApp: json['privateRepliedByApp'] as bool? ?? false,
    );

Map<String, dynamic> _$IgMediaCommentToJson(IgMediaComment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'igCommentId': instance.igCommentId,
      'igMediaId': instance.igMediaId,
      'parentCommentId': instance.parentCommentId,
      'username': instance.username,
      'userId': instance.userId,
      'text': instance.text,
      'likeCount': instance.likeCount,
      'timestamp': instance.timestamp.toIso8601String(),
      'isReply': instance.isReply,
      'isHidden': instance.isHidden,
      'isDeleted': instance.isDeleted,
      'repliedByApp': instance.repliedByApp,
      'privateRepliedByApp': instance.privateRepliedByApp,
    };

AutoReplyRule _$AutoReplyRuleFromJson(Map<String, dynamic> json) =>
    AutoReplyRule(
      id: json['id'] as String,
      name: json['name'] as String,
      isEnabled: json['isEnabled'] as bool? ?? true,
      triggerType: json['triggerType'] as String,
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      replyMode: json['replyMode'] as String,
      publicReplyText: json['publicReplyText'] as String?,
      privateReplyText: json['privateReplyText'] as String?,
      onlyOncePerUser: json['onlyOncePerUser'] as bool? ?? false,
    );

Map<String, dynamic> _$AutoReplyRuleToJson(AutoReplyRule instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'isEnabled': instance.isEnabled,
      'triggerType': instance.triggerType,
      'keywords': instance.keywords,
      'replyMode': instance.replyMode,
      'publicReplyText': instance.publicReplyText,
      'privateReplyText': instance.privateReplyText,
      'onlyOncePerUser': instance.onlyOncePerUser,
    };
