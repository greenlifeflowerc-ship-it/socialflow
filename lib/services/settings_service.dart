import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/app_settings.dart';

class SettingsService {
  final _storage = const FlutterSecureStorage();
  static const _keySettings = 'app_settings';

  Future<AppSettings> loadSettings() async {
    final jsonString = await _storage.read(key: _keySettings);
    if (jsonString != null) {
      try {
        return AppSettings.fromJson(json.decode(jsonString));
      } catch (e) {
        return AppSettings();
      }
    }
    return AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    final jsonString = json.encode(settings.toJson());
    await _storage.write(key: _keySettings, value: jsonString);
  }
}

final settingsServiceProvider = Provider((ref) => SettingsService());

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(settingsServiceProvider));
});

/// Convenient derived provider — any widget can watch this to get the current language code.
final languageProvider = Provider<String>((ref) => ref.watch(settingsProvider).language);

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsService _service;

  SettingsNotifier(this._service) : super(AppSettings()) {
    load();
  }

  Future<AppSettings> load() async {
    state = await _service.loadSettings();
    return state;
  }

  Future<void> save(AppSettings settings) async {
    await _service.saveSettings(settings);
    state = settings;
  }
  
  void updateState(AppSettings newState) {
    state = newState;
  }
}
