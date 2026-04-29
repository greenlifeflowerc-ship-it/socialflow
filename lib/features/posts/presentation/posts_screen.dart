import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/media_asset.dart';
import '../../../models/scheduled_post.dart';
import '../../../services/post_service.dart';
import '../../../services/settings_service.dart';

// State for the filter
final postFilterProvider = StateProvider<PostStatus?>((ref) => null);

final filteredPostsProvider = Provider<List<ScheduledPost>>((ref) {
  final filter = ref.watch(postFilterProvider);
  final posts = ref.watch(postsProvider).asData?.value ?? [];

  if (filter == null) return posts;
  return posts.where((post) => post.status == filter).toList();
});


class PostsScreen extends ConsumerWidget {
  const PostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsyncValue = ref.watch(postsProvider);
    final filteredPosts = ref.watch(filteredPostsProvider);
    final lang = ref.watch(settingsProvider).language;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.tr('posts', lang).toUpperCase()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(postsProvider.notifier).fetchPosts(),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/inbox'),
                    icon: const Icon(Icons.mail),
                    label: Text(S.tr('inbox', lang)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).cardTheme.color,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/comments'),
                    icon: const Icon(Icons.comment),
                    label: Text(S.tr('comments', lang)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).cardTheme.color,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _FilterChips(),
          Expanded(
            child: postsAsyncValue.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (_) {
                if (filteredPosts.isEmpty) {
                  return Center(child: Text(S.tr('noPostsFilter', lang)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: filteredPosts.length,
                  itemBuilder: (context, index) => _PostCard(post: filteredPosts[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(postFilterProvider);
    final lang = ref.watch(settingsProvider).language;

    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ChoiceChip(
            label: Text(S.tr('all', lang)),
            selected: currentFilter == null,
            onSelected: (_) => ref.read(postFilterProvider.notifier).state = null,
          ),
          ...PostStatus.values.map((status) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(_getStatusText(status, lang)),
              selected: currentFilter == status,
              onSelected: (_) => ref.read(postFilterProvider.notifier).state = status,
            ),
          )),
        ],
      ),
    );
  }

  String _getStatusText(PostStatus status, String lang) {
    switch (status) {
      case PostStatus.scheduled: return S.tr('scheduled', lang);
      case PostStatus.published: return S.tr('published', lang);
      case PostStatus.failed: return S.tr('failed', lang);
      default: return status.name;
    }
  }
}

class _PostCard extends ConsumerWidget {
  final ScheduledPost post;
  const _PostCard({required this.post});

  void _confirmDelete(BuildContext context, WidgetRef ref, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.tr('deletePost', lang)),
        content: Text(S.tr('deletePostMsg', lang)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(S.tr('cancel', lang))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(postsProvider.notifier).deletePost(post.id);
            },
            child: Text(S.tr('delete', lang), style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60, height: 60,
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrl ?? post.mediaUrl, 
                      fit: BoxFit.cover, 
                      errorWidget: (c,u,e) => const Icon(Icons.error)
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.caption ?? S.tr('noCaption', lang), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        post.scheduledAt != null 
                          ? '${S.tr('scheduledFor', lang)} ${DateFormat.yMd().add_jm().format(post.scheduledAt!)}' 
                          : S.tr('unscheduled', lang),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  post.mediaType == MediaType.video ? Icons.videocam_outlined : Icons.image_outlined, 
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5)
                ),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusChip(status: post.status),
                Row(
                  children: [
                    TextButton(onPressed: (){}, child: Text(S.tr('edit', lang))),
                    TextButton(
                      onPressed: () => _confirmDelete(context, ref, lang),
                      child: Text(S.tr('delete', lang), style: const TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}


class _StatusChip extends ConsumerWidget {
  final PostStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final color = _getColorForStatus(status);

    return Chip(
      label: Text(_getStatusText(status, lang).toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
      backgroundColor: color.withOpacity(0.15),
      side: BorderSide(color: color.withOpacity(0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  String _getStatusText(PostStatus status, String lang) {
    switch (status) {
      case PostStatus.scheduled: return S.tr('scheduled', lang);
      case PostStatus.published: return S.tr('published', lang);
      case PostStatus.failed: return S.tr('failed', lang);
      default: return status.name;
    }
  }

  Color _getColorForStatus(PostStatus status) {
    switch (status) {
      case PostStatus.published: return Colors.green;
      case PostStatus.scheduled: case PostStatus.approved: return Colors.blueAccent;
      case PostStatus.failed: return Colors.redAccent;
      case PostStatus.publishing: return Colors.purpleAccent;
      default: return Colors.orangeAccent;
    }
  }
}
