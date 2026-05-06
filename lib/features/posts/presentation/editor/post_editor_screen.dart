import 'dart:typed_data' show Uint8List;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import '../../../../core/l10n/app_strings.dart';
import '../../../../models/media_asset.dart';
import '../../../../services/ai_service.dart';
import '../../../../services/api_client.dart';
import '../../../../services/media_service.dart';
import '../../../../services/settings_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Publish type enum
// ─────────────────────────────────────────────────────────────────────────────
enum PublishType { feed, reels, story }

extension PublishTypeLabel on PublishType {
  String label(String lang) {
    switch (this) {
      case PublishType.feed:  return S.tr('postTypeFeed', lang);
      case PublishType.reels: return S.tr('postTypeReel', lang);
      case PublishType.story: return S.tr('postTypeStory', lang);
    }
  }
  String get apiValue {
    switch (this) {
      case PublishType.feed:  return 'image';
      case PublishType.reels: return 'reels';
      case PublishType.story: return 'story';
    }
  }
  String get outputType {
    switch (this) {
      case PublishType.story: return 'story';
      default:                return 'reels';
    }
  }
  String get aspectRatio {
    switch (this) {
      case PublishType.story: return '9:16';
      case PublishType.reels: return '9:16';
      case PublishType.feed:  return '1:1';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class PostEditorScreen extends ConsumerStatefulWidget {
  final MediaAsset asset;
  const PostEditorScreen({super.key, required this.asset});

  @override
  ConsumerState<PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends ConsumerState<PostEditorScreen> {
  final _captionController   = TextEditingController();
  final _hashtagsController  = TextEditingController();

  bool _isGeneratingCaption = true;

  // Publish type — used for audio rendering parameters & UI hint
  PublishType _publishType = PublishType.feed;

  // Custom audio
  XFile?  _audioFile;
  String? _audioName;
  bool    _isApplyingMusic = false;

  @override
  void initState() {
    super.initState();
    _publishType = widget.asset.mediaType == MediaType.video
        ? PublishType.reels
        : PublishType.feed;
    _generateCaption();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagsController.dispose();
    super.dispose();
  }

  // ── Caption generation ────────────────────────────────────────────────────

  Future<void> _generateCaption() async {
    setState(() => _isGeneratingCaption = true);
    final imageUrl = widget.asset.imageUrl ?? widget.asset.mediaUrl;

    if (imageUrl == null) {
      _showError('Cannot generate caption — media URL is missing.');
      setState(() => _isGeneratingCaption = false);
      return;
    }

    try {
      final settings = ref.read(settingsProvider);
      if (settings.selectedTextModel == null) {
        _showError('No AI text model selected in settings.');
        setState(() => _isGeneratingCaption = false);
        return;
      }

      final profile = settings.brandProfile;
      Map<String, dynamic> result;

      if (profile.isConfigured) {
        debugPrint('POST EDITOR: generating with brand profile (${profile.businessName})');
        result = await ref.read(aiServiceProvider).generateCaptionWithProfile(
          imageUrl: imageUrl,
          mediaUrl: widget.asset.mediaUrl,
          mediaAssetId: widget.asset.id.startsWith('media_') ? null : widget.asset.id,
          provider: settings.selectedAiProvider,
          model: settings.selectedTextModel!,
          profile: profile,
        );
      } else {
        debugPrint('POST EDITOR: generating without brand profile');
        result = await ref.read(aiServiceProvider).generateCaption(
          imageUrl: imageUrl,
          mediaUrl: widget.asset.mediaUrl,
          provider: settings.selectedAiProvider,
          model: settings.selectedTextModel!,
          language: settings.language == 'ar' ? 'Arabic' : 'English',
          tone: 'professional',
        );
      }

      _captionController.text  = result['caption'] as String? ?? '';
      _hashtagsController.text = (result['hashtags'] as List? ?? []).join(' ');
    } on DioException catch (e) {
      debugPrint('POST EDITOR CAPTION ERROR: ${e.response?.data}');
      final data = e.response?.data;
      final msg = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'AI caption generation failed. Please try again.';
      _showError(msg);
    } catch (e) {
      debugPrint('POST EDITOR CAPTION EXCEPTION: $e');
      _showError('AI generation failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isGeneratingCaption = false);
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );

  // ── Audio picker ──────────────────────────────────────────────────────────

  Future<void> _pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'wav', 'aac'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      final xFile = (kIsWeb || f.path == null)
          ? XFile.fromData(f.bytes ?? Uint8List(0), name: f.name,
              mimeType: ApiClient.inferMimeType(f.name))
          : XFile(f.path!, name: f.name);
      setState(() {
        _audioFile = xFile;
        _audioName = f.name;
      });
    } catch (e) {
      _showError('Failed to pick audio file: $e');
    }
  }

  // ── Apply music → render → save ───────────────────────────────────────────

  Future<void> _applyMusicAndSave() async {
    if (_audioFile == null) return;
    setState(() => _isApplyingMusic = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final lang = ref.read(settingsProvider).language;
    final api  = ref.read(apiClientProvider);

    try {
      // 1) Upload audio file
      final audioResp = await api.uploadAudio(_audioFile!);
      if (audioResp['ok'] != true) {
        throw Exception(audioResp['error'] ?? 'Audio upload failed');
      }
      final audioAssetId = audioResp['asset']?['id']?.toString();
      if (audioAssetId == null) throw Exception('Audio asset id missing in response');

      // 2) Render media with audio
      final renderResp = await api.renderWithAudio({
        'media_asset_id': widget.asset.id,
        'audio_asset_id': audioAssetId,
        'output_type':    _publishType.outputType,
        'duration_seconds': _publishType == PublishType.story ? 15 : 60,
        'audio_mode':     'replace',
        'aspect_ratio':   _publishType.aspectRatio,
      });
      if (renderResp['ok'] != true) {
        throw Exception(renderResp['error'] ?? 'Render failed');
      }

      // 3) Add rendered asset to local media library
      final newAsset = MediaAsset.fromUploadResponse(renderResp);
      // Carry over the caption/hashtags to the rendered asset
      newAsset.caption  = _captionController.text;
      newAsset.hashtags = _hashtagsController.text.split(' ')
          .where((s) => s.isNotEmpty).toList();
      await ref.read(mediaProvider.notifier).addAssetToBox(newAsset);

      // Also save caption to original asset
      widget.asset.caption  = _captionController.text;
      widget.asset.hashtags = newAsset.hashtags;
      await ref.read(mediaProvider.notifier).updateMedia(widget.asset);

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text(S.tr('musicSavedToLibrary', lang)),
        backgroundColor: Colors.green.shade700,
      ));
      context.pop();
    } catch (e) {
      debugPrint('APPLY MUSIC ERROR: $e');
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isApplyingMusic = false);
    }
  }

  // ── Save caption only ─────────────────────────────────────────────────────

  void _saveCaptionToLibrary() {
    widget.asset.caption  = _captionController.text;
    widget.asset.hashtags = _hashtagsController.text
        .split(' ')
        .where((s) => s.isNotEmpty)
        .toList();
    ref.read(mediaProvider.notifier).updateMedia(widget.asset);
    context.pop();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.asset.mediaType == MediaType.video;
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;
    final hasBrandProfile = settings.brandProfile.isConfigured;
    final gold = Theme.of(context).colorScheme.primary;

    final thumbnailUrl = isVideo
        ? widget.asset.imageUrl
        : (widget.asset.imageUrl ?? widget.asset.mediaUrl);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Post'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) context.pop();
            else context.go('/media');
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Regenerate caption',
            onPressed: _isGeneratingCaption ? null : _generateCaption,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Brand profile hint ───────────────────────────────────
                if (!hasBrandProfile)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: gold.withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline, color: gold, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Set up your AI Brand Profile for personalised captions.',
                        style: TextStyle(color: gold, fontSize: 12),
                      )),
                      TextButton(
                        onPressed: () => context.push('/ai/brand-profile'),
                        child: Text('Set up', style: TextStyle(color: gold, fontSize: 12)),
                      ),
                    ]),
                  ),

                // ── Preview ──────────────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: thumbnailUrl != null
                        ? CachedNetworkImage(
                            imageUrl: thumbnailUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => isVideo
                                ? _VideoPoster(asset: widget.asset, gold: gold)
                                : Container(color: const Color(0xFF1C1C1E),
                                    child: const Icon(Icons.broken_image_outlined,
                                        color: Colors.white38)),
                          )
                        : (isVideo
                            ? _VideoPoster(asset: widget.asset, gold: gold)
                            : Container(color: const Color(0xFF1C1C1E),
                                child: const Icon(Icons.photo_outlined,
                                    color: Colors.white38, size: 48))),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Publish type selector ────────────────────────────────
                _SectionCard(
                  title: S.tr('publishTypeLabel', lang),
                  child: _PublishTypeSelector(
                    selected: _publishType,
                    isVideo: isVideo,
                    lang: lang,
                    onChanged: (t) => setState(() => _publishType = t),
                  ),
                ),
                const SizedBox(height: 8),

                // ── Story 9:16 warning ───────────────────────────────────
                if (_publishType == PublishType.story)
                  _WarningBanner(
                    message: S.tr('storyAspectWarning', lang),
                    color: Colors.amber,
                  ),
                if (_publishType == PublishType.reels && !isVideo)
                  _WarningBanner(
                    message: S.tr('reelImageWarning', lang),
                    color: gold,
                  ),

                const SizedBox(height: 8),

                // ── Custom audio section ─────────────────────────────────
                _SectionCard(
                  title: S.tr('addCustomAudio', lang),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_audioName == null) ...[
                        Text(
                          S.tr('noAudio', lang),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _pickAudio,
                          icon: const Icon(Icons.audio_file_outlined, size: 18),
                          label: Text(S.tr('uploadAudio', lang),
                              style: const TextStyle(fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: gold,
                            side: BorderSide(color: gold.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ] else ...[
                        Row(children: [
                          Icon(Icons.library_music_outlined, color: gold, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            _audioName!,
                            style: const TextStyle(fontSize: 13,
                                color: Colors.white, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          )),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18,
                                color: Colors.white38),
                            onPressed: () => setState(() {
                              _audioFile = null;
                              _audioName = null;
                            }),
                          ),
                        ]),
                        const SizedBox(height: 4),
                        Text(
                          S.tr('audioSelected', lang),
                          style: TextStyle(fontSize: 11,
                              color: gold.withValues(alpha: 0.8)),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Caption & hashtags ───────────────────────────────────
                if (_isGeneratingCaption)
                  const LinearProgressIndicator()
                else ...[
                  TextField(
                    controller: _captionController,
                    decoration: const InputDecoration(labelText: 'Caption'),
                    maxLines: 6,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _hashtagsController,
                    decoration: const InputDecoration(labelText: 'Hashtags'),
                    maxLines: 3,
                  ),
                ],
              ],
            ),
          ),

          // ── Full-screen rendering overlay ──────────────────────────────
          if (_isApplyingMusic)
            Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      S.tr('renderingMedia', lang),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _isGeneratingCaption || _isApplyingMusic
          ? null
          : _BottomBar(
              hasAudio: _audioFile != null,
              lang: lang,
              onSave: _saveCaptionToLibrary,
              onApplyMusic: _applyMusicAndSave,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supporting widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.bold,
                  color: gold.withValues(alpha: 0.75), letterSpacing: 1.4)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PublishTypeSelector extends StatelessWidget {
  final PublishType selected;
  final bool isVideo;
  final String lang;
  final ValueChanged<PublishType> onChanged;

  const _PublishTypeSelector({
    required this.selected, required this.isVideo,
    required this.lang, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    const types = PublishType.values;
    return Row(
      children: types.map((t) {
        final disabled = t == PublishType.reels && !isVideo;
        final isSel = t == selected;
        return Expanded(
          child: GestureDetector(
            onTap: disabled ? null : () => onChanged(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: isSel ? gold.withValues(alpha: 0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSel ? gold : Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: [
                  Icon(_iconForType(t),
                      color: disabled
                          ? Colors.white24
                          : isSel ? gold : Colors.white60,
                      size: 18),
                  const SizedBox(height: 4),
                  Text(t.label(lang),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: disabled
                            ? Colors.white24
                            : isSel ? gold : Colors.white60,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      )),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _iconForType(PublishType t) {
    switch (t) {
      case PublishType.feed:  return Icons.image_outlined;
      case PublishType.reels: return Icons.movie_creation_outlined;
      case PublishType.story: return Icons.amp_stories_outlined;
    }
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;
  final Color color;
  const _WarningBanner({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: TextStyle(color: color, fontSize: 12))),
      ]),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool hasAudio;
  final String lang;
  final VoidCallback onSave;
  final VoidCallback onApplyMusic;

  const _BottomBar({
    required this.hasAudio, required this.lang,
    required this.onSave, required this.onApplyMusic,
  });

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: hasAudio
            ? ElevatedButton.icon(
                onPressed: onApplyMusic,
                icon: const Icon(Icons.library_music_outlined),
                label: Text(S.tr('applyMusicAndSave', lang)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              )
            : ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save to Library'),
              ),
      ),
    );
  }
}

/// A poster/placeholder shown for video assets that have no thumbnail.
class _VideoPoster extends StatelessWidget {
  final MediaAsset asset;
  final Color gold;
  const _VideoPoster({required this.asset, required this.gold});

  @override
  Widget build(BuildContext context) {
    final label = asset.fileName
        ?? asset.videoUrl?.split('/').last
        ?? asset.mediaUrl?.split('/').last
        ?? 'Video';
    return Container(
      color: const Color(0xFF1C1C1E),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_collection_outlined, color: gold, size: 56),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
          ),
        ],
      ),
    );
  }
}

