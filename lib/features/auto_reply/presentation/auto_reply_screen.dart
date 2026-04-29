import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/ig_models.dart';
import '../../../services/api_client.dart';
import '../../../services/settings_service.dart';

final autoReplyRulesProvider = FutureProvider.autoDispose<List<AutoReplyRule>>((ref) async {
  final response = await ref.read(apiClientProvider).getAutoReplyRules();
  return (response['rules'] as List).map((e) => AutoReplyRule.fromJson(e)).toList();
});

class AutoReplyScreen extends ConsumerWidget {
  const AutoReplyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(autoReplyRulesProvider);
    final lang = ref.watch(settingsProvider).language;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.tr('autoReplies', lang).toUpperCase()),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.refresh(autoReplyRulesProvider)),
        ],
      ),
      body: rulesAsync.when(
        data: (rules) {
          if (rules.isEmpty) return Center(child: Text(S.tr('noRules', lang)));
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  title: Text(rule.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('${S.tr('triggerType', lang)}: ${rule.triggerType}'),
                      if (rule.publicReplyText != null)
                        Text(rule.publicReplyText!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: Switch(
                    value: rule.isEnabled,
                    onChanged: (v) async {
                      await ref.read(apiClientProvider).updateAutoReplyRule(rule.id, {'isEnabled': v});
                      ref.refresh(autoReplyRulesProvider);
                    },
                  ),
                  onLongPress: () async {
                     final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(S.tr('deleteRule', lang)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(S.tr('cancel', lang))),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(S.tr('delete', lang), style: const TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(apiClientProvider).deleteAutoReplyRule(rule.id);
                      ref.refresh(autoReplyRulesProvider);
                    }
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRuleDialog(context, ref, lang),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddRuleDialog(BuildContext context, WidgetRef ref, String lang) {
    final nameController = TextEditingController();
    final publicReplyController = TextEditingController();
    final keywordController = TextEditingController();
    String triggerType = 'any_comment';
    String replyMode = 'public_reply';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(S.tr('createRule', lang)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: InputDecoration(labelText: S.tr('ruleName', lang))),
                DropdownButtonFormField<String>(
                  value: triggerType,
                  items: ['any_comment', 'keyword', 'exact_match'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => triggerType = v!),
                  decoration: InputDecoration(labelText: S.tr('triggerType', lang)),
                ),
                if (triggerType != 'any_comment')
                  TextField(controller: keywordController, decoration: InputDecoration(labelText: S.tr('keywords', lang))),
                DropdownButtonFormField<String>(
                  value: replyMode,
                  items: ['public_reply', 'private_reply', 'both'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => replyMode = v!),
                  decoration: InputDecoration(labelText: S.tr('replyMode', lang)),
                ),
                TextField(controller: publicReplyController, decoration: InputDecoration(labelText: S.tr('replyMessage', lang)), maxLines: 2),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(S.tr('cancel', lang))),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ref.read(apiClientProvider).createAutoReplyRule({
                    'name': nameController.text,
                    'triggerType': triggerType,
                    'keywords': keywordController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
                    'replyMode': replyMode,
                    'publicReplyText': publicReplyController.text,
                    'isEnabled': true,
                  });
                  Navigator.pop(context);
                  ref.refresh(autoReplyRulesProvider);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(S.tr('create', lang)),
            ),
          ],
        ),
      ),
    );
  }
}

