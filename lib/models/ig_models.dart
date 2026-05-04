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

  /// Raw participants list from Facebook API (`participants.data`).
  /// Not serialized — populated manually in [fromJson].
  @JsonKey(includeFromJson: false, includeToJson: false)
  final List<dynamic> rawParticipants;

  /// Messages embedded in the conversation (from Facebook API `messages.data`).
  /// Not serialized — populated manually in [fromJson].
  @JsonKey(includeFromJson: false, includeToJson: false)
  final List<IgMessage> messages;

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
    this.rawParticipants = const [],
    this.messages = const [],
  });

  /// Returns the OTHER participant (the one whose id != [myInstagramUserId]).
  /// Falls back to first participant if no match is found.
  Map<String, dynamic>? getOtherParticipant(String? myInstagramUserId) {
    final list = rawParticipants.whereType<Map>().toList();
    if (list.isEmpty) return null;
    if (myInstagramUserId == null || myInstagramUserId.isEmpty) {
      return Map<String, dynamic>.from(list.first);
    }
    final other = list.firstWhere(
      (p) => p['id']?.toString() != myInstagramUserId,
      orElse: () => list.first,
    );
    return Map<String, dynamic>.from(other);
  }

  /// The Instagram-scoped user ID of the OTHER participant.
  String? getOtherParticipantId(String? myInstagramUserId) =>
      getOtherParticipant(myInstagramUserId)?['id']?.toString();

  /// The display name of the OTHER participant.
  String? getOtherParticipantName(String? myInstagramUserId) =>
      getOtherParticipant(myInstagramUserId)?['name']?.toString();

  factory IgConversation.fromJson(Map<String, dynamic> json) {
    // Manual fallbacks for snake_case vs camelCase from different backend versions
    final map = Map<String, dynamic>.from(json);
    map['lastMessageText'] ??= json['last_message_text'];
    // Facebook API uses updated_time as the conversation timestamp
    map['lastMessageAt'] ??= json['last_message_at'] ?? json['updated_time'];
    map['igScopedUserId'] ??= json['ig_scoped_user_id'];
    map['metaConversationId'] ??= json['meta_conversation_id'];
    map['profilePicUrl'] ??= json['profile_pic_url'];
    map['userFullName'] ??= json['user_full_name'];

    // Parse raw participants list
    List<dynamic> rawParticipants = [];
    if (json['participants'] is Map) {
      rawParticipants =
          (json['participants'] as Map)['data'] as List? ?? [];
    } else if (json['participants'] is List) {
      rawParticipants = json['participants'] as List;
    }

    // NOTE: We intentionally do NOT assign igScopedUserId/username from participants here
    // because we don't know which participant is "me" without myInstagramUserId context.
    // Use getOtherParticipant(myInstagramUserId) at the call site instead.

    // Extract messages from Facebook API format
    List<IgMessage> parsedMessages = [];
    if (json['messages'] is Map) {
      final msgData = (json['messages'] as Map)['data'] as List? ?? [];
      parsedMessages = msgData
          .map((m) {
            final msgMap = Map<String, dynamic>.from(m as Map<String, dynamic>);
            msgMap['conversationId'] = json['id'];
            msgMap['text'] ??= m['message'] as String?;
            msgMap['sentAt'] ??= m['created_time'] as String?;
            if (msgMap['direction'] == null) msgMap['direction'] = 'inbound';
            if (msgMap['messageType'] == null) msgMap['messageType'] = 'text';
            // Preserve 'from' so IgMessage.fromJson can extract fromId
            // (IgMessage.fromJson reads json['from'] directly)
            try {
              return IgMessage.fromJson(msgMap);
            } catch (_) {
              return null;
            }
          })
          .whereType<IgMessage>()
          .toList();

      if (map['lastMessageText'] == null && parsedMessages.isNotEmpty) {
        map['lastMessageText'] = parsedMessages.last.text;
      }
    }

    // Use generated code for all standard fields, then add non-serialized fields manually
    final base = _$IgConversationFromJson(map);
    return IgConversation(
      id: base.id,
      metaConversationId: base.metaConversationId,
      igScopedUserId: base.igScopedUserId,
      username: base.username,
      userFullName: base.userFullName,
      profilePicUrl: base.profilePicUrl,
      lastMessageText: base.lastMessageText,
      lastMessageAt: base.lastMessageAt,
      unreadCount: base.unreadCount,
      status: base.status,
      rawParticipants: rawParticipants,
      messages: parsedMessages,
    );
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
  /// Sender's Instagram-scoped user ID (from Facebook API `message.from.id`).
  /// Compare with myInstagramUserId to determine ownership: isMine = fromId == myIgUserId.
  final String? fromId;

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
    this.fromId,
  });

  factory IgMessage.fromJson(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);
    map['conversationId'] ??= json['conversation_id'];
    map['metaMessageId'] ??= json['meta_message_id'];
    map['messageType'] ??= json['message_type'] ?? 'text';
    // Facebook API uses 'message' for the text and 'created_time' for the timestamp
    map['text'] ??= json['message'] as String?;
    map['sentAt'] ??= json['sent_at'] ?? json['created_time'];
    map['mediaUrl'] ??= json['media_url'];
    if (map['direction'] == null) map['direction'] = 'inbound';
    // Extract sender ID from Facebook API message.from.id
    if (map['fromId'] == null) {
      map['fromId'] ??= json['from_id']?.toString();
      if (map['fromId'] == null && json['from'] is Map) {
        map['fromId'] = (json['from'] as Map)['id']?.toString();
      }
    }
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
