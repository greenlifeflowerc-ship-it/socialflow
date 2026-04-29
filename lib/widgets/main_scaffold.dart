import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/l10n/app_strings.dart';
import '../services/settings_service.dart';

class MainScaffold extends ConsumerWidget {
  final Widget child;

  const MainScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;
    final theme = Theme.of(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _calculateSelectedIndex(context),
          onTap: (index) => _onItemTapped(index, context),
          type: BottomNavigationBarType.fixed,
          backgroundColor: theme.colorScheme.surface,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: theme.disabledColor,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          showUnselectedLabels: true,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
              activeIcon: const Icon(Icons.dashboard),
              label: S.tr('dashboard', lang),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.photo_library_outlined),
              activeIcon: const Icon(Icons.photo_library),
              label: S.tr('media', lang),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.auto_awesome_outlined),
              activeIcon: const Icon(Icons.auto_awesome),
              label: S.tr('aiStudio', lang),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.post_add_outlined),
              activeIcon: const Icon(Icons.post_add),
              label: S.tr('posts', lang),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.smart_toy_outlined),
              activeIcon: const Icon(Icons.smart_toy),
              label: S.tr('autoReply', lang),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month_outlined),
              activeIcon: const Icon(Icons.calendar_month),
              label: S.tr('calendar', lang),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings),
              label: S.tr('settings', lang),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/media')) return 1;
    if (location.startsWith('/ai')) return 2;
    if (location.startsWith('/posts')) return 3;
    if (location.startsWith('/auto-reply')) return 4;
    if (location.startsWith('/calendar')) return 5;
    if (location.startsWith('/settings')) return 6;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/media');
        break;
      case 2:
        context.go('/ai');
        break;
      case 3:
        context.go('/posts');
        break;
      case 4:
        context.go('/auto-reply');
        break;
      case 5:
        context.go('/calendar');
        break;
      case 6:
        context.go('/settings');
        break;
    }
  }
}
