import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/app_settings.dart';
import '../../../models/media_asset.dart';
import '../../../services/ai_service.dart';
import '../../../services/settings_service.dart';

class AiStudioScreen extends ConsumerStatefulWidget {
  final MediaAsset asset;
  const AiStudioScreen({super.key, required this.asset});

  @override
  ConsumerState<AiStudioScreen> createState() => _AiStudioScreenState();
}

class _AiStudioScreenState extends ConsumerState<AiStudioScreen> {
  final _promptController = TextEditingController();
  String _selectedStyle = 'luxury interior';
  String _selectedSize = '1080x1350';
  bool _isGeneratingPrompt = false;
  bool _isGeneratingImage = false;
  String? _editedImageUrl;

  final List<String> _styles = [
    'luxury interior', 'villa entrance', 'hotel lobby', 'mall decoration', 
    'staircase decoration', 'outdoor garden', 'white background product photo', 'custom'
  ];

  void _generatePrompt() async {
    final imageUrl = widget.asset.imageUrl ?? widget.asset.mediaUrl;
    if (imageUrl == null) {
      _showError("Media must be uploaded before generating a prompt.");
      return;
    }
    setState(() => _isGeneratingPrompt = true);
    final settings = ref.read(settingsProvider);
    if(settings.selectedTextModel == null) {
       _showError("No AI text model selected in settings.");
       setState(() => _isGeneratingPrompt = false);
       return;
    }

    try {
      final prompt = await ref.read(aiServiceProvider).generateEditPrompt(
        imageUrl: imageUrl,
        editStyle: _selectedStyle,
        provider: settings.selectedAiProvider,
        model: settings.selectedTextModel!,
      );
      _promptController.text = prompt;
    } on DioException catch (e) {
      _showError("AI Error: ${e.message}");
    } finally {
      if (mounted) setState(() => _isGeneratingPrompt = false);
    }
  }

  void _generateImage() async {
    final imageUrl = widget.asset.imageUrl ?? widget.asset.mediaUrl;
    if (imageUrl == null || _promptController.text.isEmpty) {
      _showError("Media URL is missing or prompt is empty.");
      return;
    }
    setState(() => _isGeneratingImage = true);
    final settings = ref.read(settingsProvider);
    if(settings.selectedImageModel == null) {
       _showError("No AI image model selected in settings.");
       setState(() => _isGeneratingImage = false);
       return;
    }
    
    try {
      final newUrl = await ref.read(aiServiceProvider).editImage(
        originalImageUrl: imageUrl,
        prompt: _promptController.text,
        size: _selectedSize,
        provider: settings.selectedAiProvider,
        model: settings.selectedImageModel!,
      );
      setState(() => _editedImageUrl = newUrl);
    } on DioException catch (e) {
      _showError("AI Error: ${e.message}");
    } finally {
      if (mounted) setState(() => _isGeneratingImage = false);
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI STUDIO')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBeforeAfter(),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'STYLE'),
          Wrap(
            spacing: 8,
            children: _styles.map((s) => ChoiceChip(
              label: Text(s),
              selected: _selectedStyle == s,
              onSelected: (_) => setState(() => _selectedStyle = s),
            )).toList(),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'PROMPT'),
          TextField(
            controller: _promptController,
            maxLines: 4,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'AI prompt will appear here...'),
          ),
          const SizedBox(height: 8),
          if (_isGeneratingPrompt) const Center(child: CircularProgressIndicator()) 
          else OutlinedButton.icon(
            onPressed: _generatePrompt,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generate Prompt Automatically'),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isGeneratingImage ? null : _generateImage,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('GENERATE EDITED IMAGE'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeforeAfter() {
    return Row(
      children: [
        Expanded(child: _buildImageCard('ORIGINAL', widget.asset.imageUrl ?? widget.asset.mediaUrl)),
        const SizedBox(width: 16),
        Expanded(child: _buildImageCard('AI EDITED', _editedImageUrl, isLoading: _isGeneratingImage)),
      ],
    );
  }

  Widget _buildImageCard(String title, String? url, {bool isLoading = false}) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1080 / 1350,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : url == null
                    ? const Center(child: Icon(Icons.image_outlined, size: 50, color: AppTheme.textGrey))
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (c, u) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (c, u, e) => const Icon(Icons.error),
                      ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
    );
  }
}
