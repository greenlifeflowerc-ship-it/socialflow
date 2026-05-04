import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/media_asset.dart';
import '../../../services/api_client.dart';
import '../../../services/settings_service.dart';
import '../../../services/media_service.dart';

// ── Per-item generation state ──────────────────────────────────────────────
enum _ItemStatus { pending, loading, done, error }

class _BulkItem {
  final MediaAsset asset;
  _ItemStatus status;
  String resultImageUrl;
  String errorMessage;

  _BulkItem({
    required this.asset,
    this.status = _ItemStatus.pending,
    this.resultImageUrl = '',
    this.errorMessage = '',
  });
}

enum _Phase { selecting, generating, done }

// ── Screen ─────────────────────────────────────────────────────────────────
class BulkEditScreen extends ConsumerStatefulWidget {
  final List<MediaAsset> assets;
  const BulkEditScreen({super.key, required this.assets});

  @override
  ConsumerState<BulkEditScreen> createState() => _BulkEditScreenState();
}

class _BulkEditScreenState extends ConsumerState<BulkEditScreen> {
  _Phase _phase = _Phase.selecting;
  final Set<String> _selectedIds = {};
  List<_BulkItem> _items = [];
  final TextEditingController _promptController = TextEditingController();

  String _style = 'premium';
  String _aspectRatio = 'Original';

  final _styles = ['premium', 'luxury', 'minimal', 'bold', 'natural', 'dramatic'];
  final _aspectRatios = ['Original', '1:1', '4:5', '9:16', '16:9'];

  @override
  void initState() {
    super.initState();
    // Pre-select any assets passed via navigation
    for (final a in widget.assets) {
      _selectedIds.add(a.id);
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Merge navigation-passed assets with the library (library first, then
  /// any navigation assets that are not already present in the library).
  List<MediaAsset> _displayAssets(List<MediaAsset> library) {
    final libIds = library.map((a) => a.id).toSet();
    return [
      ...library,
      ...widget.assets.where((a) => !libIds.contains(a.id)),
    ];
  }

  String _buildEditPrompt() {
    final custom = _promptController.text.trim();
    if (custom.isNotEmpty) return custom;
    final settings = ref.read(settingsProvider);
    final profile = settings.brandProfile;
    final biz = profile.isConfigured && profile.businessName.isNotEmpty
        ? 'for ${profile.businessName}'
        : '';
    return 'Edit this product image in a $_style visual style $biz. '
        'Enhance the lighting, composition, and color quality. '
        'Make it professional and suitable for Instagram marketing. '
        'Preserve the main product / subject.';
  }

  // ── Generation ────────────────────────────────────────────────────────────

  Future<void> _startGeneration(List<MediaAsset> displayAssets) async {
    final settings = ref.read(settingsProvider);
    final selected =
        displayAssets.where((a) => _selectedIds.contains(a.id)).toList();

    if (selected.isEmpty) {
      _showSnack('Please select at least one image.', isError: true);
      return;
    }

    final model = settings.selectedImageModel ?? settings.selectedTextModel;
    if (model == null) {
      _showSnack(
        'No AI model selected. Go to Settings → Configurations.',
        isError: true,
      );
      return;
    }

    final items = selected.map((a) => _BulkItem(asset: a)).toList();
    setState(() {
      _items = items;
      _phase = _Phase.generating;
    });

    final provider = settings.selectedAiProvider;

    for (final item in _items) {
      if (!mounted) break;
      setState(() {
        item.status = _ItemStatus.loading;
        item.errorMessage = '';
      });

      try {
        final imageUrl = item.asset.imageUrl ?? item.asset.mediaUrl ?? '';
        final response = await ref.read(apiClientProvider).editImage({
          'originalImageUrl': imageUrl,
          'mediaAssetId': item.asset.id,
          'prompt': _buildEditPrompt(),
          'provider': provider,
          'model': model,
          'aspectRatio': _aspectRatio,
          'resolution': 'Auto',
          'preserveProduct': true,
          'saveToLibrary': true,
        });

        if (response['ok'] == true) {
          final url =
              (response['result']?['imageUrl'] as String?) ??
              (response['imageUrl'] as String?) ??
              '';
          setState(() {
            item.resultImageUrl = url;
            item.status = _ItemStatus.done;
          });
        } else {
          setState(() {
            item.errorMessage =
                response['error']?.toString() ?? 'Generation failed';
            item.status = _ItemStatus.error;
          });
        }
      } catch (e) {
        setState(() {
          item.errorMessage = e.toString().replaceFirst('Exception: ', '');
          item.status = _ItemStatus.error;
        });
      }
    }

    if (!mounted) return;
    setState(() => _phase = _Phase.done);

    // Refresh library so new AI-generated images appear for this user
    await ref.read(mediaProvider.notifier).refresh();

    if (!mounted) return;
    final doneCount = _items.where((i) => i.status == _ItemStatus.done).length;
    final errCount = _items.where((i) => i.status == _ItemStatus.error).length;
    _showSnack(
      doneCount > 0
          ? 'Done! $doneCount edited image${doneCount > 1 ? 's' : ''} saved to your library.'
          : 'Generation failed for all items.',
      isError: errCount == _items.length,
    );
  }

  Future<void> _retryItem(_BulkItem item) async {
    final settings = ref.read(settingsProvider);
    final model = settings.selectedImageModel ?? settings.selectedTextModel;
    if (model == null) {
      _showSnack('No AI model selected.', isError: true);
      return;
    }

    setState(() {
      item.status = _ItemStatus.loading;
      item.errorMessage = '';
    });

    try {
      final imageUrl = item.asset.imageUrl ?? item.asset.mediaUrl ?? '';
      final response = await ref.read(apiClientProvider).editImage({
        'originalImageUrl': imageUrl,
        'mediaAssetId': item.asset.id,
        'prompt': _buildEditPrompt(),
        'provider': settings.selectedAiProvider,
        'model': model,
        'aspectRatio': _aspectRatio,
        'resolution': 'Auto',
        'preserveProduct': true,
        'saveToLibrary': true,
      });

      if (response['ok'] == true) {
        final url =
            (response['result']?['imageUrl'] as String?) ??
            (response['imageUrl'] as String?) ??
            '';
        setState(() {
          item.resultImageUrl = url;
          item.status = _ItemStatus.done;
        });
        await ref.read(mediaProvider.notifier).refresh();
      } else {
        setState(() {
          item.errorMessage =
              response['error']?.toString() ?? 'Generation failed';
          item.status = _ItemStatus.error;
        });
      }
    } catch (e) {
      setState(() {
        item.errorMessage = e.toString().replaceFirst('Exception: ', '');
        item.status = _ItemStatus.error;
      });
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final library = ref.watch(mediaProvider);
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;
    final displayAssets = _displayAssets(library);
    final noModel =
        settings.selectedImageModel == null &&
        settings.selectedTextModel == null;

    final doneCount = _items.where((i) => i.status == _ItemStatus.done).length;
    final runningIdx = _items.indexWhere((i) => i.status == _ItemStatus.loading);

    return Scaffold(
      appBar: AppBar(
        title: Text(S.tr('bulkImageEditor', lang)),
        actions: [
          if (_phase == _Phase.selecting && _selectedIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${_selectedIds.length} ${S.tr('selected2', lang)}',
                  style: TextStyle(
                    color: gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          if (_phase == _Phase.generating || _phase == _Phase.done)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '$doneCount/${_items.length}',
                  style: TextStyle(
                    color: gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (noModel) _NoModelBanner(gold: gold),
          Expanded(
            child: _phase == _Phase.selecting
                ? _buildSelectionPhase(context, gold, displayAssets, lang)
                : _buildGenerationPhase(context, gold),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(
        context,
        gold,
        displayAssets,
        doneCount,
        runningIdx,
        lang,
      ),
    );
  }

  // ── Selection phase ───────────────────────────────────────────────────────

  Widget _buildSelectionPhase(
    BuildContext context,
    Color gold,
    List<MediaAsset> displayAssets,
    String lang,
  ) {
    return Column(
      children: [
        _OptionsBar(
          style: _style,
          aspectRatio: _aspectRatio,
          styles: _styles,
          aspectRatios: _aspectRatios,
          gold: gold,
          onStyleChanged: (v) => setState(() => _style = v),
          onAspectRatioChanged: (v) => setState(() => _aspectRatio = v),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _promptController,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              labelText: S.tr('editPromptOptional', lang),
              labelStyle: TextStyle(
                color: gold.withValues(alpha: 0.7),
                fontSize: 12,
              ),
              hintText: S.tr('leaveEmptyForStyle', lang),
              hintStyle: const TextStyle(fontSize: 11, color: Colors.white30),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: gold.withValues(alpha: 0.25)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: gold.withValues(alpha: 0.2)),
              ),
            ),
            maxLines: 2,
          ),
        ),

        if (displayAssets.isEmpty)
          Expanded(child: _EmptyLibraryState(gold: gold))
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                  Text(
                  S.tr('yourLibrary', lang),
                  style: TextStyle(
                    color: gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${displayAssets.length})',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const Spacer(),
                if (_selectedIds.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _selectedIds.clear()),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        color: gold.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ),
                if (_selectedIds.length < displayAssets.length)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _selectedIds.clear();
                        for (final a in displayAssets) {
                          _selectedIds.add(a.id);
                        }
                      }),
                      child: Text(
                        'Select All',
                        style: TextStyle(
                          color: gold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 5,
                mainAxisSpacing: 5,
              ),
              itemCount: displayAssets.length,
              itemBuilder: (context, index) {
                final asset = displayAssets[index];
                final isSelected = _selectedIds.contains(asset.id);
                return _SelectableAssetTile(
                  asset: asset,
                  isSelected: isSelected,
                  gold: gold,
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selectedIds.remove(asset.id);
                    } else {
                      _selectedIds.add(asset.id);
                    }
                  }),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // ── Generation phase ──────────────────────────────────────────────────────

  Widget _buildGenerationPhase(BuildContext context, Color gold) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _BulkItemCard(
          item: item,
          gold: gold,
          onRetry: () => _retryItem(item),
        );
      },
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────

  Widget _buildBottomBar(
    BuildContext context,
    Color gold,
    List<MediaAsset> displayAssets,
    int doneCount,
    int runningIdx,
    String lang,
  ) {
    switch (_phase) {
      case _Phase.selecting:
        final count = _selectedIds.length;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    count == 0 ? null : () => _startGeneration(displayAssets),
                icon: const Icon(Icons.auto_awesome),
                label: Text(
                  count == 0
                      ? S.tr('selectImageFromLibrary', lang)
                      : '${S.tr('generatePictures', lang)} ($count)',
                ),
              ),
            ),
          ),
        );

      case _Phase.generating:
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: null,
                icon: const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                ),
                label: Text(
                  '${S.tr('statusPublishing', lang)} ${runningIdx >= 0 ? "${runningIdx + 1}/${_items.length}" : "…"}',
                ),
              ),
            ),
          ),
        );

      case _Phase.done:
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _phase = _Phase.selecting;
                      _items = [];
                      _selectedIds.clear();
                    }),
                    icon: const Icon(Icons.refresh),
                    label: Text(S.tr('retry', lang)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: gold,
                      side: BorderSide(color: gold.withValues(alpha: 0.4)),
                      minimumSize: const Size(0, 52),
                    ),
                  ),
                ),
                if (doneCount > 0) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/media'),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(S.tr('mediaLibrary', lang)),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
    }
  }
}

// ── Selectable asset tile ──────────────────────────────────────────────────

class _SelectableAssetTile extends StatelessWidget {
  final MediaAsset asset;
  final bool isSelected;
  final Color gold;
  final VoidCallback onTap;

  const _SelectableAssetTile({
    required this.asset,
    required this.isSelected,
    required this.gold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = asset.imageUrl ?? asset.mediaUrl ?? '';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? gold : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: Colors.white10),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.white10,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white30,
                          size: 20,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.white10,
                      child: const Icon(
                        Icons.image_outlined,
                        color: Colors.white30,
                        size: 24,
                      ),
                    ),
              if (isSelected)
                Container(
                  color: gold.withValues(alpha: 0.30),
                  child: const Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: EdgeInsets.all(3),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────

class _NoModelBanner extends StatelessWidget {
  final Color gold;
  const _NoModelBanner({required this.gold});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/settings'),
      child: Container(
        width: double.infinity,
        color: Colors.orange.withValues(alpha: 0.1),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No AI model selected. Tap here → Settings → Configurations → Refresh Models.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.orange, size: 11),
          ],
        ),
      ),
    );
  }
}

class _OptionsBar extends StatelessWidget {
  final String style;
  final String aspectRatio;
  final List<String> styles;
  final List<String> aspectRatios;
  final Color gold;
  final ValueChanged<String> onStyleChanged;
  final ValueChanged<String> onAspectRatioChanged;

  const _OptionsBar({
    required this.style,
    required this.aspectRatio,
    required this.styles,
    required this.aspectRatios,
    required this.gold,
    required this.onStyleChanged,
    required this.onAspectRatioChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: gold.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _DropChip(
              label: 'Style',
              value: style,
              items: styles,
              gold: gold,
              onChanged: onStyleChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DropChip(
              label: 'Aspect Ratio',
              value: aspectRatio,
              items: aspectRatios,
              gold: gold,
              onChanged: onAspectRatioChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _DropChip extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final Color gold;
  final ValueChanged<String> onChanged;

  const _DropChip({
    required this.label,
    required this.value,
    required this.items,
    required this.gold,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: gold.withValues(alpha: 0.7), fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.2)),
        ),
      ),
      items: items
          .map(
            (s) => DropdownMenuItem(
              value: s,
              child: Text(s, style: const TextStyle(fontSize: 12)),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      style: const TextStyle(color: Colors.white, fontSize: 12),
      dropdownColor: const Color(0xFF1E1E2E),
      isExpanded: true,
    );
  }
}

class _EmptyLibraryState extends StatelessWidget {
  final Color gold;
  const _EmptyLibraryState({required this.gold});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: gold.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            const Text(
              'No images in your library yet',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload images first, then come back\nto generate edited versions.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/media'),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Go to Media'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulkItemCard extends StatelessWidget {
  final _BulkItem item;
  final Color gold;
  final VoidCallback onRetry;

  const _BulkItemCard({
    required this.item,
    required this.gold,
    required this.onRetry,
  });

  Color _borderColor(Color gold) => switch (item.status) {
    _ItemStatus.loading => gold,
    _ItemStatus.done => Colors.green.withValues(alpha: 0.35),
    _ItemStatus.error => Colors.redAccent.withValues(alpha: 0.35),
    _ItemStatus.pending => Colors.white.withValues(alpha: 0.06),
  };

  @override
  Widget build(BuildContext context) {
    final originalUrl = item.asset.imageUrl ?? item.asset.mediaUrl;
    final resultUrl = item.resultImageUrl.isNotEmpty ? item.resultImageUrl : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _borderColor(gold),
          width: item.status == _ItemStatus.loading ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Before → After
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(13),
                      ),
                      child: SizedBox(
                        height: 90,
                        child: _buildImage(originalUrl),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Original',
                        style: TextStyle(color: Colors.white38, fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: gold.withValues(alpha: 0.4),
                  size: 16,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(13),
                      ),
                      child: SizedBox(
                        height: 90,
                        child: switch (item.status) {
                          _ItemStatus.loading => Container(
                            color: Colors.white10,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: gold,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          _ItemStatus.done => _buildImage(resultUrl),
                          _ItemStatus.error => Container(
                            color: Colors.redAccent.withValues(alpha: 0.08),
                            child: const Center(
                              child: Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                                size: 24,
                              ),
                            ),
                          ),
                          _ItemStatus.pending => Container(
                            color: Colors.white10,
                            child: const Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: Colors.white24,
                                size: 24,
                              ),
                            ),
                          ),
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Generated',
                        style: TextStyle(color: Colors.white38, fontSize: 9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Status + retry
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
            child: Row(
              children: [
                _StatusChip(status: item.status, gold: gold),
                const Spacer(),
                if (item.status == _ItemStatus.error)
                  GestureDetector(
                    onTap: onRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh, size: 11, color: Colors.redAccent),
                          SizedBox(width: 4),
                          Text(
                            'Retry',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (item.status == _ItemStatus.error && item.errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Text(
                item.errorMessage,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(String? url) {
    if (url == null || url.isEmpty) {
      return Container(
        color: Colors.white10,
        child: const Icon(Icons.image_outlined, color: Colors.white30, size: 20),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: Colors.white10),
      errorWidget: (_, __, ___) => Container(
        color: Colors.white10,
        child: const Icon(
          Icons.broken_image_outlined,
          color: Colors.white30,
          size: 20,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final _ItemStatus status;
  final Color gold;
  const _StatusChip({required this.status, required this.gold});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      _ItemStatus.pending => ('Pending', Colors.white38),
      _ItemStatus.loading => ('Generating…', gold),
      _ItemStatus.done => ('Saved ✓', Colors.greenAccent),
      _ItemStatus.error => ('Failed', Colors.redAccent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
