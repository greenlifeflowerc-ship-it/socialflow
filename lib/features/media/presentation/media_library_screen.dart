import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/media_asset.dart';
import '../../../services/accounts_service.dart';
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

class MediaLibraryScreen extends ConsumerStatefulWidget {
  const MediaLibraryScreen({super.key});

  @override
  ConsumerState<MediaLibraryScreen> createState() => _MediaLibraryScreenState();
}

class _MediaLibraryScreenState extends ConsumerState<MediaLibraryScreen> {
  Future<void> _pickAndUpload(BuildContext context) async {
    final List<XFile> files = await ImagePicker().pickMultiImage();
    if (files.isEmpty) return;
    ref.read(uploadQueueProvider.notifier).addFilesToQueue(files);
    if (mounted) context.go('/upload-queue');
  }

  Future<void> _deleteSelected(BuildContext context, String lang) async {
    final selectedIds = ref.read(selectionProvider);
    if (selectedIds.isEmpty) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(S.tr('deleteMediaTitle', lang)),
            content: Text(S.tr('deleteMediaMsg', lang)),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.of(ctx).pop(),
                child: Text(S.tr('cancel', lang)),
              ),
              TextButton(
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() => isDeleting = true);
                        final navigator = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        int successCount = 0;
                        String? lastError;
                        for (final id in List<String>.from(selectedIds)) {
                          try {
                            await ref.read(mediaProvider.notifier).deleteMedia(id);
                            successCount++;
                          } catch (e) {
                            lastError = e.toString().replaceFirst('Exception: ', '');
                          }
                        }
                        ref.read(selectionProvider.notifier).clear();
                        navigator.pop();
                        // Refresh from backend once after all deletions.
                        ref.read(mediaProvider.notifier).refresh();
                        if (successCount > 0) {
                          messenger.showSnackBar(SnackBar(
                            content: Text(S.tr('mediaDeleted', lang)),
                            backgroundColor: Colors.green.shade700,
                          ));
                        }
                        if (lastError != null) {
                          messenger.showSnackBar(SnackBar(
                            content: Text(lastError!),
                            backgroundColor: Colors.redAccent,
                          ));
                        }
                      },
                child: isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(S.tr('delete', lang),
                        style: const TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaAssets = ref.watch(mediaProvider);
    final selection = ref.watch(selectionProvider);
    final isSelectionMode = selection.isNotEmpty;
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = (screenWidth / 180).floor().clamp(2, 6);

    return Scaffold(
      appBar: AppBar(
        title: Text(isSelectionMode
            ? '${selection.length} ${S.tr('selected', lang)}'
            : S.tr('mediaLibrary', lang)),
        leading: isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => ref.read(selectionProvider.notifier).clear())
            : null,
        actions: [
          if (!isSelectionMode && mediaAssets.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () => ref
                  .read(selectionProvider.notifier)
                  .selectAll(mediaAssets.map((a) => a.id).toList()),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(mediaProvider.notifier).refresh(),
          ),
          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteSelected(context, lang),
            ),
        ],
      ),
      body: mediaAssets.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 80,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.2)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _pickAndUpload(context),
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
              itemBuilder: (context, index) =>
                  _MediaCard(asset: mediaAssets[index], lang: lang),
            ),
      floatingActionButton: isSelectionMode
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  onPressed: () {
                    final selectedAssets = mediaAssets
                        .where((a) => selection.contains(a.id))
                        .toList();
                    context.push('/ai/bulk-edit', extra: selectedAssets);
                  },
                  label: Text(S.tr('bulkAi', lang)),
                  icon: const Icon(Icons.auto_awesome),
                  heroTag: 'bulk_ai',
                ),
                const SizedBox(width: 8),
                FloatingActionButton.extended(
                  onPressed: () => context.go('/bulk-scheduler'),
                  label: Text(
                      '${S.tr('scheduled', lang)} (${selection.length})'),
                  icon: const Icon(Icons.schedule),
                  heroTag: 'bulk_schedule',
                ),
              ],
            )
          : FloatingActionButton.extended(
              onPressed: () => _pickAndUpload(context),
              label: Text(S.tr('upload', lang)),
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
    );
  }
}

class _MediaCard extends ConsumerStatefulWidget {
  final MediaAsset asset;
  final String lang;
  const _MediaCard({required this.asset, required this.lang});

  @override
  ConsumerState<_MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends ConsumerState<_MediaCard> {
  bool _publishing = false;

  MediaAsset get asset => widget.asset;
  String get lang => widget.lang;

  Future<void> _publishNow(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final currentLang = ref.read(settingsProvider).language;

    // Validate the media asset id is a real backend id, not a local placeholder.
    if (asset.id.startsWith('media_')) {
      scaffoldMessenger.showSnackBar(const SnackBar(
        content: Text(
            'Media upload not complete yet. Please wait and try again.'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    // Build caption + hashtags.
    final caption = asset.caption ?? '';
    final hashtags = (asset.hashtags ?? []).join(' ');
    final finalCaption = '$caption\n\n$hashtags'.trim();

    if (finalCaption.isEmpty) {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(S.tr('noCaption', currentLang)),
          content: Text(S.tr('whatToDo', currentLang)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: Text(S.tr('cancel', currentLang))),
            TextButton(
                onPressed: () => Navigator.pop(context, 'publish'),
                child: Text(S.tr('publishAnyway', currentLang))),
            TextButton(
                onPressed: () => Navigator.pop(context, 'generate'),
                child: Text(S.tr('generateCaption', currentLang))),
          ],
        ),
      );

      if (result == 'cancel' || result == null) return;
      if (result == 'generate') {
        if (mounted) context.push('/post-editor', extra: asset);
        return;
      }
    }

    // Fetch the connected social account.
    String socialAccountId;
    try {
      final accounts = await ref.read(socialAccountsProvider.future);
      if (accounts.isEmpty) {
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(const SnackBar(
          content: Text(
              'No connected Instagram account found. Please connect an account first.'),
          backgroundColor: Colors.redAccent,
        ));
        return;
      }
      socialAccountId = accounts.first.id;
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text(
            'Failed to load account: ${e.toString().replaceFirst('Exception: ', '')}'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    if (socialAccountId.isEmpty) {
      scaffoldMessenger.showSnackBar(const SnackBar(
        content: Text(
            'Social account ID is missing. Please reconnect your account.'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    if (!mounted) return;
    setState(() => _publishing = true);

    try {
      final body = {
        'social_account_id': socialAccountId,
        'media_asset_id': asset.id,
        'caption': finalCaption.isEmpty ? '' : finalCaption,
        'media_type': asset.mediaType.name, // 'image' or 'video'
      };

      debugPrint('PUBLISH NOW PAYLOAD: $body');

      await ref.read(postServiceProvider).publishNow(body);

      asset.isPublished = true;
      await ref.read(mediaProvider.notifier).updateMedia(asset);

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text(S.tr('publishedSuccess', currentLang)),
        backgroundColor: Colors.green.shade700,
      ));
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: Colors.redAccent,
      ));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  /// Shows the confirmation dialog and, on confirm, calls DELETE /api/media/:id.
  /// Disables the Delete button while loading, shows snackbar on result.
  void _confirmAndDelete(BuildContext context) {
    // Guard: do not attempt to delete assets with local placeholder IDs.
    if (asset.id.startsWith('media_')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Upload not complete. Please wait and try again.'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        bool isDeleting = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(S.tr('deleteMediaTitle', lang)),
            content: Text(S.tr('deleteMediaMsg', lang)),
            actions: [
              TextButton(
                onPressed:
                    isDeleting ? null : () => Navigator.of(ctx).pop(),
                child: Text(S.tr('cancel', lang)),
              ),
              TextButton(
                onPressed: isDeleting
                    ? null
                    : () async {
                        setDialogState(() => isDeleting = true);
                        // Capture before async gap to avoid stale context.
                        final navigator = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref
                              .read(mediaProvider.notifier)
                              .deleteMedia(asset.id);
                          // Refresh library from backend (linked_posts_untouched is ignored).
                          ref.read(mediaProvider.notifier).refresh();
                          navigator.pop();
                          messenger.showSnackBar(SnackBar(
                            content: Text(S.tr('mediaDeleted', lang)),
                            backgroundColor: Colors.green.shade700,
                          ));
                        } catch (e) {
                          if (!ctx.mounted) return;
                          setDialogState(() => isDeleting = false);
                          navigator.pop();
                          messenger.showSnackBar(SnackBar(
                            content: Text(e
                                .toString()
                                .replaceFirst('Exception: ', '')),
                            backgroundColor: Colors.redAccent,
                          ));
                        }
                      },
                child: isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(S.tr('delete', lang),
                        style:
                            const TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: _publishing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              title: Text(S.tr('publishNow', lang)),
              enabled: !_publishing,
              onTap: _publishing
                  ? null
                  : () {
                      Navigator.pop(sheetCtx);
                      _publishNow(context);
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
              title: Text(S.tr('delete', lang),
                  style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetCtx);
                _confirmAndDelete(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(selectionProvider);
    final isSelected = selection.contains(asset.id);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        if (selection.isNotEmpty) {
          ref.read(selectionProvider.notifier).toggle(asset.id);
        } else {
          _showMenu(context);
        }
      },
      onLongPress: () => ref.read(selectionProvider.notifier).toggle(asset.id),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? primaryColor : Colors.transparent,
              width: 2),
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
                  child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (c, u, e) => Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
              if (isSelected)
                Container(
                  color: primaryColor.withOpacity(0.4),
                  child: const Icon(Icons.check_circle,
                      color: Colors.white, size: 32),
                ),
              if (_publishing)
                Container(
                  color: Colors.black45,
                  child: const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: asset.isPublished
                    ? Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.check_circle,
                            color: Colors.green, size: 16),
                      )
                    : const SizedBox.shrink(),
              ),
              if (asset.mediaType == MediaType.video)
                const Center(
                    child: Icon(Icons.play_circle_outline,
                        color: Colors.white, size: 32)),
            ],
          ),
        ),
      ),
    );
  }
}
