import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../services/settings_service.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _awaitingEmailConfirmation = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validate(String lang) {
    final name = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (name.isEmpty) return S.tr('fullNameRequired', lang);
    if (email.isEmpty) return S.tr('emailRequired', lang);
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return S.tr('invalidEmail', lang);
    }
    if (password.length < 6) return S.tr('passwordLength', lang);
    if (password != confirm) return S.tr('passwordsNotMatch', lang);
    return null;
  }

  Future<void> _signUp(String lang) async {
    final validationError = _validate(lang);
    if (validationError != null) {
      setState(() => _errorMessage = validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {'full_name': _fullNameController.text.trim()},
      );

      if (!mounted) return;

      if (response.session != null) {
        // Email confirmation is disabled in Supabase — user is signed in immediately.
        // GoRouter's refreshListenable will redirect to /dashboard automatically.
      } else {
        // Email confirmation required before the session is created.
        setState(() => _awaitingEmailConfirmation = true);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _errorMessage = S.tr('signUpFailed', lang));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.tr('signUp', lang)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: _awaitingEmailConfirmation
                ? _buildConfirmationView(lang, primaryColor)
                : _buildFormView(lang, primaryColor),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationView(String lang, Color primaryColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.mark_email_read_outlined, size: 80, color: primaryColor),
        const SizedBox(height: 24),
        Text(
          S.tr('checkEmail', lang),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          S.tr('emailSentMsg', lang).replaceFirst('{email}', _emailController.text.trim()),
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, height: 1.5),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => context.go('/login'),
            child: Text(S.tr('backToLogin', lang)),
          ),
        ),
      ],
    );
  }

  Widget _buildFormView(String lang, Color primaryColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person_add_outlined, size: 60, color: primaryColor),
        const SizedBox(height: 16),
        Text(
          S.tr('signUp', lang).toUpperCase(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _fullNameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: S.tr('fullName', lang),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: S.tr('email', lang),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: S.tr('password', lang),
            prefixIcon: const Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          onSubmitted: (_) => _signUp(lang),
          decoration: InputDecoration(
            labelText: S.tr('confirmPassword', lang),
            prefixIcon: const Icon(Icons.lock_person_outlined),
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
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () => _signUp(lang),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : Text(S.tr('signUp', lang)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => context.go('/login'),
          child: Text(S.tr('alreadyHaveAccount', lang)),
        ),
      ],
    );
  }
}
