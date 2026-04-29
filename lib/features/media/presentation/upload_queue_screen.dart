import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/upload_service.dart';

class UploadQueueScreen extends ConsumerWidget {
  const UploadQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(uploadQueueProvider);
    final total = queue.length;
    final uploaded = queue.where((item) => item.status == UploadStatus.uploaded).length;
    final failed = queue.where((item) => item.status == UploadStatus.failed).length;
    final uploading = queue.where((item) => item.status == UploadStatus.uploading).length;
    final pending = queue.where((item) => item.status == UploadStatus.pending).length;
    
    final isFinished = (uploaded + failed == total) && total > 0;

    return Scaffold(
      backgroundColor: AppTheme.surfaceDark,
      appBar: AppBar(
        title: const Text('UPLOAD QUEUE', style: TextStyle(letterSpacing: 1.2)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryGold),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/media');
            }
          },
        ),
        actions: [
          if (!isFinished && total > 0)
            TextButton(
              onPressed: () => ref.read(uploadQueueProvider.notifier).cancelAll(),
              child: const Text('CANCEL ALL', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          if (isFinished && failed > 0)
             IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
              onPressed: () => ref.read(uploadQueueProvider.notifier).retryAllFailed(),
              tooltip: 'Retry All Failed',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryCard(uploaded, failed, pending, uploading, total),
          Expanded(
            child: queue.isEmpty
              ? const Center(child: Text('No files in queue', style: TextStyle(color: AppTheme.textGrey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: queue.length,
                  itemBuilder: (context, index) {
                    final item = queue[index];
                    return AnimatedBuilder(
                      animation: item,
                      builder: (context, _) => _UploadItemTile(item: item),
                    );
                  },
                ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isFinished) ...[
                const Text(
                  'Upload completed. Go to Media Library.',
                  style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(uploadQueueProvider.notifier).clearCompleted();
                      context.go('/media');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('DONE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ] else if (total > 0) ...[
                const LinearProgressIndicator(color: AppTheme.primaryGold, backgroundColor: Colors.white10),
                const SizedBox(height: 8),
                Text('Processing $uploading of $total files...', style: const TextStyle(color: AppTheme.textGrey, fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(int uploaded, int failed, int pending, int uploading, int total) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('TOTAL', total.toString(), Colors.white),
          _summaryItem('UPLOADED', uploaded.toString(), Colors.green),
          _summaryItem('FAILED', failed.toString(), Colors.redAccent),
          _summaryItem('PENDING', (pending + uploading).toString(), AppTheme.primaryGold),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
      ],
    );
  }
}

class _UploadItemTile extends ConsumerWidget {
  final UploadQueueItem item;
  const _UploadItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: Colors.black,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _getStatusColor(item.status).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.image, color: AppTheme.primaryGold, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.file.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildTrailingAction(ref),
              ],
            ),
            if (item.status == UploadStatus.uploading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: item.progress,
                color: AppTheme.primaryGold,
                backgroundColor: Colors.white10,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Attempt ${item.attemptCount}', style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                  Text('${(item.progress * 100).toInt()}%', style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
                ],
              ),
            ],
            if (item.status == UploadStatus.failed) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.errorMessage ?? 'Unknown error',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrailingAction(WidgetRef ref) {
    switch (item.status) {
      case UploadStatus.uploaded:
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case UploadStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.primaryGold, size: 20),
              onPressed: () => ref.read(uploadQueueProvider.notifier).retryFile(item),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              onPressed: () => ref.read(uploadQueueProvider.notifier).removeFile(item),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        );
      case UploadStatus.pending:
        return IconButton(
          icon: const Icon(Icons.close, color: AppTheme.textGrey, size: 20),
          onPressed: () => ref.read(uploadQueueProvider.notifier).removeFile(item),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        );
      case UploadStatus.uploading:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGold),
        );
    }
  }

  Color _getStatusColor(UploadStatus status) {
    switch (status) {
      case UploadStatus.uploaded: return Colors.green;
      case UploadStatus.failed: return Colors.redAccent;
      case UploadStatus.uploading: return AppTheme.primaryGold;
      default: return AppTheme.textGrey;
    }
  }
}
