// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_insights.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AccountInsights _$AccountInsightsFromJson(Map<String, dynamic> json) =>
    AccountInsights(
      totalFollowers: (json['totalFollowers'] as num).toInt(),
      totalFollowing: (json['totalFollowing'] as num).toInt(),
      totalPosts: (json['totalPosts'] as num).toInt(),
      engagementRate: (json['engagementRate'] as num).toDouble(),
      followerGrowth: (json['followerGrowth'] as List<dynamic>)
          .map((e) => FollowerDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      engagementStats: (json['engagementStats'] as List<dynamic>)
          .map((e) => EngagementDataPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      topPosts: (json['topPosts'] as List<dynamic>)
          .map((e) => TopPost.fromJson(e as Map<String, dynamic>))
          .toList(),
      bestTimeToPost: json['bestTimeToPost'] as String,
      bestDayToPost: json['bestDayToPost'] as String,
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$AccountInsightsToJson(AccountInsights instance) =>
    <String, dynamic>{
      'totalFollowers': instance.totalFollowers,
      'totalFollowing': instance.totalFollowing,
      'totalPosts': instance.totalPosts,
      'engagementRate': instance.engagementRate,
      'followerGrowth': instance.followerGrowth,
      'engagementStats': instance.engagementStats,
      'topPosts': instance.topPosts,
      'bestTimeToPost': instance.bestTimeToPost,
      'bestDayToPost': instance.bestDayToPost,
      'recommendations': instance.recommendations,
    };

FollowerDataPoint _$FollowerDataPointFromJson(Map<String, dynamic> json) =>
    FollowerDataPoint(
      DateTime.parse(json['date'] as String),
      (json['count'] as num).toInt(),
    );

Map<String, dynamic> _$FollowerDataPointToJson(FollowerDataPoint instance) =>
    <String, dynamic>{
      'date': instance.date.toIso8601String(),
      'count': instance.count,
    };

EngagementDataPoint _$EngagementDataPointFromJson(Map<String, dynamic> json) =>
    EngagementDataPoint(
      json['label'] as String,
      (json['value'] as num).toInt(),
    );

Map<String, dynamic> _$EngagementDataPointToJson(EngagementDataPoint instance) =>
    <String, dynamic>{
      'label': instance.label,
      'value': instance.value,
    };

TopPost _$TopPostFromJson(Map<String, dynamic> json) => TopPost(
      id: json['id'] as String,
      imageUrl: json['imageUrl'] as String,
      likes: (json['likes'] as num).toInt(),
      comments: (json['comments'] as num).toInt(),
      engagement: (json['engagement'] as num).toInt(),
    );

Map<String, dynamic> _$TopPostToJson(TopPost instance) => <String, dynamic>{
      'id': instance.id,
      'imageUrl': instance.imageUrl,
      'likes': instance.likes,
      'comments': instance.comments,
      'engagement': instance.engagement,
    };
