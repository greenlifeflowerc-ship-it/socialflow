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

  void distributeTimes({required DateTime startDate, required int numDays, required int postsPerDay, required TimeOfDay startTime, required TimeOfDay endTime}) { /* ... */ }
  
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

  Future<void> scheduleAllPosts() async {
    await runWithConcurrency(
      items: state.value!,
      concurrency: 3,
      task: (item, index) => _scheduleItem(item),
    );
  }

  Future<void> _scheduleItem(BulkScheduleItem item) async {
    if (item.media.mediaUrl == null) {
      item.updateStatus(BulkItemStatus.failed, error: "Media URL is missing.");
      return;
    }
    item.updateStatus(BulkItemStatus.scheduling);
    try {
      final post = await _apiClient.createScheduledPost(
        mediaAssetId: item.media.id, mediaUrl: item.media.mediaUrl!, imageUrl: item.media.imageUrl,
        videoUrl: item.media.videoUrl, mediaType: item.media.mediaType.name,
        caption: item.captionController.text, hashtags: item.hashtagsController.text.split(' ').toList(),
        scheduledAt: item.scheduledAt,
      );
      item.postId = post['id'];
      item.updateStatus(BulkItemStatus.scheduled);
    } catch (e) {
      item.updateStatus(BulkItemStatus.failed, error: e.toString());
    }
  }
}

final bulkSchedulerProvider = StateNotifierProvider.autoDispose.family<BulkSchedulerNotifier, AsyncValue<List<BulkScheduleItem>>, List<MediaAsset>>(
  (ref, selectedMedia) => BulkSchedulerNotifier(ref.watch(apiClientProvider), selectedMedia)
);
