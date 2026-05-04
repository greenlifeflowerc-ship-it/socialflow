import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/scheduled_post.dart';
import '../../../models/social_account.dart';
import '../../../services/accounts_service.dart';
import '../../../services/media_service.dart';
import '../../../services/post_service.dart';
import '../../../services/settings_service.dart';
import '../../direct_management/models/direct_instagram_profile.dart';
import '../../direct_management/providers/direct_profiles_provider.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Root screen
// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;
    final directProfilesAsync = ref.watch(directProfilesProvider);
    // socialAccountsProvider → GET /api/accounts — used for the header display.
    final socialAccountsAsync = ref.watch(socialAccountsProvider);
    final postsAsync = ref.watch(postsProvider);
    final mediaCount = ref.watch(mediaProvider).length;
    final gold = Theme.of(context).colorScheme.primary;

    // ── counts ─────────────────────────────────────────────────────────────
    final posts = postsAsync.asData?.value ?? [];
    final scheduledCount =
        posts.where((p) => p.status == PostStatus.scheduled).length;
    final publishedCount =
        posts.where((p) => p.status == PostStatus.published).length;
    final failedCount =
        posts.where((p) => p.status == PostStatus.failed).length;

    // ── upcoming: next 5 scheduled posts sorted by scheduledAt ─────────────
    final upcoming = [...posts.where(
      (p) =>
          p.status == PostStatus.scheduled &&
          p.scheduledAt != null &&
          p.scheduledAt!.isAfter(DateTime.now()),
    )]..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));
    final upcomingSlice = upcoming.take(5).toList();

    // ── recent: last 5 posts by updatedAt / createdAt ──────────────────────
    final recent = [...posts]..sort((a, b) {
        final ta = a.updatedAt ?? a.createdAt ?? DateTime(0);
        final tb = b.updatedAt ?? b.createdAt ?? DateTime(0);
        return tb.compareTo(ta);
      });
    final recentSlice = recent.take(5).toList();

    // ── connected account (for header) ─────────────────────────────────────
    // Use socialAccountsProvider (GET /api/accounts) — pick first active one.
    // directProfilesProvider is still used for the Insights route ID only.

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: gold,
        onRefresh: () async {
          ref.invalidate(postsProvider);
          ref.invalidate(directProfilesProvider);
          ref.invalidate(socialAccountsProvider);
          ref.read(mediaProvider.notifier).refresh();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            return CustomScrollView(
              slivers: [
                // ── App Bar ──────────────────────────────────────────────
                _DashAppBar(
                  lang: lang,
                  socialAccountsAsync: socialAccountsAsync,
                  onRefresh: () {
                    ref.invalidate(postsProvider);
                    ref.invalidate(directProfilesProvider);
                    ref.invalidate(socialAccountsProvider);
                    ref.read(mediaProvider.notifier).refresh();
                  },
                  onCreatePost: () => context.go('/media'),
                ),
                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 28 : 16,
                    vertical: 20,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Hero action card ──────────────────────────────
                      _HeroActionCard(lang: lang),
                      const SizedBox(height: 28),

                      // ── KPI grid ──────────────────────────────────────
                      _SectionLabel(label: S.tr('overview', lang)),
                      const SizedBox(height: 12),
                      _KpiGrid(
                        isWide: isWide,
                        postsAsync: postsAsync,
                        mediaCount: mediaCount,
                        scheduledCount: scheduledCount,
                        publishedCount: publishedCount,
                        failedCount: failedCount,
                        lang: lang,
                      ),
                      const SizedBox(height: 28),

                      // ── Quick Actions ─────────────────────────────────
                      _SectionLabel(label: S.tr('quickActions', lang)),
                      const SizedBox(height: 12),
                      _QuickActionsGrid(
                        isWide: isWide,
                        lang: lang,
                        profilesAsync: directProfilesAsync,
                      ),
                      const SizedBox(height: 28),

                      // ── Wide: recent + upcoming side by side ──────────
                      if (isWide) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _RecentActivitySection(
                                  posts: recentSlice),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _UpcomingSection(
                                  posts: upcomingSlice),
                            ),
                          ],
                        ),
                      ] else ...[
                        _RecentActivitySection(
                            posts: recentSlice),
                        const SizedBox(height: 28),
                        _UpcomingSection(posts: upcomingSlice),
                      ],
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Bar
// ─────────────────────────────────────────────────────────────────────────────
class _DashAppBar extends StatelessWidget {
  final String lang;
  final AsyncValue<List<SocialAccount>> socialAccountsAsync;
  final VoidCallback onRefresh;
  final VoidCallback onCreatePost;

  const _DashAppBar({
    required this.lang,
    required this.socialAccountsAsync,
    required this.onRefresh,
    required this.onCreatePost,
  });

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;

    // Resolve subtitle: loading / connected account / no account
    final String subtitle;
    final bool hasAccount;
    if (socialAccountsAsync is AsyncLoading) {
      subtitle = S.tr('loadingAccount', lang);
      hasAccount = false;
    } else {
      final accounts = socialAccountsAsync.asData?.value ?? [];
      // Prefer first active/connected account
      final active = accounts.where((a) => a.isActive).toList();
      if (active.isNotEmpty) {
        subtitle = active.first.displayName;
        hasAccount = true;
      } else {
        subtitle = S.tr('connectInstagram', lang);
        hasAccount = false;
      }
    }

    return SliverAppBar(
      pinned: true,
      expandedHeight: 0,
      backgroundColor: surface,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: gold.withOpacity(0.18)),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            S.tr('dashboard', lang).toUpperCase(),
            style: TextStyle(
              color: gold,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: TextStyle(
              color: hasAccount ? Colors.white70 : Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: Icon(Icons.refresh_rounded, color: gold, size: 22),
          onPressed: onRefresh,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12, left: 2),
          child: TextButton.icon(
            onPressed: onCreatePost,
            style: TextButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text(S.tr('create', lang),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: gold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero action card
// ─────────────────────────────────────────────────────────────────────────────
class _HeroActionCard extends StatelessWidget {
  final String lang;
  const _HeroActionCard({required this.lang});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withOpacity(0.25)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gold.withOpacity(0.08),
            surface,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: gold.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.tr('createScheduleTitle', lang),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  S.tr('createScheduleSub', lang),
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _HeroBtn(
                      label: S.tr('createPost', lang),
                      isPrimary: true,
                      onTap: () => context.go('/media'),
                    ),
                    const SizedBox(width: 10),
                    _HeroBtn(
                      label: S.tr('viewCalendar', lang),
                      isPrimary: false,
                      onTap: () => context.go('/calendar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(Icons.auto_awesome_rounded, color: gold.withOpacity(0.35), size: 52),
        ],
      ),
    );
  }
}

class _HeroBtn extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;
  const _HeroBtn({required this.label, required this.isPrimary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    if (isPrimary) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: gold,
        side: BorderSide(color: gold.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      child: Text(label),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI grid
// ─────────────────────────────────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  final bool isWide;
  final AsyncValue<List<ScheduledPost>> postsAsync;
  final int mediaCount, scheduledCount, publishedCount, failedCount;
  final String lang;

  const _KpiGrid({
    required this.isWide,
    required this.postsAsync,
    required this.mediaCount,
    required this.scheduledCount,
    required this.publishedCount,
    required this.failedCount,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = postsAsync is AsyncLoading;
    final kpis = [
      _KpiDef(
        icon: Icons.perm_media_outlined,
        label: S.tr('totalMedia', lang),
        value: mediaCount.toString(),
        hint: S.tr('filesInLibrary', lang),
        iconColor: Colors.blueAccent,
      ),
      _KpiDef(
        icon: Icons.schedule_rounded,
        label: S.tr('scheduled', lang),
        value: isLoading ? '—' : scheduledCount.toString(),
        hint: S.tr('queuedPosts', lang),
        iconColor: Colors.orangeAccent,
      ),
      _KpiDef(
        icon: Icons.check_circle_outline_rounded,
        label: S.tr('published', lang),
        value: isLoading ? '—' : publishedCount.toString(),
        hint: S.tr('postsLive', lang),
        iconColor: Colors.greenAccent,
      ),
      _KpiDef(
        icon: Icons.error_outline_rounded,
        label: S.tr('failed', lang),
        value: isLoading ? '—' : failedCount.toString(),
        hint: S.tr('needAttention', lang),
        iconColor: Colors.redAccent,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 4 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isWide ? 1.7 : 1.6,
      ),
      itemCount: kpis.length,
      itemBuilder: (_, i) => _KpiCard(def: kpis[i], isLoading: isLoading),
    );
  }
}

class _KpiDef {
  final IconData icon;
  final String label, value, hint;
  final Color iconColor;
  const _KpiDef({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
    required this.iconColor,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiDef def;
  final bool isLoading;
  const _KpiCard({required this.def, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.18),
              blurRadius: 8, offset: const Offset(0, 3))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: def.iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(def.icon, color: def.iconColor, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isLoading
                  ? Container(
                      width: 36, height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ))
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        def.value,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
              const SizedBox(height: 2),
              Text(def.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActionsGrid extends StatelessWidget {
  final bool isWide;
  final String lang;
  final AsyncValue<List<DirectInstagramProfile>> profilesAsync;

  const _QuickActionsGrid({
    required this.isWide,
    required this.lang,
    required this.profilesAsync,
  });

  @override
  Widget build(BuildContext context) {
    final profiles = profilesAsync.asData?.value ?? [];
    final hasProfile = profiles.isNotEmpty;

    String insightsRoute() {
      if (!hasProfile) return '/settings/instagram-accounts';
      final id = profiles.first.igBusinessAccountId;
      return id.isNotEmpty
          ? '/dashboard/insights/$id'
          : '/dashboard/insights';
    }

    final actions = [
      _ActionDef(
        icon: Icons.cloud_upload_outlined,
        title: S.tr('uploadMedia', lang),
        subtitle: S.tr('uploadMediaDesc', lang),
        route: '/media',
      ),
      _ActionDef(
        icon: Icons.grid_view_rounded,
        title: S.tr('viewPosts', lang),
        subtitle: S.tr('viewPostsDesc', lang),
        route: '/posts',
      ),
      _ActionDef(
        icon: Icons.calendar_month_outlined,
        title: S.tr('calendar', lang),
        subtitle: S.tr('calendarDesc', lang),
        route: '/calendar',
      ),
      _ActionDef(
        icon: Icons.insights_rounded,
        title: S.tr('viewInsights', lang),
        subtitle: hasProfile
            ? 'Analytics for @${profiles.first.username ?? profiles.first.igBusinessAccountId}'
            : S.tr('noAccountInsights', lang),
        route: insightsRoute(),
        muted: !hasProfile,
      ),
      _ActionDef(
        icon: Icons.comment_outlined,
        title: S.tr('comments', lang),
        subtitle: S.tr('commentsDesc', lang),
        route: '/comments',
      ),
      _ActionDef(
        icon: Icons.inbox_rounded,
        title: S.tr('inbox', lang),
        subtitle: S.tr('inboxDesc', lang),
        route: '/inbox',
      ),
      _ActionDef(
        icon: Icons.smart_toy_outlined,
        title: S.tr('autoReply', lang),
        subtitle: S.tr('autoReplyDesc', lang),
        route: '/auto-reply',
      ),
      _ActionDef(
        icon: Icons.settings_outlined,
        title: S.tr('settings', lang),
        subtitle: S.tr('settingsDesc', lang),
        route: '/settings',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 2 : 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 68,
      ),
      itemCount: actions.length,
      itemBuilder: (_, i) => _ActionTile(def: actions[i]),
    );
  }
}

class _ActionDef {
  final IconData icon;
  final String title, subtitle, route;
  final bool muted;
  const _ActionDef({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.muted = false,
  });
}

class _ActionTile extends StatelessWidget {
  final _ActionDef def;
  const _ActionTile({required this.def});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(def.route),
        splashColor: gold.withOpacity(0.08),
        highlightColor: gold.withOpacity(0.04),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: gold.withOpacity(0.1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: def.muted
                      ? Colors.white.withOpacity(0.04)
                      : gold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(def.icon,
                    color: def.muted ? Colors.white30 : gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(def.title,
                        style: TextStyle(
                          color: def.muted ? Colors.white38 : Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        )),
                    const SizedBox(height: 2),
                    Text(def.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18,
                  color: def.muted ? Colors.white12 : gold.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent Activity
// ─────────────────────────────────────────────────────────────────────────────
class _RecentActivitySection extends ConsumerWidget {
  final List<ScheduledPost> posts;
  const _RecentActivitySection({required this.posts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: S.tr('recentActivity', lang)),
        const SizedBox(height: 12),
        if (posts.isEmpty)
          _EmptyCard(
            icon: Icons.history_rounded,
            message: S.tr('noRecentActivity', lang),
            sub: S.tr('latestPostsHere', lang),
          )
        else
          ...posts.map((p) => _PostRow(post: p, isUpcoming: false)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Upcoming Schedule
// ─────────────────────────────────────────────────────────────────────────────
class _UpcomingSection extends ConsumerWidget {
  final List<ScheduledPost> posts;
  const _UpcomingSection({required this.posts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: S.tr('upcomingSchedule', lang)),
        const SizedBox(height: 12),
        if (posts.isEmpty)
          _EmptyCard(
            icon: Icons.event_note_rounded,
            message: S.tr('noUpcomingPosts', lang),
            sub: S.tr('scheduleNextPost', lang),
          )
        else
          ...posts.map((p) => _PostRow(post: p, isUpcoming: true)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post row (shared by Recent + Upcoming)
// ─────────────────────────────────────────────────────────────────────────────
class _PostRow extends ConsumerWidget {
  final ScheduledPost post;
  final bool isUpcoming;
  const _PostRow({required this.post, required this.isUpcoming});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;

    final (statusColor, statusIcon, statusLabel) = _statusMeta(post.status, lang);
    final dateStr = _fmtDate(isUpcoming ? post.scheduledAt : (post.updatedAt ?? post.createdAt));
    final caption = (post.caption?.isNotEmpty == true)
        ? post.caption!
        : S.tr('noCaption', lang);
    final thumb = post.imageUrl ?? post.mediaUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          // thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
            child: SizedBox(
              width: 58, height: 64,
              child: thumb != null && thumb.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: thumb,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _thumbPlaceholder(post),
                    )
                  : _thumbPlaceholder(post),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusLabel,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                      if (dateStr != null) ...[
                        Text('  ·  ',
                            style: const TextStyle(
                                color: Colors.white24, fontSize: 11)),
                        Text(dateStr,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 11)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder(ScheduledPost p) {
    final icon = p.mediaType.name == 'video'
        ? Icons.videocam_rounded
        : Icons.image_rounded;
    return Container(
      color: Colors.white.withOpacity(0.05),
      child: Center(child: Icon(icon, color: Colors.white24, size: 24)),
    );
  }

  (Color, IconData, String) _statusMeta(PostStatus s, String lang) {
    switch (s) {
      case PostStatus.scheduled:
        return (Colors.orangeAccent, Icons.schedule_rounded, S.tr('statusScheduled', lang));
      case PostStatus.published:
        return (Colors.greenAccent, Icons.check_circle_outline_rounded, S.tr('statusPublished', lang));
      case PostStatus.failed:
        return (Colors.redAccent, Icons.error_outline_rounded, S.tr('statusFailed', lang));
      case PostStatus.publishing:
        return (Colors.blueAccent, Icons.upload_rounded, S.tr('statusPublishing', lang));
      case PostStatus.approved:
        return (Colors.tealAccent, Icons.thumb_up_alt_outlined, S.tr('statusApproved', lang));
      case PostStatus.caption_ready:
        return (Colors.purpleAccent, Icons.edit_note_rounded, S.tr('statusCaptionReady', lang));
      default:
        return (Colors.white38, Icons.drafts_outlined, S.tr('statusDraft', lang));
    }
  }

  String? _fmtDate(DateTime? dt) {
    if (dt == null) return null;
    return DateFormat('MMM d, HH:mm').format(dt);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty card
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message, sub;
  const _EmptyCard({required this.icon, required this.message, required this.sub});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white12, size: 36),
          const SizedBox(height: 10),
          Text(message,
              style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5)),
          const SizedBox(height: 4),
          Text(sub,
              style: const TextStyle(color: Colors.white30, fontSize: 12)),
        ],
      ),
    );
  }
}
