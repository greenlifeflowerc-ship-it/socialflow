import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/app_settings.dart';
import '../../../models/ai_model.dart';
import '../../../services/ai_service.dart';
import '../../../services/settings_service.dart';
import '../../../core/l10n/app_strings.dart';

class ConfigurationsScreen extends ConsumerStatefulWidget {
  const ConfigurationsScreen({super.key});

  @override
  ConsumerState<ConfigurationsScreen> createState() =>
      _ConfigurationsScreenState();
}

class _ConfigurationsScreenState extends ConsumerState<ConfigurationsScreen> {
  final _apiKeyController = TextEditingController();

  bool _isRefreshingModels = false;
  bool _isTestingAi = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _apiKeyController.text =
        _getApiKeyForProvider(settings, settings.selectedAiProvider);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  String _getApiKeyForProvider(AppSettings settings, String provider) {
    switch (provider) {
      case 'openai':
        return settings.openAiApiKey ?? '';
      case 'openrouter':
        return settings.openRouterApiKey ?? '';
      default:
        return settings.geminiApiKey ?? '';
    }
  }

  Future<void> _refreshModels(String lang) async {
    setState(() => _isRefreshingModels = true);
    final settings = ref.read(settingsProvider);
    final aiService = ref.read(aiServiceProvider);

    try {
      final response = await aiService.listModels(
        provider: settings.selectedAiProvider,
        apiKey: _apiKeyController.text.trim().isEmpty
            ? null
            : _apiKeyController.text.trim(),
      );

      final models =
          (response['models'] as List).map((m) => AiModel.fromJson(m)).toList();
      final textModels =
          models.where((m) => m.type == 'text').map((m) => m.id).toList();
      final imageModels =
          models.where((m) => m.type == 'image').map((m) => m.id).toList();

      ref.read(settingsProvider.notifier).updateState(
            settings.copyWith(
              availableModels: models,
              selectedTextModel:
                  textModels.isNotEmpty ? textModels.first : null,
              selectedImageModel:
                  imageModels.isNotEmpty ? imageModels.first : null,
              lastModelsRefreshAt: DateTime.now(),
            ),
          );
      _showSnackbar(S.tr('modelsRefreshed', lang), isError: false);
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      _showSnackbar('${S.tr('modelsRefreshFailed', lang)}: $message',
          isError: true);
    } finally {
      if (mounted) setState(() => _isRefreshingModels = false);
    }
  }

  Future<void> _testAiConnection(String lang) async {
    setState(() => _isTestingAi = true);
    final settings = ref.read(settingsProvider);
    if (settings.selectedTextModel == null) {
      _showSnackbar(S.tr('noModelSelected', lang), isError: true);
      setState(() => _isTestingAi = false);
      return;
    }

    try {
      await ref.read(aiServiceProvider).testModel(
            provider: settings.selectedAiProvider,
            model: settings.selectedTextModel!,
            apiKey: _apiKeyController.text.trim().isEmpty
                ? null
                : _apiKeyController.text.trim(),
          );
      _showSnackbar(S.tr('aiSuccess', lang), isError: false);
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      _showSnackbar('${S.tr('aiFailed', lang)}: $message', isError: true);
    } finally {
      if (mounted) setState(() => _isTestingAi = false);
    }
  }

  Future<void> _saveSettings(String lang) async {
    final notifier = ref.read(settingsProvider.notifier);
    final currentSettings = ref.read(settingsProvider);
    final apiKey = _apiKeyController.text.trim();
    final provider = currentSettings.selectedAiProvider;

    await notifier.save(
      currentSettings.copyWith(
        geminiApiKey: provider == 'gemini' ? apiKey : currentSettings.geminiApiKey,
        openAiApiKey: provider == 'openai' ? apiKey : currentSettings.openAiApiKey,
        openRouterApiKey:
            provider == 'openrouter' ? apiKey : currentSettings.openRouterApiKey,
      ),
    );
    _showSnackbar(S.tr('settingsSaved', lang), isError: false);
  }

  void _showSnackbar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;
    final textModels = settings.availableModels.where((m) => m.type == 'text').toList();
    final imageModels =
        settings.availableModels.where((m) => m.type == 'image').toList();

    return Scaffold(
      appBar: AppBar(title: Text(S.tr('configurations', lang))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── AI provider settings ───────────────────────────────────────────
          _buildSubSectionHeader(S.tr('aiProvider', lang)),
          _buildDropdown(
            S.tr('provider', lang),
            settings.selectedAiProvider,
            ['gemini', 'openai', 'openrouter'],
            (val) {
              if (val != null) {
                final updated = settings.copyWith(selectedAiProvider: val);
                ref.read(settingsProvider.notifier).updateState(updated);
                _apiKeyController.text =
                    _getApiKeyForProvider(settings, val);
              }
            },
          ),
          _buildTextField(
            '${S.tr('apiKey', lang)} (${settings.selectedAiProvider})',
            _apiKeyController,
            obscure: true,
          ),
          // Helper text: tell the user whether their key or the backend key is used
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _apiKeyController,
              builder: (context, value, _) {
                final hasKey = value.text.trim().isNotEmpty;
                return Text(
                  hasKey
                      ? 'Using your Gemini API key.'
                      : 'Using backend default Gemini key if configured.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: hasKey ? Colors.green : Colors.orange,
                      ),
                );
              },
            ),
          ),
          _buildActionButton(
            label: S.tr('refreshModels', lang),
            icon: Icons.sync,
            isLoading: _isRefreshingModels,
            onPressed: () => _refreshModels(lang),
          ),
          const SizedBox(height: 12),
          _buildDropdown(
            S.tr('textModel', lang),
            settings.selectedTextModel,
            textModels.map((m) => m.id).toList(),
            (val) => ref.read(settingsProvider.notifier).updateState(
                  settings.copyWith(selectedTextModel: val),
                ),
          ),
          _buildDropdown(
            S.tr('imageModel', lang),
            settings.selectedImageModel,
            imageModels.map((m) => m.id).toList(),
            (val) => ref.read(settingsProvider.notifier).updateState(
                  settings.copyWith(selectedImageModel: val),
                ),
          ),
          _buildActionButton(
            label: S.tr('testAi', lang),
            icon: Icons.bolt_outlined,
            isLoading: _isTestingAi,
            onPressed: () => _testAiConnection(lang),
          ),

          const SizedBox(height: 20),

          // ── Sync preferences ───────────────────────────────────────────────
          _buildSubSectionHeader(S.tr('metaIntegration', lang)),
          SwitchListTile(
            title: Text(S.tr('inboxSync', lang)),
            subtitle: Text(S.tr('inboxSyncSub', lang)),
            value: settings.isMetaInboxEnabled,
            onChanged: (val) => ref.read(settingsProvider.notifier).updateState(
                  settings.copyWith(isMetaInboxEnabled: val),
                ),
          ),
          SwitchListTile(
            title: Text(S.tr('commentsSync', lang)),
            subtitle: Text(S.tr('commentsSyncSub', lang)),
            value: settings.isMetaCommentsEnabled,
            onChanged: (val) => ref.read(settingsProvider.notifier).updateState(
                  settings.copyWith(isMetaCommentsEnabled: val),
                ),
          ),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _saveSettings(lang),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54)),
            child: Text(S.tr('saveSettings', lang)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }


  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required VoidCallback onPressed,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              )
            : OutlinedButton.icon(
                icon: Icon(icon),
                label: Text(label),
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
      );

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    String? hint,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: TextField(
          controller: controller,
          obscureText: obscure,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
          ),
        ),
      );

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: DropdownButtonFormField<String>(
          value: items.contains(value) ? value : null,
          items: items
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(labelText: label),
          isExpanded: true,
        ),
      );

  Widget _buildSubSectionHeader(String title) => Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 10.0),
        child: Row(
          children: [
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                color:
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Divider(color: Theme.of(context).dividerColor)),
          ],
        ),
      );
}
