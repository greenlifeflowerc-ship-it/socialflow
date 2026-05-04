import 'ai_model.dart';
import 'brand_profile.dart';

class AppSettings {
  // AI Settings (persisted – user's own AI provider keys)
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
  final bool instagramConnected;
  final String lastBackendMessage;
  final String lastInstagramMessage;

  // Appearance (persisted)
  final String language;
  final String selectedTheme;

  // Sync preferences (persisted)
  final bool isMetaInboxEnabled;
  final bool isMetaCommentsEnabled;

  // AI Brand Profile (persisted)
  final BrandProfile brandProfile;

  AppSettings({
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
    this.instagramConnected = false,
    this.lastBackendMessage = 'Not tested',
    this.lastInstagramMessage = 'Not connected',
    this.language = 'en',
    this.selectedTheme = 'midnight',
    this.isMetaInboxEnabled = false,
    this.isMetaCommentsEnabled = false,
    BrandProfile? brandProfile,
  }) : brandProfile = brandProfile ?? const BrandProfile();

  AppSettings copyWith({
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
    bool? instagramConnected,
    String? lastBackendMessage,
    String? lastInstagramMessage,
    String? language,
    String? selectedTheme,
    bool? isMetaInboxEnabled,
    bool? isMetaCommentsEnabled,
    BrandProfile? brandProfile,
  }) {
    return AppSettings(
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
      instagramConnected: instagramConnected ?? this.instagramConnected,
      lastBackendMessage: lastBackendMessage ?? this.lastBackendMessage,
      lastInstagramMessage: lastInstagramMessage ?? this.lastInstagramMessage,
      language: language ?? this.language,
      selectedTheme: selectedTheme ?? this.selectedTheme,
      isMetaInboxEnabled: isMetaInboxEnabled ?? this.isMetaInboxEnabled,
      isMetaCommentsEnabled: isMetaCommentsEnabled ?? this.isMetaCommentsEnabled,
      brandProfile: brandProfile ?? this.brandProfile,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      geminiApiKey: json['geminiApiKey'] as String?,
      openAiApiKey: json['openAiApiKey'] as String?,
      openRouterApiKey: json['openRouterApiKey'] as String?,
      selectedAiProvider: json['selectedAiProvider'] as String? ?? 'gemini',
      selectedTextModel: json['selectedTextModel'] as String?,
      selectedImageModel: json['selectedImageModel'] as String?,
      selectedVideoModel: json['selectedVideoModel'] as String?,
      availableModels: (json['availableModels'] as List? ?? [])
          .map((m) => AiModel.fromJson(m as Map<String, dynamic>))
          .toList(),
      lastModelsRefreshAt: json['lastModelsRefreshAt'] != null
          ? DateTime.tryParse(json['lastModelsRefreshAt'].toString())
          : null,
      language: json['language'] as String? ?? 'en',
      selectedTheme: json['selectedTheme'] as String? ?? 'midnight',
      isMetaInboxEnabled: json['isMetaInboxEnabled'] as bool? ?? false,
      isMetaCommentsEnabled: json['isMetaCommentsEnabled'] as bool? ?? false,
      brandProfile: json['brandProfile'] != null
          ? BrandProfile.fromJson(json['brandProfile'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
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
        'brandProfile': brandProfile.toJson(),
      };
}
