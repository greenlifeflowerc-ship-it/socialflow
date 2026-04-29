import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/media_asset.dart';
import '../../../services/media_service.dart';
import '../../../services/post_service.dart';
import '../../../services/upload_service.dart';
import '../../../services/settings_service.dart';

// State for selection mode
final selectionProvider = StateNotifierProvider<SelectionNotifier, Set<String>>((ref) => SelectionNotifier());

class SelectionNotifier extends StateNotifier<Set<String>> {
  SelectionNotifier() : super({});
  void toggle(String assetId) {
    if (state.contains(assetId)) {
      state = state.difference({assetId});
    } else {
      state = {...state, assetId};
    }
  }
  void selectAll(List<String> ids) => state = ids.toSet();
  void clear() => state = {};
}

class MediaLibraryScreen extends ConsumerWidget {
  const MediaLibraryScreen({super.key});

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    final List<XFile> files = await ImagePicker().pickMultiImage();
    if (files.isEmpty) return;
    
    ref.read(uploadQueueProvider.notifier).addFilesToQueue(files);
    context.go('/upload-queue');
  }

  void _deleteSelected(BuildContext context, WidgetRef ref, String lang) {
    final selectedIds = ref.read(selectionProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.tr('deleteMediaTitle', lang)),
        content: Text(S.tr('deleteMediaMsg', lang)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(S.tr('cancel', lang))),
          TextButton(
            onPressed: () {
              for (final id in selectedIds) {
                ref.read(mediaProvider.notifier).deleteMedia(id);
              }
              ref.read(selectionProvider.notifier).clear();
              Navigator.of(context).pop();
            },
            child: Text(S.tr('delete', lang), style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaAssets = ref.watch(mediaProvider);
    final selection = ref.watch(selectionProvider);
    final isSelectionMode = selection.isNotEmpty;
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 180).floor().clamp(2, 6);

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelectionMode ? '${selection.length} ${S.tr('selected', lang)}' : S.tr('mediaLibrary', lang)),
        leading: isSelectionMode 
          ? IconButton(icon: const Icon(Icons.close), onPressed: () => ref.read(selectionProvider.notifier).clear()) 
          : null,
        actions: [
          if (!isSelectionMode && mediaAssets.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () => ref.read(selectionProvider.notifier).selectAll(mediaAssets.map((a) => a.id).toList()),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(mediaProvider.notifier).refresh(),
          ),
          if (isSelectionMode)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteSelected(context, ref, lang)),
        ],
      ),
      body: mediaAssets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _pickAndUpload(context, ref),
                    icon: const Icon(Icons.add),
                    label: Text(S.tr('uploadFirstMedia', lang)),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount, 
                crossAxisSpacing: 8, 
                mainAxisSpacing: 8,
              ),
              itemCount: mediaAssets.length,
              itemBuilder: (context, index) => _MediaCard(asset: mediaAssets[index], lang: lang),
            ),
      floatingActionButton: isSelectionMode
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  onPressed: () {
                    final selectedAssets = mediaAssets.where((a) => selection.contains(a.id)).toList();
                    context.push('/ai/bulk-edit', extra: selectedAssets);
                  },
                  label: Text(S.tr('bulkAi', lang)),
                  icon: const Icon(Icons.auto_awesome),
                  heroTag: 'bulk_ai',
                ),
                const SizedBox(width: 8),
                FloatingActionButton.extended(
                  onPressed: () => context.go('/bulk-scheduler'),
                  label: Text('${S.tr('scheduled', lang)} (${selection.length})'),
                  icon: const Icon(Icons.schedule),
                  heroTag: 'bulk_schedule',
                ),
              ],
            )
          : FloatingActionButton.extended(
              onPressed: () => _pickAndUpload(context, ref),
              label: Text(S.tr('upload', lang)),
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
    );
  }
}

class _MediaCard extends ConsumerWidget {
  final MediaAsset asset;
  final String lang;
  const _MediaCard({required this.asset, required this.lang});

  Future<void> _publishNow(BuildContext context, WidgetRef ref) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final caption = asset.caption ?? '';
      final hashtags = (asset.hashtags ?? []).join(' ');
      final finalCaption = '$caption\n\n$hashtags'.trim();

      if (finalCaption.isEmpty) {
        final result = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(S.tr('noCaption', lang)),
            content: Text(S.tr('whatToDo', lang)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, 'cancel'), child: Text(S.tr('cancel', lang))),
              TextButton(onPressed: () => Navigator.pop(context, 'publish'), child: Text(S.tr('publishAnyway', lang))),
              TextButton(onPressed: () => Navigator.pop(context, 'generate'), child: Text(S.tr('generateCaption', lang))),
            ],
          ),
        );

        if (result == 'cancel' || result == null) return;
        if (result == 'generate') {
          context.push('/post-editor', extra: asset);
          return;
        }
      }

      await ref.read(postServiceProvider).publishNow({
        "mediaAssetId": asset.id,
        "mediaUrl": asset.mediaUrl,
        "imageUrl": asset.imageUrl,
        "videoUrl": asset.videoUrl,
        "mediaType": asset.mediaType.name,
        "caption": finalCaption,
      });

      asset.isPublished = true;
      await ref.read(mediaProvider.notifier).updateMedia(asset);
      scaffoldMessenger.showSnackBar(SnackBar(content: Text(S.tr('publishedSuccess', lang))));
    } catch (e) {
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
    }
  }

  void _showMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.send),
              title: Text(S.tr('publishNow', lang)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _publishNow(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(S.tr('generateCaption', lang)),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.push('/post-editor', extra: asset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(S.tr('aiEdit', lang)),
              onTap: () {
                Navigator.pop(sheetCtx);
                context.push('/ai/single-edit', extra: asset);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(S.tr('delete', lang), style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(S.tr('deleteMediaTitle', lang)),
                    content: Text(S.tr('deleteMediaMsg', lang)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.tr('cancel', lang))),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref.read(mediaProvider.notifier).deleteMedia(asset.id);
                        },
                        child: Text(S.tr('delete', lang), style: const TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(selectionProvider);
    final isSelected = selection.contains(asset.id);
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return GestureDetector(
      onTap: () {
        if (selection.isNotEmpty) {
          ref.read(selectionProvider.notifier).toggle(asset.id);
        } else {
          _showMenu(context, ref);
        }
      },
      onLongPress: () => ref.read(selectionProvider.notifier).toggle(asset.id),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? primaryColor : Colors.transparent, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: asset.imageUrl ?? asset.mediaUrl ?? '',
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (c, u, e) => Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
              if (isSelected)
                Container(
                  color: primaryColor.withOpacity(0.4),
                  child: const Icon(Icons.check_circle, color: Colors.white, size: 32),
                ),
              Positioned(
                top: 4, right: 4,
                child: asset.isPublished 
                  ? Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    )
                  : const SizedBox.shrink(),
              ),
              if (asset.mediaType == MediaType.video)
                const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 32)),
            ],
          ),
        ),
      ),
    );
  }
}
