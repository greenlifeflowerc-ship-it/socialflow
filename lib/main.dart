import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'config/app_config.dart';
import 'models/media_asset.dart';
import 'services/version_check_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(MediaAssetAdapter());
  Hive.registerAdapter(MediaTypeAdapter());
  await Hive.openBox<MediaAsset>('mediaLibrary');

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Non-blocking version check — failure is silently ignored.
  await performVersionCheck(AppConfig.backendUrl);

  runApp(const ProviderScope(child: MyApp()));
}
