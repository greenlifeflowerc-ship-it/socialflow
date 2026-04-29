import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../services/settings_service.dart';

class AiStudioScreen extends ConsumerWidget {
  const AiStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(S.tr('aiStudio', lang).toUpperCase()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/media'),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 800;
          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: isDesktop ? 4 : 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildStudioCard(
                context,
                title: S.tr('aiChat', lang),
                icon: Icons.chat_bubble_outline,
                color: Colors.blue,
                onTap: () => context.push('/ai/chat'),
              ),
              _buildStudioCard(
                context,
                title: S.tr('singleEdit', lang),
                icon: Icons.image_outlined,
                color: Colors.purple,
                onTap: () => context.push('/ai/single-edit'),
              ),
              _buildStudioCard(
                context,
                title: S.tr('bulkEdit', lang),
                icon: Icons.photo_library_outlined,
                color: Colors.orange,
                onTap: () => context.push('/ai/bulk-edit'),
              ),
              _buildStudioCard(
                context,
                title: S.tr('editHistory', lang),
                icon: Icons.history,
                color: Colors.green,
                onTap: () => context.push('/ai/history'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudioCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shadowColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title, 
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

