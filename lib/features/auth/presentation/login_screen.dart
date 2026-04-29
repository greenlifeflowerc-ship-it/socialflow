import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/settings/presentation/configurations_screen.dart';
import '../../../main.dart' show supabaseInitialized;
import '../../../core/l10n/app_strings.dart';
import '../../../services/settings_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login(String lang) async {
    if (!supabaseInitialized) {
      setState(() => _errorMessage = S.tr('supabaseNotConfiguredError', lang));
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = S.tr('enterEmailPassword', lang));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = S.tr('loginFailed', lang));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openConfigurations() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConfigurationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: S.tr('configurations', lang),
            onPressed: _openConfigurations,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [primaryColor, primaryColor.withOpacity(0.5)],
                  ).createShader(bounds),
                  child: const Icon(Icons.auto_awesome, size: 80, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text(
                  'AUTOFLOW',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 40,
                    color: primaryColor,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'SOCIAL SCHEDULER',
                  style: TextStyle(
                    letterSpacing: 4,
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 48),

                if (!supabaseInitialized) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_outlined, color: Colors.amber, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _openConfigurations,
                            child: Text(
                              S.tr('supabaseNotConfigured', lang),
                              style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  onSubmitted: (_) => _login(lang),
                  decoration: InputDecoration(
                    labelText: S.tr('email', lang),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  onSubmitted: (_) => _login(lang),
                  decoration: InputDecoration(
                    labelText: S.tr('password', lang),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _login(lang),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 8,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : Text(S.tr('login', lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => context.go('/signup'),
                  child: Text(
                    S.tr('noAccount', lang),
                    style: TextStyle(color: primaryColor.withOpacity(0.8), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
