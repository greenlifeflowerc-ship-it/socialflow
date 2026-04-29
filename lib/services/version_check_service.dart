import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionCheckResult {
  final bool needsUpdate;
  final String message;
  final String updateUrl;

  const VersionCheckResult({
    required this.needsUpdate,
    this.message = 'A new version is available. Please update the app to continue.',
    this.updateUrl = '',
  });
}

// Set once in main.dart before runApp. Checked synchronously by GoRouter redirect.
VersionCheckResult appVersionResult = const VersionCheckResult(needsUpdate: false);

Future<void> performVersionCheck(String backendBaseUrl) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final currentBuild = int.tryParse(info.buildNumber) ?? 1;

    final dio = Dio();
    final response = await dio
        .get('$backendBaseUrl/api/app-version')
        .timeout(const Duration(seconds: 4));

    final data = response.data as Map<String, dynamic>;
    final minBuild = (data['minBuildNumber'] as num?)?.toInt() ?? 1;

    if (currentBuild < minBuild) {
      appVersionResult = VersionCheckResult(
        needsUpdate: true,
        message: data['message'] as String? ??
            'A new version is available. Please update the app to continue.',
        updateUrl: data['updateUrl'] as String? ?? '',
      );
    }
  } catch (_) {
    // Network error or backend unavailable — allow the app to proceed.
  }
}
