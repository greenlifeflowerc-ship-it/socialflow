import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/media/presentation/media_library_screen.dart';
import '../../../models/media_asset.dart';
import '../../../services/bulk_scheduler_service.dart';
import '../../../services/media_service.dart';

class BulkSchedulerScreen extends ConsumerStatefulWidget {
  const BulkSchedulerScreen({super.key});

  @override
  ConsumerState<BulkSchedulerScreen> createState() => _BulkSchedulerScreenState();
}

class _BulkSchedulerScreenState extends ConsumerState<BulkSchedulerScreen> {
  DateTime _startDate = DateTime.now();
  int _numDays = 1;
  int _postsPerDay = 1;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);
  CaptionMode _captionMode = CaptionMode.generate_missing;
  
  // New state variables for advanced captioning
  String _captionPreset = 'Luxury Product Caption';
  String _tone = 'luxury';
  String _language = 'English';
  String _cta = 'Contact us today';

  @override
  Widget build(BuildContext context) {
    final selectedIds = ref.watch(selectionProvider);
    final allMedia = ref.watch(mediaProvider);
    final selectedMedia = allMedia.where((m) => selectedIds.contains(m.id)).toList();
    final totalCapacity = _numDays * _postsPerDay;

    return Scaffold(
      appBar: AppBar(
        title: Text('Schedule ${selectedMedia.length} Items'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/media');
            }
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Schedule Settings'),
          _buildDatePicker('Start Date', _startDate, (date) => setState(() => _startDate = date)),
          _buildIntInput('Number of Days', _numDays, (val) => setState(() => _numDays = val)),
          _buildIntInput('Posts per Day', _postsPerDay, (val) => setState(() => _postsPerDay = val)),
          _buildTimePicker('Start Time', _startTime, (val) => setState(() => _startTime = val)),
          _buildTimePicker('End Time', _endTime, (val) => setState(() => _endTime = val)),
          
          _buildSectionHeader('AI Caption Settings'),
          _buildDropdown('Caption Preset', _captionPreset, ['Luxury Product Caption', 'Artificial Tree Marketing', 'Interior Design Decor', 'Custom Prompt'], (val) => setState(() => _captionPreset = val!)),
          _buildDropdown('Tone', _tone, ['luxury', 'premium', 'elegant', 'sales', 'poetic'], (val) => setState(() => _tone = val!)),
          _buildDropdown('Language', _language, ['English', 'Arabic', 'Arabic + English'], (val) => setState(() => _language = val!)),
          _buildDropdown('Call to Action (CTA)', _cta, ['Contact us today', 'Order now', 'No CTA'], (val) => setState(() => _cta = val!)),
          _buildDropdown('Caption Mode', _captionMode.name, CaptionMode.values.map((e) => e.name).toList(), (val) => setState(() => _captionMode = CaptionMode.values.firstWhere((e) => e.name == val))),
          
          const Divider(height: 32),
          
          if (selectedMedia.length > totalCapacity)
            Text('Warning: Schedule capacity ($totalCapacity) is less than selected media (${selectedMedia.length}).', style: const TextStyle(color: Colors.orangeAccent)),
          
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: () {
              context.go('/bulk-scheduler-preview', extra: {
                'selectedMedia': selectedMedia,
                'startDate': _startDate, 'numDays': _numDays, 'postsPerDay': _postsPerDay,
                'startTime': _startTime, 'endTime': _endTime, 'captionMode': _captionMode,
                'captionPreset': _captionPreset, 'tone': _tone, 'language': _language, 'cta': _cta,
              });
            },
            child: const Text('Generate & Preview'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Text(title, style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)));
  Widget _buildIntInput(String label, int value, ValueChanged<int> onChanged) => ListTile(title: Text(label), trailing: SizedBox(width: 80, child: TextFormField(initialValue: value.toString(), keyboardType: TextInputType.number, textAlign: TextAlign.center, onChanged: (val) => onChanged(int.tryParse(val) ?? 0))));
  Widget _buildDatePicker(String label, DateTime date, ValueChanged<DateTime> onChanged) => ListTile(title: Text(label), subtitle: Text(DateFormat.yMMMd().format(date)), onTap: () async {final newDate = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime(2030)); if (newDate != null) onChanged(newDate);});
  Widget _buildTimePicker(String label, TimeOfDay time, ValueChanged<TimeOfDay> onChanged) => ListTile(title: Text(label), subtitle: Text(time.format(context)), onTap: () async {final newTime = await showTimePicker(context: context, initialTime: time); if (newTime != null) onChanged(newTime);});
  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) => DropdownButtonFormField<String>(value: value, items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: onChanged, decoration: InputDecoration(labelText: label));
}
