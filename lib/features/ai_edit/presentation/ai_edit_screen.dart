import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../media/models/media_item.dart';

class AIEditScreen extends StatefulWidget {
  final MediaItem mediaItem;

  const AIEditScreen({super.key, required this.mediaItem});

  @override
  State<AIEditScreen> createState() => _AIEditScreenState();
}

class _AIEditScreenState extends State<AIEditScreen> {
  String _selectedStyle = 'luxury interior';
  String _selectedSize = '1080x1350';
  final _customPromptController = TextEditingController();

  final List<String> _styles = [
    'luxury interior',
    'villa entrance',
    'hotel lobby',
    'mall decoration',
    'staircase decoration',
    'outdoor garden',
    'white background product photo',
    'custom prompt'
  ];

  final List<String> _sizes = [
    '1080x1080',
    '1080x1350',
    '1080x1920',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI IMAGE EDIT'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.mediaItem.originalUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('SELECT STYLE', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _styles.map((style) {
                final isSelected = _selectedStyle == style;
                return ChoiceChip(
                  label: Text(style),
                  selected: isSelected,
                  onSelected: (val) => setState(() => _selectedStyle = style),
                  selectedColor: AppTheme.primaryGold,
                  labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white),
                );
              }).toList(),
            ),
            if (_selectedStyle == 'custom prompt') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customPromptController,
                decoration: const InputDecoration(
                  labelText: 'Custom AI Prompt',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
            const SizedBox(height: 24),
            const Text('SELECT SIZE', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedSize,
              items: _sizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => setState(() => _selectedSize = val!),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Call AI Edit API
                },
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('GENERATE AI EDIT'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
