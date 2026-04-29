import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/app_settings.dart';
import '../../../models/ai_model.dart';
import '../../../services/ai_service.dart';
import '../../../services/settings_service.dart';
import '../../../core/l10n/app_strings.dart';

class ConfigurationsScreen extends ConsumerStatefulWidget {
  const ConfigurationsScreen({super.key});

  @override
  ConsumerState<ConfigurationsScreen> createState() => _ConfigurationsScreenState();
}

class _ConfigurationsScreenState extends ConsumerState<ConfigurationsScreen> {
  final _supabaseUrlController = TextEditingController();
  final _supabaseAnonKeyController = TextEditingController();
  final _apiUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();

  bool _isRefreshingModels = false;
  bool _isTestingAi = false;
  bool _isTestingBackend = false;

  @override
  void initState() {
    super.initState();
    _syncControllersFromState(ref.read(settingsProvider));
  }

  @override
  void dispose() {
    _supabaseUrlController.dispose();
    _supabaseAnonKeyController.dispose();
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _syncControllersFromState(AppSettings settings) {
    _supabaseUrlController.text = settings.supabaseUrl ?? '';
    _supabaseAnonKeyController.text = settings.supabaseAnonKey ?? '';
    _apiUrlController.text = settings.backendUrl ?? '';
    _apiKeyController.text = _getApiKeyForProvider(settings, settings.selectedAiProvider);
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

  Future<void> _testBackendConnection(String lang) async {
    setState(() => _isTestingBackend = true);
    String url = _apiUrlController.text.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    if (url.isEmpty) {
      _showSnackbar(S.tr('backendUrlRequired', lang), isError: true);
      setState(() => _isTestingBackend = false);
      return;
    }

    final dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 10);

    try {
      await dio.get('$url/api/health');

      try {
        final metaResponse = await dio.get('$url/api/meta/test-connection');
        final data = metaResponse.data as Map<String, dynamic>;
        final connected = data['ok'] == true || data['connected'] == true;
        final message = data['message'] as String? ??
            data['username'] as String? ??
            (connected ? S.tr('metaConnected', lang) : S.tr('metaDisconnected', lang));

        final settings = ref.read(settingsProvider);
        ref.read(settingsProvider.notifier).updateState(
          settings.copyWith(
            metaConnected: connected,
            lastMetaMessage: message,
          ),
        );
      } catch (_) {
        final settings = ref.read(settingsProvider);
        ref.read(settingsProvider.notifier).updateState(
          settings.copyWith(
            metaConnected: false,
            lastMetaMessage: S.tr('metaDisconnected', lang),
          ),
        );
      }

      _showSnackbar(S.tr('backendConnectedMsg', lang), isError: false);
    } catch (_) {
      final settings = ref.read(settingsProvider);
      ref.read(settingsProvider.notifier).updateState(
        settings.copyWith(metaConnected: false, lastMetaMessage: S.tr('notTested', lang)),
      );
      _showSnackbar(S.tr('backendFailedMsg', lang), isError: true);
    } finally {
      if (mounted) setState(() => _isTestingBackend = false);
    }
  }

  Future<void> _refreshModels(String lang) async {
    setState(() => _isRefreshingModels = true);
    final settings = ref.read(settingsProvider);
    final aiService = ref.read(aiServiceProvider);

    try {
      final response = await aiService.listModels(
        provider: settings.selectedAiProvider,
        apiKey: _apiKeyController.text.trim(),
      );

      final models = (response['models'] as List).map((m) => AiModel.fromJson(m)).toList();
      final textModels = models.where((m) => m.type == 'text').map((m) => m.id).toList();
      final imageModels = models.where((m) => m.type == 'image').map((m) => m.id).toList();

      ref.read(settingsProvider.notifier).updateState(
        settings.copyWith(
          availableModels: models,
          selectedTextModel: textModels.isNotEmpty ? textModels.first : null,
          selectedImageModel: imageModels.isNotEmpty ? imageModels.first : null,
          lastModelsRefreshAt: DateTime.now(),
        ),
      );
      _showSnackbar(S.tr('modelsRefreshed', lang), isError: false);
    } on DioException catch (e) {
      _showSnackbar('${S.tr('modelsRefreshFailed', lang)}: ${e.message}', isError: true);
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
        apiKey: _apiKeyController.text.trim(),
      );
      _showSnackbar(S.tr('aiSuccess', lang), isError: false);
    } on DioException catch (e) {
      _showSnackbar('${S.tr('aiFailed', lang)}: ${e.message}', isError: true);
    } finally {
      if (mounted) setState(() => _isTestingAi = false);
    }
  }

  Future<void> _saveSettings(String lang) async {
    final notifier = ref.read(settingsProvider.notifier);
    final currentSettings = ref.read(settingsProvider);

    String url = _apiUrlController.text.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);

    final apiKey = _apiKeyController.text.trim();
    final provider = currentSettings.selectedAiProvider;

    await notifier.save(
      currentSettings.copyWith(
        supabaseUrl: _supabaseUrlController.text.trim(),
        supabaseAnonKey: _supabaseAnonKeyController.text.trim(),
        backendUrl: url,
        geminiApiKey: provider == 'gemini' ? apiKey : currentSettings.geminiApiKey,
        openAiApiKey: provider == 'openai' ? apiKey : currentSettings.openAiApiKey,
        openRouterApiKey: provider == 'openrouter' ? apiKey : currentSettings.openRouterApiKey,
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
    final imageModels = settings.availableModels.where((m) => m.type == 'image').toList();

    return Scaffold(
      appBar: AppBar(title: Text(S.tr('configurations', lang))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSubSectionHeader(S.tr('supabase', lang)),
          _buildTextField(S.tr('supabaseUrl', lang), _supabaseUrlController, hint: 'https://xxxx.supabase.co'),
          _buildTextField(S.tr('supabaseAnonKey', lang), _supabaseAnonKeyController, obscure: true),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.tr('supabaseRestartNote', lang),
                    style: const TextStyle(fontSize: 12, color: Colors.amber),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          _buildSubSectionHeader(S.tr('backend', lang)),
          _buildTextField(S.tr('backendUrl', lang), _apiUrlController, hint: 'https://your-backend.com'),
          _buildActionButton(
            label: S.tr('testBackend', lang),
            icon: Icons.cloud_done_outlined,
            isLoading: _isTestingBackend,
            onPressed: () => _testBackendConnection(lang),
          ),

          const SizedBox(height: 20),

          _buildSubSectionHeader(S.tr('aiProvider', lang)),
          _buildDropdown(
            S.tr('provider', lang),
            settings.selectedAiProvider,
            ['gemini', 'openai', 'openrouter'],
            (val) {
              if (val != null) {
                final updated = settings.copyWith(selectedAiProvider: val);
                ref.read(settingsProvider.notifier).updateState(updated);
                _apiKeyController.text = _getApiKeyForProvider(settings, val);
              }
            },
          ),
          _buildTextField(
            '${S.tr('apiKey', lang)} (${settings.selectedAiProvider})',
            _apiKeyController,
            obscure: true,
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

          _buildSubSectionHeader(S.tr('metaIntegration', lang)),
          _buildMetaStatus(settings, lang),
          const SizedBox(height: 8),
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
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
            child: Text(S.tr('saveSettings', lang)),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMetaStatus(AppSettings settings, String lang) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: settings.metaConnected
              ? Colors.green.withOpacity(0.5)
              : Colors.red.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            settings.metaConnected ? Icons.check_circle : Icons.error_outline,
            color: settings.metaConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.metaConnected ? S.tr('metaConnected', lang) : S.tr('metaDisconnected', lang),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  settings.lastMetaMessage,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
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
          decoration: InputDecoration(
            labelText: label,
          ),
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
                color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
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
