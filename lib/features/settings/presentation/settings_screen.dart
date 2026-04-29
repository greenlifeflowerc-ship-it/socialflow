import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/settings_service.dart';
import '../../../core/l10n/app_strings.dart';
import 'configurations_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;

    return Scaffold(
      appBar: AppBar(title: Text(S.tr('settings', lang))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(title: S.tr('configurations', lang)),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_suggest),
              title: Text(S.tr('configurations', lang)),
              subtitle: Text(S.tr('backendAiMeta', lang)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConfigurationsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(title: S.tr('appearance', lang)),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(S.tr('language', lang)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LangButton(
                        label: 'English',
                        isSelected: lang == 'en',
                        onTap: () => _updateLang(ref, 'en'),
                      ),
                      const SizedBox(width: 8),
                      _LangButton(
                        label: 'العربية',
                        isSelected: lang == 'ar',
                        onTap: () => _updateLang(ref, 'ar'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.palette),
                  title: Text(S.tr('theme', lang)),
                  subtitle: Text(_getThemeName(settings.selectedTheme, lang)),
                  onTap: () => _showThemePicker(context, ref, settings.selectedTheme, lang),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            label: Text(S.tr('logout', lang), style: const TextStyle(color: Colors.redAccent)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.redAccent),
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Supabase.instance.client.auth.signOut(),
          ),
        ],
      ),
    );
  }

  void _updateLang(WidgetRef ref, String lang) {
    final current = ref.read(settingsProvider);
    ref.read(settingsProvider.notifier).save(current.copyWith(language: lang));
  }

  String _getThemeName(String theme, String lang) {
    switch (theme) {
      case 'ocean': return S.tr('themeOcean', lang);
      case 'amethyst': return S.tr('themeAmethyst', lang);
      case 'emerald': return S.tr('themeEmerald', lang);
      default: return S.tr('themeMidnight', lang);
    }
  }

  void _showThemePicker(BuildContext context, WidgetRef ref, String currentTheme, String lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(S.tr('theme', lang), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _ThemeOption(
              label: S.tr('themeMidnight', lang),
              color: const Color(0xFFD4AF37),
              isSelected: currentTheme == 'midnight',
              onTap: () => _updateTheme(ref, 'midnight', context),
            ),
            _ThemeOption(
              label: S.tr('themeOcean', lang),
              color: const Color(0xFF29B6F6),
              isSelected: currentTheme == 'ocean',
              onTap: () => _updateTheme(ref, 'ocean', context),
            ),
            _ThemeOption(
              label: S.tr('themeAmethyst', lang),
              color: const Color(0xFFCE93D8),
              isSelected: currentTheme == 'amethyst',
              onTap: () => _updateTheme(ref, 'amethyst', context),
            ),
            _ThemeOption(
              label: S.tr('themeEmerald', lang),
              color: const Color(0xFF66BB6A),
              isSelected: currentTheme == 'emerald',
              onTap: () => _updateTheme(ref, 'emerald', context),
            ),
          ],
        ),
      ),
    );
  }

  void _updateTheme(WidgetRef ref, String theme, BuildContext context) {
    final current = ref.read(settingsProvider);
    ref.read(settingsProvider.notifier).save(current.copyWith(selectedTheme: theme));
    Navigator.pop(context);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, right: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _LangButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.transparent,
          border: Border.all(color: isSelected ? primary : Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  const _ThemeOption({required this.label, required this.color, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color, radius: 12),
      title: Text(label),
      trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
      onTap: onTap,
    );
  }
}
