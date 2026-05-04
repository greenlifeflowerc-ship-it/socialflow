import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/media_asset.dart';
import '../../../models/scheduled_post.dart';
import '../../../services/post_service.dart';
import '../../../services/settings_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────
final postFilterProvider = StateProvider<PostStatus?>((ref) => null);
final postSearchProvider = StateProvider<String>((ref) => '');

final filteredPostsProvider = Provider<List<ScheduledPost>>((ref) {
  final filter = ref.watch(postFilterProvider);
  final search = ref.watch(postSearchProvider).toLowerCase().trim();
  final all = ref.watch(postsProvider).asData?.value ?? [];

  var result = filter == null
      ? List<ScheduledPost>.from(all)
      : all.where((p) => p.status == filter).toList();

  if (search.isNotEmpty) {
    result = result
        .where((p) => (p.caption ?? '').toLowerCase().contains(search))
        .toList();
  }

  result.sort((a, b) {
    final ta = a.updatedAt ?? a.createdAt ?? DateTime(0);
    final tb = b.updatedAt ?? b.createdAt ?? DateTime(0);
    return tb.compareTo(ta);
  });

  return result;
});

// ─────────────────────────────────────────────────────────────────────────────
// Root screen
// ─────────────────────────────────────────────────────────────────────────────
class PostsScreen extends ConsumerWidget {
  const PostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final postsAsync = ref.watch(postsProvider);
    final gold = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _PostsAppBar(lang: lang),
          _QuickNavRow(lang: lang),
          _FilterRow(postsAsync: postsAsync, lang: lang),
          _SearchField(lang: lang),
          Expanded(
            child: postsAsync.when(
              loading: () =>
                  Center(child: CircularProgressIndicator(color: gold)),
              error: (err, _) => _ErrorBody(
                message:
                    err.toString().replaceFirst('Exception: ', ''),
                onRetry: () =>
                    ref.read(postsProvider.notifier).fetchPosts(),
              ),
              data: (_) => _PostsList(lang: lang),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App bar
// ─────────────────────────────────────────────────────────────────────────────
class _PostsAppBar extends ConsumerWidget {
  final String lang;
  const _PostsAppBar({required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final top = MediaQuery.of(context).padding.top;

    return Container(
      padding:
          EdgeInsets.only(top: top, left: 16, right: 8, bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        border: Border(
            bottom: BorderSide(color: gold.withValues(alpha: 0.18))),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.tr('posts', lang).toUpperCase(),
                style: TextStyle(
                  color: gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
              Text(
                S.tr('yourContent', lang),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Refresh',
            icon: Icon(Icons.refresh_rounded, color: gold, size: 22),
            onPressed: () =>
                ref.read(postsProvider.notifier).fetchPosts(),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton.icon(
              onPressed: () => context.go('/media'),
              style: TextButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(S.tr('create', lang),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick nav row  (Inbox · Comments · Calendar)
// ─────────────────────────────────────────────────────────────────────────────
class _QuickNavRow extends StatelessWidget {
  final String lang;
  const _QuickNavRow({required this.lang});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;

    final items = [
      (Icons.inbox_rounded, S.tr('inbox', lang), '/inbox'),
      (Icons.comment_outlined, S.tr('comments', lang), '/comments'),
      (Icons.calendar_month_outlined, S.tr('calendar', lang), '/calendar'),
    ];

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: List.generate(items.length, (i) {
          final (icon, label, route) = items[i];
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < items.length - 1 ? 8 : 0),
              child: Material(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.go(route),
                  splashColor: gold.withValues(alpha: 0.08),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: gold.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: gold, size: 16),
                        const SizedBox(width: 6),
                        Text(label,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chips with per-status counts
// ─────────────────────────────────────────────────────────────────────────────
class _FilterRow extends ConsumerWidget {
  final AsyncValue<List<ScheduledPost>> postsAsync;
  final String lang;
  const _FilterRow({required this.postsAsync, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gold = Theme.of(context).colorScheme.primary;
    final currentFilter = ref.watch(postFilterProvider);
    final all = postsAsync.asData?.value ?? [];

    int countFor(PostStatus? s) =>
        s == null ? all.length : all.where((p) => p.status == s).length;

    String labelFor(PostStatus? s) {
      if (s == null) return S.tr('all', lang);
      switch (s) {
        case PostStatus.draft:          return S.tr('statusDraft', lang);
        case PostStatus.caption_ready:  return S.tr('statusCaptionReady', lang);
        case PostStatus.approved:       return S.tr('statusApproved', lang);
        case PostStatus.scheduled:      return S.tr('statusScheduled', lang);
        case PostStatus.publishing:     return S.tr('statusPublishing', lang);
        case PostStatus.published:      return S.tr('statusPublished', lang);
        case PostStatus.failed:         return S.tr('statusFailed', lang);
      }
    }

    final filters = <PostStatus?>[
      null,
      PostStatus.scheduled,
      PostStatus.published,
      PostStatus.failed,
      PostStatus.draft,
      PostStatus.caption_ready,
      PostStatus.approved,
      PostStatus.publishing,
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final f = filters[i];
          final count = countFor(f);
          final selected = currentFilter == f;
          return GestureDetector(
            onTap: () =>
                ref.read(postFilterProvider.notifier).state = f,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? gold
                    : gold.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected
                      ? gold
                      : gold.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                count > 0
                    ? '${labelFor(f)} ($count)'
                    : labelFor(f),
                style: TextStyle(
                  color: selected ? Colors.black : Colors.white70,
                  fontSize: 12,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search field
// ─────────────────────────────────────────────────────────────────────────────
class _SearchField extends ConsumerWidget {
  final String lang;
  const _SearchField({required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search by caption…',
          hintStyle:
              const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Colors.white38, size: 18),
          suffixIcon: Consumer(builder: (ctx, r, _) {
            final q = r.watch(postSearchProvider);
            if (q.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white38, size: 18),
              onPressed: () =>
                  r.read(postSearchProvider.notifier).state = '',
            );
          }),
          filled: true,
          fillColor: surface,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: gold.withValues(alpha: 0.15)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: gold.withValues(alpha: 0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: gold),
          ),
        ),
        onChanged: (v) =>
            ref.read(postSearchProvider.notifier).state = v,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Posts list
// ─────────────────────────────────────────────────────────────────────────────
class _PostsList extends ConsumerWidget {
  final String lang;
  const _PostsList({required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(filteredPostsProvider);
    final filter = ref.watch(postFilterProvider);
    final search = ref.watch(postSearchProvider);

    if (posts.isEmpty) {
      final isFiltered = filter != null || search.isNotEmpty;
      return _EmptyState(
        icon: isFiltered
            ? Icons.filter_list_off_rounded
            : Icons.post_add_rounded,
        title: isFiltered
            ? S.tr('noPostsFilter', lang)
            : 'No posts yet.',
        sub: isFiltered
            ? 'Try a different filter or search term.'
            : 'Create your first scheduled post.',
        showCreate: !isFiltered,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
          left: 16, right: 16, top: 8, bottom: 80),
      itemCount: posts.length,
      itemBuilder: (_, i) =>
          _PostCard(post: posts[i], lang: lang),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post card
// ─────────────────────────────────────────────────────────────────────────────
class _PostCard extends ConsumerStatefulWidget {
  final ScheduledPost post;
  final String lang;
  const _PostCard({required this.post, required this.lang});

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  bool _showError = false;
  bool _working = false;

  ScheduledPost get post => widget.post;
  String get lang => widget.lang;

  Color _statusColor() {
    switch (post.status) {
      case PostStatus.published:     return Colors.greenAccent;
      case PostStatus.scheduled:     return Colors.orangeAccent;
      case PostStatus.approved:      return Colors.lightBlueAccent;
      case PostStatus.failed:        return Colors.redAccent;
      case PostStatus.publishing:    return Colors.purpleAccent;
      case PostStatus.caption_ready: return Colors.tealAccent;
      default:                       return Colors.white38;
    }
  }

  String _statusLabel() {
    switch (post.status) {
      case PostStatus.published:     return S.tr('statusPublished', lang);
      case PostStatus.scheduled:     return S.tr('statusScheduled', lang);
      case PostStatus.failed:        return S.tr('statusFailed', lang);
      case PostStatus.publishing:    return S.tr('statusPublishing', lang);
      case PostStatus.approved:      return S.tr('statusApproved', lang);
      case PostStatus.caption_ready: return S.tr('statusCaptionReady', lang);
      default:                       return S.tr('statusDraft', lang);
    }
  }

  String _dateLabel() {
    final fmt = DateFormat('MMM d, h:mm a');
    switch (post.status) {
      case PostStatus.published:
        return post.publishedAt != null
            ? 'Published · ${fmt.format(post.publishedAt!.toLocal())}'
            : 'Published';
      case PostStatus.scheduled:
        return post.scheduledAt != null
            ? 'Scheduled for · ${fmt.format(post.scheduledAt!.toLocal())}'
            : S.tr('unscheduled', lang);
      case PostStatus.failed:
        return post.scheduledAt != null
            ? 'Failed · ${fmt.format(post.scheduledAt!.toLocal())}'
            : 'Failed';
      default:
        if (post.updatedAt != null) return fmt.format(post.updatedAt!.toLocal());
        if (post.createdAt != null) return fmt.format(post.createdAt!.toLocal());
        return '';
    }
  }

  Future<void> _handleRemove() async {
    // Published posts cannot be cancelled — hide this path entirely (button is
    // not shown for published, but guard here for safety).
    if (post.status == PostStatus.published) return;

    final ok = await _confirmDialog(
      title: 'Remove Post?',
      body:
          'This will remove this post from your queue.\nPublished Instagram posts cannot be deleted from here.',
      confirmLabel: 'Remove',
      confirmColor: Colors.redAccent,
    );
    if (!ok || !mounted) return;

    setState(() => _working = true);
    // Uses POST /api/posts/:id/cancel — the only supported remove route.
    final err =
        await ref.read(postsProvider.notifier).cancelPost(post.id);
    if (!mounted) return;
    setState(() => _working = false);
    err != null
        ? _showSnack(err, isError: true)
        : _showSnack('Post removed.');
  }

  Future<void> _handleRetry() async {
    final ok = await _confirmDialog(
      title: 'Retry Post?',
      body:
          'The system will attempt to publish this post again.',
      confirmLabel: 'Retry',
      confirmColor: Theme.of(context).colorScheme.primary,
    );
    if (!ok || !mounted) return;

    setState(() => _working = true);
    final err =
        await ref.read(postsProvider.notifier).retryPost(post.id);
    if (!mounted) return;
    setState(() => _working = false);
    err != null
        ? _showSnack(err, isError: true)
        : _showSnack('Post queued for retry.');
  }

  Future<void> _handlePublishNow() async {
    if (post.id.isEmpty) {
      _showSnack('Post ID is missing — cannot publish.', isError: true);
      return;
    }

    final ok = await _confirmDialog(
      title: 'Publish Now?',
      body: 'This will immediately publish the post to Instagram.',
      confirmLabel: 'Publish Now',
      confirmColor: Theme.of(context).colorScheme.primary,
    );
    if (!ok || !mounted) return;

    setState(() => _working = true);
    debugPrint('PUBLISH NOW PAYLOAD: {post_id: ${post.id}}');
    final err =
        await ref.read(postsProvider.notifier).publishNow(post.id);
    if (!mounted) return;
    setState(() => _working = false);
    err != null
        ? _showSnack(err, isError: true)
        : _showSnack('Published successfully.');
  }

  Future<bool> _confirmDialog({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            Theme.of(context).cardTheme.color,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(color: Colors.white)),
        content: Text(body,
            style: const TextStyle(
                color: Colors.white70, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.tr('cancel', lang),
                style:
                    const TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel,
                style: TextStyle(
                    color: confirmColor,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    final clean = msg.replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(clean),
      backgroundColor: isError
          ? Colors.redAccent.shade700
          : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    final statusColor = _statusColor();
    final thumb = post.imageUrl ?? post.mediaUrl;
    final isPublished = post.status == PostStatus.published;
    final isFailed = post.status == PostStatus.failed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isFailed
              ? Colors.redAccent.withValues(alpha: 0.25)
              : gold.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main row ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 64, height: 72,
                    child: thumb.isNotEmpty && thumb.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: thumb,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _thumbFallback(),
                          )
                        : _thumbFallback(),
                  ),
                ),
                const SizedBox(width: 12),

                // Caption + date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.caption?.isNotEmpty == true
                            ? post.caption!
                            : S.tr('noCaption', lang),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: post.caption?.isNotEmpty == true
                              ? Colors.white
                              : Colors.white38,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(
                          isPublished
                              ? Icons.check_circle_outline_rounded
                              : isFailed
                                  ? Icons.error_outline_rounded
                                  : Icons.schedule_rounded,
                          size: 12, color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _dateLabel(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Status badge + media type
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                            statusColor.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: statusColor
                                .withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _statusLabel().toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      post.mediaType == MediaType.video
                          ? Icons.videocam_outlined
                          : Icons.image_outlined,
                      color: Colors.white24, size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Error banner for failed posts ─────────────────────────────
          if (isFailed && post.errorMessage != null) ...[
            GestureDetector(
              onTap: () =>
                  setState(() => _showError = !_showError),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.redAccent
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.redAccent
                            .withValues(alpha: 0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 13, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _showError
                            ? post.errorMessage!
                            : post.errorMessage!
                                .split('\n')
                                .first,
                        maxLines: _showError ? 6 : 1,
                        overflow: _showError
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 11),
                      ),
                    ),
                    Icon(
                      _showError
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 14, color: Colors.redAccent,
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── Actions ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_working) ...[
                  SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: gold),
                  ),
                  const SizedBox(width: 12),
                ],
                // Retry (failed only)
                if (isFailed && !_working) ...[
                  _ActionBtn(
                    icon: Icons.replay_rounded,
                    label: S.tr('retry', lang),
                    color: Colors.orangeAccent,
                    onTap: _handleRetry,
                  ),
                  const SizedBox(width: 8),
                ],
                // Publish Now — for scheduled/draft/approved/caption_ready posts
                if (!_working &&
                    !isPublished &&
                    !isFailed &&
                    post.status != PostStatus.publishing) ...[
                  _ActionBtn(
                    icon: Icons.send_rounded,
                    label: S.tr('publishNow', lang),
                    color: Colors.greenAccent,
                    onTap: _handlePublishNow,
                  ),
                  const SizedBox(width: 8),
                ],
                // Remove — only for draft/scheduled/failed/caption_ready/approved
                // Published posts do NOT show Remove.
                if (!_working && !isPublished)
                  _ActionBtn(
                    icon: Icons.delete_outline_rounded,
                    label: 'Remove',
                    color: Colors.redAccent,
                    onTap: _handleRemove,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbFallback() => Container(
        color: Colors.white.withValues(alpha: 0.05),
        child: Center(
          child: Icon(
            post.mediaType == MediaType.video
                ? Icons.videocam_rounded
                : Icons.image_rounded,
            color: Colors.white24, size: 26,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Small action button
// ─────────────────────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final bool showCreate;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.sub,
    this.showCreate = false,
  });

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white12, size: 52),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
            const SizedBox(height: 6),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white30, fontSize: 13)),
            if (showCreate) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.go('/media'),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Create Post'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: Colors.black,
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error body
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 13),
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon:
                  const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.black,
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
