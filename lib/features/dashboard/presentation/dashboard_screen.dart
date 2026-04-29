import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/scheduled_post.dart';
import '../../../services/media_service.dart';
import '../../../services/post_service.dart';
import '../../../services/settings_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediaCount = ref.watch(mediaProvider).length;
    final posts = ref.watch(postsProvider).asData?.value ?? [];
    final scheduledCount = posts.where((p) => p.status == PostStatus.scheduled).length;
    final publishedCount = posts.where((p) => p.status == PostStatus.published).length;
    final failedCount = posts.where((p) => p.status == PostStatus.failed).length;

    final settings = ref.watch(settingsProvider);
    final lang = settings.language;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 2 : 4;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.tr('dashboard', lang).toUpperCase()),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: crossAxisCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.8,
            children: [
              _buildCountCard(context, S.tr('totalMedia', lang), mediaCount.toString(), Icons.perm_media),
              _buildCountCard(context, S.tr('scheduled', lang), scheduledCount.toString(), Icons.schedule),
              _buildCountCard(context, S.tr('published', lang), publishedCount.toString(), Icons.check_circle_outline),
              _buildCountCard(context, S.tr('failed', lang), failedCount.toString(), Icons.error_outline),
            ],
          ),
          const SizedBox(height: 32),
          _buildSectionHeader(context, S.tr('quickActions', lang)),
          const SizedBox(height: 8),
          _buildActionCard(context, title: S.tr('uploadMedia', lang), icon: Icons.cloud_upload_outlined, onTap: () => context.go('/media')),
          _buildActionCard(context, title: S.tr('viewPosts', lang), icon: Icons.grid_view, onTap: () => context.go('/posts')),
          _buildActionCard(context, title: S.tr('calendar', lang), icon: Icons.calendar_today_outlined, onTap: () => context.go('/calendar')),
          _buildActionCard(context, title: S.tr('settings', lang), icon: Icons.settings_outlined, onTap: () => context.go('/settings')),
        ],
      ),
    );
  }

  Widget _buildCountCard(BuildContext context, String title, String count, IconData icon) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              bottom: -10,
              child: Icon(icon, size: 60, color: primaryColor.withOpacity(0.05)),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
                  const SizedBox(height: 2),
                  Text(title, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(left: 4, right: 4),
        child: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 14,
          ),
        ),
      );

  Widget _buildActionCard(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primaryColor.withOpacity(0.1)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Icon(icon, color: primaryColor),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: Icon(Icons.chevron_right, size: 20, color: primaryColor.withOpacity(0.5)),
          onTap: onTap,
        ),
      ),
    );
  }
}
