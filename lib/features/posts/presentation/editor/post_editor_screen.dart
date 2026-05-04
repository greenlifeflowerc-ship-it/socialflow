import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../models/media_asset.dart';
import '../../../../services/ai_service.dart';
import '../../../../services/media_service.dart';
import '../../../../services/settings_service.dart';

class PostEditorScreen extends ConsumerStatefulWidget {
  final MediaAsset asset;
  const PostEditorScreen({super.key, required this.asset});

  @override
  ConsumerState<PostEditorScreen> createState() => _PostEditorScreenState();
}

class _PostEditorScreenState extends ConsumerState<PostEditorScreen> {
  final _captionController = TextEditingController();
  final _hashtagsController = TextEditingController();
  bool _isGeneratingCaption = true;

  @override
  void initState() {
    super.initState();
    _generateCaption();
  }

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
        // Use brand-aware generation
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
        // Fallback: basic generation without brand profile
        debugPrint('POST EDITOR: generating without brand profile (not configured)');
        result = await ref.read(aiServiceProvider).generateCaption(
          imageUrl: imageUrl,
          mediaUrl: widget.asset.mediaUrl,
          provider: settings.selectedAiProvider,
          model: settings.selectedTextModel!,
          language: settings.language == 'ar' ? 'Arabic' : 'English',
          tone: 'professional',
        );
      }

      _captionController.text = result['caption'] as String? ?? '';
      _hashtagsController.text =
          (result['hashtags'] as List? ?? []).join(' ');
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

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.asset.imageUrl ?? widget.asset.mediaUrl;
    final settings = ref.watch(settingsProvider);
    final hasBrandProfile = settings.brandProfile.isConfigured;
    final gold = Theme.of(context).colorScheme.primary;

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Brand profile hint
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
                  Expanded(
                    child: Text(
                      'Set up your AI Brand Profile for personalised captions.',
                      style: TextStyle(color: gold, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/ai/brand-profile'),
                    child: Text('Set up', style: TextStyle(color: gold, fontSize: 12)),
                  ),
                ]),
              ),

            // Thumbnail
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
                ),
              ),
            const SizedBox(height: 16),

            if (_isGeneratingCaption)
              const LinearProgressIndicator()
            else
              Column(
                children: [
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
              ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _isGeneratingCaption
              ? null
              : () {
                  widget.asset.caption = _captionController.text;
                  widget.asset.hashtags = _hashtagsController.text
                      .split(' ')
                      .where((s) => s.isNotEmpty)
                      .toList();
                  ref.read(mediaProvider.notifier).updateMedia(widget.asset);
                  context.pop();
                },
          child: const Text('Save to Library'),
        ),
      ),
    );
  }
}
