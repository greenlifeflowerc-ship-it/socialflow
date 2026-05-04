/// SetupScreen is no longer used.
/// Supabase and backend URLs are hardcoded in AppConfig.
/// This file is kept to avoid broken imports.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Redirect to login immediately — setup is no longer needed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/login');
    });
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
