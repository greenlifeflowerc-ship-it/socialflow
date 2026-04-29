import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'models/media_asset.dart';
import 'services/settings_service.dart';
import 'services/version_check_service.dart';

bool supabaseInitialized = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(MediaAssetAdapter());
  Hive.registerAdapter(MediaTypeAdapter());
  await Hive.openBox<MediaAsset>('mediaLibrary');

  final settings = await SettingsService().loadSettings();

  final supabaseUrl = settings.supabaseUrl ?? '';
  final supabaseAnonKey = settings.supabaseAnonKey ?? '';

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    supabaseInitialized = true;
  }

  if (settings.backendUrl != null && settings.backendUrl!.isNotEmpty) {
    await performVersionCheck(settings.backendUrl!);
  }

  runApp(const ProviderScope(child: MyApp()));
}
