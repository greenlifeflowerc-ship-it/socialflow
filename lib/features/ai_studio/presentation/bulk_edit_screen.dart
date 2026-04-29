import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/media_asset.dart';
import '../../../services/api_client.dart';
import '../../../services/settings_service.dart';

class BulkEditScreen extends ConsumerStatefulWidget {
  final List<MediaAsset> assets;
  const BulkEditScreen({super.key, required this.assets});

  @override
  ConsumerState<BulkEditScreen> createState() => _BulkEditScreenState();
}

class _BulkEditScreenState extends ConsumerState<BulkEditScreen> {
  final TextEditingController _sharedPromptController = TextEditingController();
  bool _useAutoPrompt = true;
  bool _isProcessing = false;
  String _aspectRatio = 'Original';

  Future<void> _startBulkEdit() async {
    setState(() => _isProcessing = true);
    try {
      final settings = ref.read(settingsProvider);
      final response = await ref.read(apiClientProvider).createBulkEditJob({
        'items': widget.assets.map((a) => {
          'mediaAssetId': a.id,
          'mediaUrl': a.mediaUrl,
          'imageUrl': a.imageUrl,
          'useAutoPrompt': _useAutoPrompt,
        }).toList(),
        'sharedPrompt': _sharedPromptController.text,
        'useAutoPrompt': _useAutoPrompt,
        'provider': settings.selectedAiProvider,
        'model': settings.selectedImageModel,
        'aspectRatio': _aspectRatio,
        'saveToLibrary': true,
      });
      if (response['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bulk edit job started!')));
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk AI Edit')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: widget.assets.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Image.network(widget.assets[index].imageUrl ?? widget.assets[index].mediaUrl!, width: 50, height: 50, fit: BoxFit.cover),
                    title: Text(widget.assets[index].id),
                    subtitle: const Text('Pending...'),
                  );
                },
              ),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Use Auto Prompt per image'),
              value: _useAutoPrompt,
              onChanged: (v) => setState(() => _useAutoPrompt = v),
            ),
            if (!_useAutoPrompt)
              TextField(
                controller: _sharedPromptController,
                decoration: const InputDecoration(labelText: 'Shared Prompt for all'),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isProcessing ? null : _startBulkEdit,
              child: _isProcessing ? const CircularProgressIndicator() : const Text('Start Bulk Edit'),
            ),
          ],
        ),
      ),
    );
  }
}
