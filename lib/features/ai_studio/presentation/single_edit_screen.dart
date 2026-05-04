import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../core/l10n/app_strings.dart';
import '../../../models/media_asset.dart';
import '../../../services/api_client.dart';
import '../../../services/settings_service.dart';
import '../../../services/media_service.dart';

class SingleEditScreen extends ConsumerStatefulWidget {
  final MediaAsset? asset;
  const SingleEditScreen({super.key, this.asset});

  @override
  ConsumerState<SingleEditScreen> createState() => _SingleEditScreenState();
}

class _SingleEditScreenState extends ConsumerState<SingleEditScreen> {
  MediaAsset? _selectedAsset;
  final TextEditingController _promptController = TextEditingController();
  String _aspectRatio = 'Original';
  String _resolution = 'Auto';
  bool _preserveProduct = true;
  bool _preservePlanter = true;
  bool _isProcessing = false;
  String? _resultImageUrl;

  @override
  void initState() {
    super.initState();
    _selectedAsset = widget.asset;
  }

  Future<void> _generateAutoPrompt() async {
    if (_selectedAsset == null) return;
    setState(() => _isProcessing = true);
    try {
      final settings = ref.read(settingsProvider);
      final response = await ref.read(apiClientProvider).generateEditPrompt({
        'imageUrl': _selectedAsset!.imageUrl ?? _selectedAsset!.mediaUrl,
        'provider': settings.selectedAiProvider,
        'model': settings.selectedTextModel,
        'preserveProduct': _preserveProduct,
        'preservePlanter': _preservePlanter,
      });
      if (response['ok'] == true) {
        _promptController.text = response['result']['prompt'];
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _startEdit() async {
    if (_selectedAsset == null || _promptController.text.isEmpty) return;
    setState(() {
      _isProcessing = true;
      _resultImageUrl = null;
    });
    try {
      final settings = ref.read(settingsProvider);
      final response = await ref.read(apiClientProvider).editImage({
        'originalImageUrl': _selectedAsset!.imageUrl ?? _selectedAsset!.mediaUrl,
        'mediaAssetId': _selectedAsset!.id,
        'prompt': _promptController.text,
        'provider': settings.selectedAiProvider,
        'model': settings.selectedImageModel ?? 'dall-e-3',
        'aspectRatio': _aspectRatio,
        'resolution': _resolution,
        'preserveProduct': _preserveProduct,
        'preservePlanter': _preservePlanter,
        'saveToLibrary': true,
      });
      if (response['ok'] == true) {
        setState(() {
          _resultImageUrl = response['result']['imageUrl'];
        });
        // Auto-refresh library to show new AI result
        await ref.read(mediaProvider.notifier).refresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image edited and saved to library!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _downloadResult() async {
    if (_resultImageUrl == null) return;
    
    setState(() => _isProcessing = true);
    try {
      final dio = Dio();
      final response = await dio.get(_resultImageUrl!, options: Options(responseType: ResponseType.bytes));
      
      String? outputFile;
      if (kIsWeb) {
        // Web download logic would go here, but focusing on Desktop/Mobile as per project
      } else {
        final fileName = 'ai_edit_${DateTime.now().millisecondsSinceEpoch}.png';
        outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save AI Result',
          fileName: fileName,
          type: FileType.image,
        );
        
        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(response.data);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to: $outputFile')));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider);
    return Scaffold(
      appBar: AppBar(title: Text(S.tr('singleImageEdit', lang))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedAsset != null)
              Center(
                child: SizedBox(
                  height: 200,
                  child: CachedNetworkImage(imageUrl: _selectedAsset!.imageUrl ?? _selectedAsset!.mediaUrl!),
                ),
              )
            else
              Center(child: Text(S.tr('selectImageFromLibrary', lang))),
            const SizedBox(height: 16),
            TextField(
              controller: _promptController,
              decoration: InputDecoration(
                labelText: S.tr('editPrompt', lang),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_awesome),
                  onPressed: _generateAutoPrompt,
                  tooltip: S.tr('autoPrompt', lang),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _aspectRatio,
                    decoration: InputDecoration(labelText: S.tr('aspectRatioLabel', lang)),
                    items: ['Original', '1:1', '4:5', '9:16', '16:9', '3:4'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _aspectRatio = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _resolution,
                    decoration: InputDecoration(labelText: S.tr('resolutionLabel', lang)),
                    items: ['Auto', '1080', '1350', '1920', '2048'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => _resolution = v!),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              title: Text(S.tr('preserveProduct', lang)),
              value: _preserveProduct,
              onChanged: (v) => setState(() => _preserveProduct = v),
            ),
            SwitchListTile(
              title: Text(S.tr('preservePlanter', lang)),
              value: _preservePlanter,
              onChanged: (v) => setState(() => _preservePlanter = v),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _startEdit,
                child: _isProcessing ? const CircularProgressIndicator() : Text(S.tr('startEdit', lang)),
              ),
            ),
            if (_resultImageUrl != null) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${S.tr('resultImage', lang)}:', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _downloadResult,
                    icon: const Icon(Icons.download),
                    label: Text(S.tr('downloadResult', lang)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(child: CachedNetworkImage(imageUrl: _resultImageUrl!)),
            ]
          ],
        ),
      ),
    );
  }
}
