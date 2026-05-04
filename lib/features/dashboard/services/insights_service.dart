import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_client.dart';

// ─── InsightsData ─────────────────────────────────────────────────────────────
// Holds real data from:
//   GET /api/insights/account?account_id=...
//   GET /api/instagram/media?account_id=...

class InsightsData {
  /// Raw insights root from the backend. May contain a 'data' list (Facebook
  /// Graph API format) or a flat map of metrics.
  final Map<String, dynamic> rawInsights;

  /// Parsed media list from /api/instagram/media → media.data
  final List<Map<String, dynamic>> mediaList;

  /// Non-null when a partial/recoverable error occurred.
  final String? partialError;

  const InsightsData({
    required this.rawInsights,
    required this.mediaList,
    this.partialError,
  });

  bool get hasInsights => rawInsights.isNotEmpty;
  bool get hasMedia => mediaList.isNotEmpty;

  // ── Metric extraction ──
  // Facebook Graph API shape inside rawInsights:
  //   { "data": [ { "name": "follower_count", "values": [ { "value": 123 } ] } ] }
  dynamic metricLatest(String name) {
    final data = rawInsights['data'];
    if (data is List) {
      for (final item in data) {
        if (item is! Map) continue;
        if (item['name'] == name) {
          final values = item['values'];
          if (values is List && values.isNotEmpty) {
            return values.last['value'];
          }
          // single 'value' key
          if (item['value'] != null) return item['value'];
        }
      }
    }
    // Flat map shape: { "follower_count": 123, ... }
    return rawInsights[name];
  }

  String metricStr(String name, {String fallback = 'N/A'}) {
    final v = metricLatest(name);
    if (v == null) return fallback;
    if (v is num) return v.toStringAsFixed(0);
    return v.toString();
  }

  // ── Derived from media ──

  /// Top posts sorted by total engagement (likes + comments), up to 10.
  List<Map<String, dynamic>> get topPosts {
    final sorted = [...mediaList];
    sorted.sort((a, b) {
      final ae = (a['like_count'] as num? ?? 0) +
          (a['comments_count'] as num? ?? 0);
      final be = (b['like_count'] as num? ?? 0) +
          (b['comments_count'] as num? ?? 0);
      return be.compareTo(ae);
    });
    return sorted.take(10).toList();
  }

  /// Total likes + comments across all media.
  int get totalInteractionsFromMedia {
    return mediaList.fold<int>(0, (sum, m) {
      return sum +
          (m['like_count'] as num? ?? 0).toInt() +
          (m['comments_count'] as num? ?? 0).toInt();
    });
  }

  /// Engagement grouped by media type → [{'label':..., 'value':...}]
  List<Map<String, dynamic>> get engagementByType {
    final totals = <String, int>{};
    for (final m in mediaList) {
      final type = (m['media_type'] as String? ?? 'OTHER');
      final eng = (m['like_count'] as num? ?? 0).toInt() +
          (m['comments_count'] as num? ?? 0).toInt();
      totals[type] = (totals[type] ?? 0) + eng;
    }
    return totals.entries
        .map((e) => {'label': e.key, 'value': e.value})
        .toList();
  }

  /// Most common posting hour derived from media timestamps.
  String get bestTimeFromMedia {
    if (mediaList.isEmpty) return 'N/A';
    final hours = <int, int>{};
    for (final m in mediaList) {
      final ts = m['timestamp']?.toString();
      if (ts == null) continue;
      try {
        final hour = DateTime.parse(ts).toLocal().hour;
        hours[hour] = (hours[hour] ?? 0) + 1;
      } catch (_) {}
    }
    if (hours.isEmpty) return 'N/A';
    final best =
        hours.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    final suffix = best < 12 ? 'AM' : 'PM';
    final h12 = best == 0 ? 12 : (best > 12 ? best - 12 : best);
    return '$h12:00 $suffix';
  }

  /// Most common posting weekday derived from media timestamps.
  String get bestDayFromMedia {
    if (mediaList.isEmpty) return 'N/A';
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    final dayCounts = <int, int>{};
    for (final m in mediaList) {
      final ts = m['timestamp']?.toString();
      if (ts == null) continue;
      try {
        final wd = DateTime.parse(ts).toLocal().weekday; // 1=Mon, 7=Sun
        dayCounts[wd] = (dayCounts[wd] ?? 0) + 1;
      } catch (_) {}
    }
    if (dayCounts.isEmpty) return 'N/A';
    final best =
        dayCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    return days[best - 1];
  }

  /// Recommendations derived from real media data. Falls back to generic
  /// advice when not enough data is available.
  List<String> get recommendations {
    if (!hasMedia) {
      return [
        'Publish consistently to build account history.',
        'Use posts with higher comments_count as creative references.',
        'Check performance again after more media insights are available.',
      ];
    }
    final recs = <String>[];

    // Media type with higher average engagement
    int _avg(List<Map<String, dynamic>> items) {
      if (items.isEmpty) return 0;
      final total = items.fold<int>(0, (s, m) =>
          s + (m['like_count'] as num? ?? 0).toInt() +
          (m['comments_count'] as num? ?? 0).toInt());
      return total ~/ items.length;
    }

    final videos = mediaList
        .where((m) => m['media_type'] == 'VIDEO')
        .toList();
    final images = mediaList
        .where((m) => m['media_type'] == 'IMAGE')
        .toList();
    if (videos.isNotEmpty && images.isNotEmpty) {
      final avgV = _avg(videos);
      final avgI = _avg(images);
      if (avgV > avgI) {
        recs.add(
            'Video posts get higher engagement on this account '
            '(avg $avgV vs $avgI for images).');
      } else {
        recs.add(
            'Image posts get higher engagement on this account '
            '(avg $avgI vs $avgV for videos).');
      }
    }

    final time = bestTimeFromMedia;
    final day = bestDayFromMedia;
    if (time != 'N/A') {
      recs.add('Most of your posts are published around $time.');
    }
    if (day != 'N/A') {
      recs.add('$day is your most active posting day.');
    }

    if (recs.isEmpty) {
      recs.add('Keep publishing consistently to build account history.');
      recs.add(
          'Check performance again after more media insights are available.');
    }
    return recs;
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final realInsightsProvider =
    FutureProvider.family<InsightsData, String>((ref, accountId) async {
  final api = ref.read(apiClientProvider);
  Map<String, dynamic> rawInsights = {};
  List<Map<String, dynamic>> mediaList = [];
  String? partialError;

  // 1 ── Account insights ────────────────────────────────────────────────────
  try {
    final response = await api.getAccountInsights(accountId);
    debugPrint('INSIGHTS RAW RESPONSE: $response');

    // Expected: { "ok": true, "insights": { "data": [...] } }
    // Fallback:  { "data": [...] }  or any other map
    final insightsRoot = response['insights'];
    if (insightsRoot is Map) {
      rawInsights = Map<String, dynamic>.from(insightsRoot);
    } else {
      rawInsights = response;
    }
    debugPrint('INSIGHTS KEYS: ${rawInsights.keys.toList()}');
  } on DioException catch (e) {
    debugPrint('INSIGHTS FAILED URL: ${e.requestOptions.uri}');
    debugPrint('INSIGHTS FAILED METHOD: ${e.requestOptions.method}');
    debugPrint('INSIGHTS FAILED STATUS: ${e.response?.statusCode}');
    debugPrint('INSIGHTS FAILED DATA: ${e.response?.data}');
    final data = e.response?.data;
    final msg = data is Map && data['error'] != null
        ? data['error'].toString()
        : e.message ?? 'Insights unavailable';
    // Permission error detection
    if (e.response?.statusCode == 403 ||
        (msg.toLowerCase().contains('permission') ||
            msg.toLowerCase().contains('permission'))) {
      partialError =
          'Instagram insights permission is missing. '
          'Reconnect the account after enabling '
          'instagram_business_manage_insights.';
    } else {
      partialError = 'Account insights: $msg';
    }
  } catch (e) {
    debugPrint('INSIGHTS UNEXPECTED ERROR: $e');
    partialError = 'Account insights unavailable: $e';
  }

  // 2 ── Instagram media ─────────────────────────────────────────────────────
  try {
    final response = await api.getInstagramMedia(accountId);
    debugPrint('MEDIA RAW RESPONSE: $response');

    final mediaRoot = response['media'];
    debugPrint('MEDIA ROOT TYPE: ${mediaRoot.runtimeType}');

    final List<dynamic> raw = mediaRoot is Map && mediaRoot['data'] is List
        ? mediaRoot['data'] as List<dynamic>
        : mediaRoot is List
            ? mediaRoot
            : (response['data'] is List
                ? response['data'] as List<dynamic>
                : <dynamic>[]);

    mediaList = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    debugPrint('MEDIA COUNT: ${mediaList.length}');
  } on DioException catch (e) {
    debugPrint('INSIGHTS FAILED URL: ${e.requestOptions.uri}');
    debugPrint('INSIGHTS FAILED METHOD: ${e.requestOptions.method}');
    debugPrint('INSIGHTS FAILED STATUS: ${e.response?.statusCode}');
    debugPrint('INSIGHTS FAILED DATA: ${e.response?.data}');
    // Non-fatal — continue with empty media list
  } catch (e) {
    debugPrint('MEDIA FETCH ERROR: $e');
  }

  return InsightsData(
    rawInsights: rawInsights,
    mediaList: mediaList,
    partialError: partialError,
  );
});
