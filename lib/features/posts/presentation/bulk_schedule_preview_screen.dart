import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/app_settings.dart';
import '../../../models/media_asset.dart';
import '../../../services/bulk_scheduler_service.dart';
import '../../../services/settings_service.dart';

class BulkSchedulePreviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> scheduleSettings;
  const BulkSchedulePreviewScreen({super.key, required this.scheduleSettings});

  @override
  ConsumerState<BulkSchedulePreviewScreen> createState() => _BulkSchedulePreviewScreenState();
}

class _BulkSchedulePreviewScreenState extends ConsumerState<BulkSchedulePreviewScreen> {
  late final AutoDisposeStateNotifierProvider<BulkSchedulerNotifier, AsyncValue<List<BulkScheduleItem>>> _provider;
  bool _isGeneratingCaptions = false;
  bool _isScheduling = false;

  @override
  void initState() {
    super.initState();
    final List<MediaAsset> selectedMedia = widget.scheduleSettings['selectedMedia'];
    _provider = bulkSchedulerProvider(selectedMedia);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(_provider.notifier).distributeTimes(
        startDate: widget.scheduleSettings['startDate'],
        numDays: widget.scheduleSettings['numDays'],
        postsPerDay: widget.scheduleSettings['postsPerDay'],
        startTime: widget.scheduleSettings['startTime'],
        endTime: widget.scheduleSettings['endTime'],
      );
    });
  }

  Future<void> _generateCaptions() async {
    setState(() => _isGeneratingCaptions = true);
    final captionMode = widget.scheduleSettings['captionMode'] as CaptionMode;
    final settings = ref.read(settingsProvider);
    // Passing all required settings to the notifier method
    await ref.read(_provider.notifier).generateAllCaptions(
      captionMode,
      settings,
      widget.scheduleSettings,
    );
    if (mounted) setState(() => _isGeneratingCaptions = false);
  }

  Future<void> _scheduleAll() async {
    setState(() => _isScheduling = true);
    await ref.read(_provider.notifier).scheduleAllPosts();
    if (mounted) setState(() => _isScheduling = false);
    
    // Check for failures before navigating
    final items = ref.read(_provider).value ?? [];
    final failedCount = items.where((i) => i.status == BulkItemStatus.failed).length;
    if(failedCount > 0){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Process completed with $failedCount failures.'), backgroundColor: Colors.orangeAccent));
    } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bulk schedule completed successfully!'), backgroundColor: Colors.green));
        context.go('/posts');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final items = state.value ?? [];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview & Schedule'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/bulk-scheduler');
            }
          },
        ),
        actions: [
          TextButton.icon(
            onPressed: (_isGeneratingCaptions || _isScheduling) ? null : _generateCaptions,
            icon: _isGeneratingCaptions ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator()) : const Icon(Icons.auto_awesome),
            label: const Text('Generate All Captions'),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (items) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return AnimatedBuilder(
              animation: items[index],
              builder: (context, _) => _PostPreviewCard(item: items[index]),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_isGeneratingCaptions || _isScheduling) ? null : _scheduleAll,
        icon: _isScheduling ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check),
        label: Text('Confirm & Schedule All (${items.length})'),
      ),
    );
  }
}

class _PostPreviewCard extends StatelessWidget {
  final BulkScheduleItem item;
  const _PostPreviewCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.media.imageUrl ?? item.media.mediaUrl;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _getCardColor(item.status),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(width: 60, height: 60, child: imageUrl != null ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover) : const Icon(Icons.error)),
                const SizedBox(width: 12),
                Expanded(child: Text('Scheduled for: ${DateFormat.yMd().add_jm().format(item.scheduledAt)}')),
                Chip(label: Text(item.status.name.toUpperCase(), style: const TextStyle(fontSize: 10))),
              ],
            ),
            if (item.status == BulkItemStatus.generating_caption) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
            if (item.errorMessage != null) Text(item.errorMessage!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            TextField(controller: item.captionController, decoration: const InputDecoration(labelText: 'Caption'), maxLines: 3),
            const SizedBox(height: 8),
            TextField(controller: item.hashtagsController, decoration: const InputDecoration(labelText: 'Hashtags')),
          ],
        ),
      ),
    );
  }

  Color? _getCardColor(BulkItemStatus status) {
    switch (status) {
      case BulkItemStatus.scheduled: return AppTheme.primaryGold.withOpacity(0.1);
      case BulkItemStatus.failed: return Colors.red.withOpacity(0.1);
      default: return null;
    }
  }
}
