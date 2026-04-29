import 'dart:convert';
import 'ai_model.dart';

class AppSettings {
  final String? supabaseUrl;
  final String? supabaseAnonKey;
  final String? backendUrl;
  final String? metaToken;
  final String? instagramId;

  // AI Settings
  final String? geminiApiKey;
  final String? openAiApiKey;
  final String? openRouterApiKey;
  final String selectedAiProvider;
  final String? selectedTextModel;
  final String? selectedImageModel;
  final String? selectedVideoModel;
  final List<AiModel> availableModels;
  final DateTime? lastModelsRefreshAt;

  // Runtime connection status (never persisted)
  final bool backendConnected;
  final bool metaConnected;
  final bool geminiConnected;
  final String lastBackendMessage;
  final String lastMetaMessage;
  final String lastGeminiMessage;

  // Appearance (persisted)
  final String language;
  final String selectedTheme;

  // Meta sync preferences (persisted)
  final bool isMetaInboxEnabled;
  final bool isMetaCommentsEnabled;

  AppSettings({
    this.supabaseUrl,
    this.supabaseAnonKey,
    this.backendUrl,
    this.metaToken,
    this.instagramId,
    this.geminiApiKey,
    this.openAiApiKey,
    this.openRouterApiKey,
    this.selectedAiProvider = 'gemini',
    this.selectedTextModel,
    this.selectedImageModel,
    this.selectedVideoModel,
    this.availableModels = const [],
    this.lastModelsRefreshAt,
    this.backendConnected = false,
    this.metaConnected = false,
    this.geminiConnected = false,
    this.lastBackendMessage = 'Not tested',
    this.lastMetaMessage = 'Not tested',
    this.lastGeminiMessage = 'Not tested',
    this.language = 'en',
    this.selectedTheme = 'midnight',
    this.isMetaInboxEnabled = false,
    this.isMetaCommentsEnabled = false,
  });

  AppSettings copyWith({
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? backendUrl,
    String? metaToken,
    String? instagramId,
    String? geminiApiKey,
    String? openAiApiKey,
    String? openRouterApiKey,
    String? selectedAiProvider,
    String? selectedTextModel,
    String? selectedImageModel,
    String? selectedVideoModel,
    List<AiModel>? availableModels,
    DateTime? lastModelsRefreshAt,
    bool? backendConnected,
    bool? metaConnected,
    bool? geminiConnected,
    String? lastBackendMessage,
    String? lastMetaMessage,
    String? lastGeminiMessage,
    String? language,
    String? selectedTheme,
    bool? isMetaInboxEnabled,
    bool? isMetaCommentsEnabled,
  }) {
    return AppSettings(
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
      backendUrl: backendUrl ?? this.backendUrl,
      metaToken: metaToken ?? this.metaToken,
      instagramId: instagramId ?? this.instagramId,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      openRouterApiKey: openRouterApiKey ?? this.openRouterApiKey,
      selectedAiProvider: selectedAiProvider ?? this.selectedAiProvider,
      selectedTextModel: selectedTextModel ?? this.selectedTextModel,
      selectedImageModel: selectedImageModel ?? this.selectedImageModel,
      selectedVideoModel: selectedVideoModel ?? this.selectedVideoModel,
      availableModels: availableModels ?? this.availableModels,
      lastModelsRefreshAt: lastModelsRefreshAt ?? this.lastModelsRefreshAt,
      backendConnected: backendConnected ?? this.backendConnected,
      metaConnected: metaConnected ?? this.metaConnected,
      geminiConnected: geminiConnected ?? this.geminiConnected,
      lastBackendMessage: lastBackendMessage ?? this.lastBackendMessage,
      lastMetaMessage: lastMetaMessage ?? this.lastMetaMessage,
      lastGeminiMessage: lastGeminiMessage ?? this.lastGeminiMessage,
      language: language ?? this.language,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      isMetaInboxEnabled: isMetaInboxEnabled ?? this.isMetaInboxEnabled,
      isMetaCommentsEnabled: isMetaCommentsEnabled ?? this.isMetaCommentsEnabled,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      supabaseUrl: json['supabaseUrl'],
      supabaseAnonKey: json['supabaseAnonKey'],
      backendUrl: json['backendUrl'],
      metaToken: json['metaToken'],
      instagramId: json['instagramId'],
      geminiApiKey: json['geminiApiKey'],
      openAiApiKey: json['openAiApiKey'],
      openRouterApiKey: json['openRouterApiKey'],
      selectedAiProvider: json['selectedAiProvider'] ?? 'gemini',
      selectedTextModel: json['selectedTextModel'],
      selectedImageModel: json['selectedImageModel'],
      selectedVideoModel: json['selectedVideoModel'],
      availableModels: (json['availableModels'] as List? ?? [])
          .map((m) => AiModel.fromJson(m))
          .toList(),
      lastModelsRefreshAt: json['lastModelsRefreshAt'] != null
          ? DateTime.tryParse(json['lastModelsRefreshAt'])
          : null,
      language: json['language'] ?? 'en',
      selectedTheme: json['selectedTheme'] ?? 'midnight',
      isMetaInboxEnabled: json['isMetaInboxEnabled'] ?? false,
      isMetaCommentsEnabled: json['isMetaCommentsEnabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'supabaseUrl': supabaseUrl,
        'supabaseAnonKey': supabaseAnonKey,
        'backendUrl': backendUrl,
        'metaToken': metaToken,
        'instagramId': instagramId,
        'geminiApiKey': geminiApiKey,
        'openAiApiKey': openAiApiKey,
        'openRouterApiKey': openRouterApiKey,
        'selectedAiProvider': selectedAiProvider,
        'selectedTextModel': selectedTextModel,
        'selectedImageModel': selectedImageModel,
        'selectedVideoModel': selectedVideoModel,
        'availableModels': availableModels.map((m) => m.toJson()).toList(),
        'lastModelsRefreshAt': lastModelsRefreshAt?.toIso8601String(),
        'language': language,
        'selectedTheme': selectedTheme,
        'isMetaInboxEnabled': isMetaInboxEnabled,
        'isMetaCommentsEnabled': isMetaCommentsEnabled,
      };
}
