import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../models/media_asset.dart';
import 'api_client.dart';

// Enums and Item Model
enum BulkItemStatus { pending_caption, generating_caption, caption_ready, scheduling, scheduled, failed }
enum CaptionMode { generate_missing, regenerate_all, keep_existing }

class BulkScheduleItem extends ChangeNotifier {
  final MediaAsset media;
  DateTime scheduledAt;
  TextEditingController captionController;
  TextEditingController hashtagsController;
  BulkItemStatus status;
  String? postId;
  String? errorMessage;

  BulkScheduleItem({required this.media, required this.scheduledAt})
      : captionController = TextEditingController(text: media.caption ?? ''),
        hashtagsController = TextEditingController(text: (media.hashtags ?? []).join(' ')),
        status = (media.caption ?? '').isEmpty ? BulkItemStatus.pending_caption : BulkItemStatus.caption_ready;
  
  void updateStatus(BulkItemStatus newStatus, {String? error}) {
    status = newStatus;
    errorMessage = error;
    notifyListeners();
  }
}

// Concurrency Helper
Future<void> runWithConcurrency<T>({ required List<T> items, required int concurrency, required Future<void> Function(T item, int index) task,}) async {
  if (items.isEmpty) return;
  var nextIndex = 0;
  final safeConcurrency = concurrency.clamp(1, items.length);

  Future<void> worker() async {
    while (true) {
      final currentIndex = nextIndex;
      nextIndex += 1;
      if (currentIndex >= items.length) return;
      await task(items[currentIndex], currentIndex);
    }
  }
  await Future.wait(List.generate(safeConcurrency, (_) => worker()));
}

// State Notifier
class BulkSchedulerNotifier extends StateNotifier<AsyncValue<List<BulkScheduleItem>>> {
  final ApiClient _apiClient;

  BulkSchedulerNotifier(this._apiClient, List<MediaAsset> selectedMedia) 
    : super(const AsyncValue.loading()) {
    state = AsyncValue.data(selectedMedia.map((m) => BulkScheduleItem(media: m, scheduledAt: DateTime.now())).toList());
  }

  void distributeTimes({
    required DateTime startDate,
    required int numDays,
    required int postsPerDay,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) {
    final items = state.value;
    if (items == null || items.isEmpty) return;

    // Build every slot as a LOCAL DateTime — never UTC
    final slots = <DateTime>[];
    for (int day = 0; day < numDays; day++) {
      final date = startDate.add(Duration(days: day));

      if (postsPerDay == 1) {
        // Single post per day → place at startTime
        slots.add(DateTime(
          date.year, date.month, date.day,
          startTime.hour, startTime.minute,
        ));
      } else {
        // Spread evenly between startTime and endTime
        final startMinutes = startTime.hour * 60 + startTime.minute;
        final endMinutes   = endTime.hour   * 60 + endTime.minute;
        final span = (endMinutes - startMinutes).clamp(1, 24 * 60);
        final step = span / (postsPerDay - 1);

        for (int p = 0; p < postsPerDay; p++) {
          final totalMinutes = (startMinutes + step * p).round();
          slots.add(DateTime(
            date.year, date.month, date.day,
            totalMinutes ~/ 60, totalMinutes % 60,
          ));
        }
      }
    }

    // Assign slots to items (cycle if more items than slots)
    for (int i = 0; i < items.length; i++) {
      if (slots.isNotEmpty) {
        items[i].scheduledAt = slots[i % slots.length];
        items[i].notifyListeners();
      }
    }
    state = AsyncValue.data(items);
  }
  
  Future<void> generateAllCaptions(CaptionMode mode, AppSettings settings, Map<String, dynamic> captionSettings) async {
    final itemsToGenerate = state.value!.where((item) => mode == CaptionMode.regenerate_all || (mode == CaptionMode.generate_missing && item.captionController.text.isEmpty)).toList();
    
    await runWithConcurrency(
      items: itemsToGenerate,
      concurrency: 2,
      task: (item, index) => _generateCaptionForItem(item, settings, captionSettings),
    );
  }
  
  Future<void> _generateCaptionForItem(BulkScheduleItem item, AppSettings settings, Map<String, dynamic> captionSettings) async {
    final imageUrl = item.media.imageUrl ?? item.media.mediaUrl;
    if (imageUrl == null || settings.selectedTextModel == null) {
      item.updateStatus(BulkItemStatus.failed, error: "Missing URL or AI model.");
      return;
    }
    item.updateStatus(BulkItemStatus.generating_caption);
    try {
      final result = await _apiClient.generateCaption(
        imageUrl: imageUrl, language: captionSettings['language'], tone: captionSettings['tone'],
        provider: settings.selectedAiProvider, model: settings.selectedTextModel!,
        captionPreset: captionSettings['captionPreset'], cta: captionSettings['cta'],
      );
      item.captionController.text = result['caption'] ?? '';
      item.hashtagsController.text = (result['hashtags'] as List<dynamic>? ?? []).join(' ');
      item.updateStatus(BulkItemStatus.caption_ready);
    } catch (e) {
      item.updateStatus(BulkItemStatus.failed, error: e.toString());
    }
  }

  Future<void> scheduleAllPosts({String socialAccountId = ''}) async {
    await runWithConcurrency(
      items: state.value!,
      concurrency: 3,
      task: (item, index) => _scheduleItem(item, socialAccountId),
    );
  }

  Future<void> _scheduleItem(BulkScheduleItem item, String socialAccountId) async {
    // ── Pre-send validation ────────────────────────────────────────────────
    if (socialAccountId.isEmpty) {
      item.updateStatus(BulkItemStatus.failed,
          error: 'No Instagram account selected. Please go back and choose one.');
      return;
    }
    final mediaAssetId = item.media.id;
    if (mediaAssetId.isEmpty) {
      item.updateStatus(BulkItemStatus.failed,
          error: 'Media asset ID is missing. Re-upload the media and try again.');
      return;
    }
    // Detect local placeholder IDs — means the upload response was not parsed correctly.
    if (mediaAssetId.startsWith('media_')) {
      item.updateStatus(BulkItemStatus.failed,
          error: 'Media was not properly uploaded (got local ID: $mediaAssetId). '
              'Delete and re-upload this item, then try again.');
      return;
    }

    item.updateStatus(BulkItemStatus.scheduling);

    // ── Build local DateTime from stored scheduledAt, then convert to UTC ──
    // scheduledAt is always stored as local time by distributeTimes()
    final scheduledAt    = item.scheduledAt; // local DateTime
    final scheduledAtUtc = scheduledAt.toUtc();

    // ── Minimum 3-minute-ahead validation ─────────────────────────────────
    final nowUtc            = DateTime.now().toUtc();
    final minimumScheduleTime = nowUtc.add(const Duration(minutes: 3));

    debugPrint('NOW LOCAL: ${DateTime.now()}');
    debugPrint('NOW UTC: $nowUtc');
    debugPrint('SELECTED LOCAL SCHEDULE: $scheduledAt');
    debugPrint('SCHEDULED UTC: $scheduledAtUtc');

    if (scheduledAtUtc.isBefore(minimumScheduleTime)) {
      item.updateStatus(BulkItemStatus.failed,
          error: 'Please schedule the post at least 3 minutes from now. '
              'Selected: ${scheduledAt.toLocal()} | Minimum: ${minimumScheduleTime.toLocal()}');
      return;
    }

    // ── Build snake_case payload exactly as the backend expects ────────────
    final body = <String, dynamic>{
      'social_account_id': socialAccountId,
      'media_asset_id': mediaAssetId,
      'caption': item.captionController.text,
      'media_type': item.media.mediaType.name, // 'image' or 'video'
      'scheduled_at': scheduledAtUtc.toIso8601String(),
      'timezone': 'Asia/Dubai',
    };

    debugPrint('SCHEDULE PAYLOAD: $body');

    try {
      final post = await _apiClient.schedulePost(body);
      item.postId = (post['id'] ?? post['post_id'])?.toString();
      item.updateStatus(BulkItemStatus.scheduled);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;

      debugPrint('SCHEDULE FAILED STATUS: $statusCode');
      debugPrint('SCHEDULE FAILED DATA: $data');

      String message = 'Schedule failed';
      if (data is Map && data['error'] != null) {
        message = data['error'].toString();
      } else if (data is Map && data['message'] != null) {
        message = data['message'].toString();
      } else if (e.message != null && e.message!.isNotEmpty) {
        message = e.message!;
      }

      item.updateStatus(BulkItemStatus.failed, error: '[$statusCode] $message');
    } catch (e) {
      item.updateStatus(BulkItemStatus.failed, error: e.toString());
    }
  }
}

final bulkSchedulerProvider = StateNotifierProvider.autoDispose.family<BulkSchedulerNotifier, AsyncValue<List<BulkScheduleItem>>, List<MediaAsset>>(
  (ref, selectedMedia) => BulkSchedulerNotifier(ref.watch(apiClientProvider), selectedMedia)
);
