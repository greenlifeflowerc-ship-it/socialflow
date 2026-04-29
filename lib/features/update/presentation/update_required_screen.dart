import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/version_check_service.dart';

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final result = appVersionResult;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.system_update_alt, size: 80, color: AppTheme.primaryGold),
                  const SizedBox(height: 24),
                  const Text(
                    'UPDATE REQUIRED',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    result.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textGrey, height: 1.5),
                  ),
                  const SizedBox(height: 40),
                  if (result.updateUrl.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('UPDATE NOW'),
                        onPressed: () async {
                          final uri = Uri.parse(result.updateUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    )
                  else
                    const Text(
                      'Please contact support to get the latest version.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textGrey),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
