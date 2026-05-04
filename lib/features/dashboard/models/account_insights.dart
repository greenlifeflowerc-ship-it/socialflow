import 'package:json_annotation/json_annotation.dart';

part 'account_insights.g.dart';

@JsonSerializable()
class AccountInsights {
  final int totalFollowers;
  final int totalFollowing;
  final int totalPosts;
  final double engagementRate;
  final List<FollowerDataPoint> followerGrowth;
  final List<EngagementDataPoint> engagementStats;
  final List<TopPost> topPosts;
  final String bestTimeToPost;
  final String bestDayToPost;
  final List<String> recommendations;

  AccountInsights({
    required this.totalFollowers,
    required this.totalFollowing,
    required this.totalPosts,
    required this.engagementRate,
    required this.followerGrowth,
    required this.engagementStats,
    required this.topPosts,
    required this.bestTimeToPost,
    required this.bestDayToPost,
    required this.recommendations,
  });

  factory AccountInsights.fromJson(Map<String, dynamic> json) => _$AccountInsightsFromJson(json);
  Map<String, dynamic> toJson() => _$AccountInsightsToJson(this);
}

@JsonSerializable()
class FollowerDataPoint {
  final DateTime date;
  final int count;

  FollowerDataPoint(this.date, this.count);

  factory FollowerDataPoint.fromJson(Map<String, dynamic> json) => _$FollowerDataPointFromJson(json);
  Map<String, dynamic> toJson() => _$FollowerDataPointToJson(this);
}

@JsonSerializable()
class EngagementDataPoint {
  final String label;
  final int value;

  EngagementDataPoint(this.label, this.value);

  factory EngagementDataPoint.fromJson(Map<String, dynamic> json) => _$EngagementDataPointFromJson(json);
  Map<String, dynamic> toJson() => _$EngagementDataPointToJson(this);
}

@JsonSerializable()
class TopPost {
  final String id;
  final String imageUrl;
  final int likes;
  final int comments;
  final int engagement;

  TopPost({
    required this.id,
    required this.imageUrl,
    required this.likes,
    required this.comments,
    required this.engagement,
  });

  factory TopPost.fromJson(Map<String, dynamic> json) => _$TopPostFromJson(json);
  Map<String, dynamic> toJson() => _$TopPostToJson(this);
}
