import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../main.dart' show supabaseInitialized;
import '../../../services/settings_service.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _supabaseUrlController = TextEditingController();
  final _supabaseAnonKeyController = TextEditingController();
  final _backendUrlController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _supabaseUrlController.dispose();
    _supabaseAnonKeyController.dispose();
    _backendUrlController.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    final supabaseUrl = _supabaseUrlController.text.trim();
    final supabaseAnonKey = _supabaseAnonKeyController.text.trim();
    String backendUrl = _backendUrlController.text.trim();
    if (backendUrl.endsWith('/')) backendUrl = backendUrl.substring(0, backendUrl.length - 1);

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      setState(() => _errorMessage = 'Supabase URL and Anon Key are required.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      supabaseInitialized = true;

      final settings = await ref.read(settingsProvider.notifier).load();
      await ref.read(settingsProvider.notifier).save(
        settings.copyWith(
          supabaseUrl: supabaseUrl,
          supabaseAnonKey: supabaseAnonKey,
          backendUrl: backendUrl.isNotEmpty ? backendUrl : null,
        ),
      );

      appStateNotifier.onSetupComplete();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Setup failed. Check your Supabase URL and Anon Key.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, size: 64, color: AppTheme.primaryGold),
                const SizedBox(height: 16),
                Text(
                  'Welcome',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connect your own Supabase project and backend to get started.',
                  style: TextStyle(color: AppTheme.textGrey),
                ),
                const SizedBox(height: 32),

                _buildLabel('Supabase URL *'),
                const SizedBox(height: 6),
                TextField(
                  controller: _supabaseUrlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'https://xxxx.supabase.co',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                _buildLabel('Supabase Anon Key *'),
                const SizedBox(height: 6),
                TextField(
                  controller: _supabaseAnonKeyController,
                  obscureText: true,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'eyJhbGciOi...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                _buildLabel('Backend URL (optional)'),
                const SizedBox(height: 6),
                TextField(
                  controller: _backendUrlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'https://your-backend.com',
                    border: OutlineInputBorder(),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _setup,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Text('CONNECT & CONTINUE'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      );
}
