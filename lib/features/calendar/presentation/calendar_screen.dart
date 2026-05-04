import 'dart:collection';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../models/media_asset.dart';
import '../../../models/scheduled_post.dart';
import '../../../services/accounts_service.dart';
import '../../../services/post_service.dart';
import '../../../services/settings_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers  (data logic unchanged)
// ─────────────────────────────────────────────────────────────────────────────

final postsByDayProvider =
    Provider<LinkedHashMap<DateTime, List<ScheduledPost>>>((ref) {
  final posts = ref.watch(postsProvider).asData?.value ?? [];
  final map = LinkedHashMap<DateTime, List<ScheduledPost>>(
    equals: isSameDay,
    hashCode: (key) =>
        key.day * 1000000 + key.month * 10000 + key.year,
  );
  for (final post in posts) {
    if (post.scheduledAt != null) {
      final day = DateTime.utc(post.scheduledAt!.year,
          post.scheduledAt!.month, post.scheduledAt!.day);
      (map[day] ??= []).add(post);
    }
  }
  return map;
});

/// Filter for the selected-day panel (null = All)
final calFilterProvider = StateProvider<PostStatus?>((ref) => null);

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  // ── helpers ──────────────────────────────────────────────────────────────

  void _onDaySelected(DateTime selected, DateTime focused) {
    if (!isSameDay(_selectedDay, selected)) {
      setState(() {
        _selectedDay = selected;
        _focusedDay = focused;
      });
    }
  }

  void _goToToday() {
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    });
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final postsAsync = ref.watch(postsProvider);
    final postsByDay = ref.watch(postsByDayProvider);
    final accountsAsync = ref.watch(socialAccountsProvider);
    final gold = Theme.of(context).colorScheme.primary;

    // Resolve account subtitle
    final accounts = accountsAsync.asData?.value ?? [];
    final activeAccounts = accounts.where((a) => a.isActive).toList();
    final accountSubtitle = accountsAsync is AsyncLoading
        ? 'Loading…'
        : activeAccounts.isNotEmpty
            ? activeAccounts.first.displayName
            : 'All scheduled content';

    // Monthly stats (posts whose scheduledAt is in the focused month)
    final allPosts = postsAsync.asData?.value ?? [];
    final monthPosts = allPosts.where((p) =>
        p.scheduledAt != null &&
        p.scheduledAt!.year == _focusedDay.year &&
        p.scheduledAt!.month == _focusedDay.month).toList();
    final monthScheduled =
        monthPosts.where((p) => p.status == PostStatus.scheduled).length;
    final monthPublished =
        monthPosts.where((p) => p.status == PostStatus.published).length;
    final monthFailed =
        monthPosts.where((p) => p.status == PostStatus.failed).length;

    // Selected-day events (live from provider)
    final filter = ref.watch(calFilterProvider);
    var dayEvents = postsByDay[_selectedDay] ?? <ScheduledPost>[];
    if (filter != null) {
      dayEvents = dayEvents.where((p) => p.status == filter).toList();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: gold,
        onRefresh: () async =>
            ref.read(postsProvider.notifier).fetchPosts(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            return CustomScrollView(
              slivers: [
                // ── Header ──────────────────────────────────────────────
                _CalAppBar(
                  lang: lang,
                  subtitle: accountSubtitle,
                  hasAccount: activeAccounts.isNotEmpty,
                  focusedDay: _focusedDay,
                  onRefresh: () =>
                      ref.read(postsProvider.notifier).fetchPosts(),
                  onToday: _goToToday,
                  onPrev: () => setState(() {
                    _focusedDay = DateTime(
                        _focusedDay.year, _focusedDay.month - 1);
                  }),
                  onNext: () => setState(() {
                    _focusedDay = DateTime(
                        _focusedDay.year, _focusedDay.month + 1);
                  }),
                ),

                SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 28 : 14,
                    vertical: 16,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Monthly summary ─────────────────────────────
                      if (postsAsync is! AsyncLoading)
                        _MonthlySummary(
                          scheduled: monthScheduled,
                          published: monthPublished,
                          failed: monthFailed,
                        ),
                      if (postsAsync is! AsyncLoading)
                        const SizedBox(height: 16),

                      // ── Calendar card ────────────────────────────────
                      _CalendarCard(
                        focusedDay: _focusedDay,
                        selectedDay: _selectedDay,
                        lang: lang,
                        postsByDay: postsByDay,
                        onDaySelected: _onDaySelected,
                        onPageChanged: (fd) =>
                            setState(() => _focusedDay = fd),
                      ),
                      const SizedBox(height: 20),

                      // ── Filter row ───────────────────────────────────
                      _StatusFilterRow(
                        allDayEvents:
                            postsByDay[_selectedDay] ?? [],
                        lang: lang,
                      ),
                      const SizedBox(height: 12),

                      // ── Wide: day panel full width (calendar is above)
                      // Mobile: day panel below
                      _DayPanel(
                        selectedDay: _selectedDay,
                        events: dayEvents,
                        lang: lang,
                        isLoading: postsAsync is AsyncLoading,
                        onCreatePost: () => context.go('/media'),
                      ),
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
// App bar (SliverAppBar)
// ─────────────────────────────────────────────────────────────────────────────

class _CalAppBar extends StatelessWidget {
  final String lang;
  final String subtitle;
  final bool hasAccount;
  final DateTime focusedDay;
  final VoidCallback onRefresh;
  final VoidCallback onToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _CalAppBar({
    required this.lang,
    required this.subtitle,
    required this.hasAccount,
    required this.focusedDay,
    required this.onRefresh,
    required this.onToday,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final monthLabel =
        DateFormat('MMMM yyyy').format(focusedDay);

    return SliverAppBar(
      pinned: true,
      backgroundColor: surface,
      automaticallyImplyLeading: false,
      elevation: 0,
      expandedHeight: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: gold.withValues(alpha: 0.18)),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'CONTENT CALENDAR',
            style: TextStyle(
              color: gold,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 2,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color:
                  hasAccount ? Colors.white70 : Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
        ],
      ),
      actions: [
        // Month label + nav
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left_rounded,
                  color: gold, size: 22),
              onPressed: onPrev,
              tooltip: 'Previous month',
            ),
            Text(monthLabel,
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            IconButton(
              icon: Icon(Icons.chevron_right_rounded,
                  color: gold, size: 22),
              onPressed: onNext,
              tooltip: 'Next month',
            ),
          ],
        ),
        TextButton(
          onPressed: onToday,
          style: TextButton.styleFrom(
            foregroundColor: gold,
            textStyle: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Today'),
        ),
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: gold, size: 20),
          onPressed: onRefresh,
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Monthly summary KPIs
// ─────────────────────────────────────────────────────────────────────────────

class _MonthlySummary extends StatelessWidget {
  final int scheduled, published, failed;
  const _MonthlySummary({
    required this.scheduled,
    required this.published,
    required this.failed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SummaryChip(
            label: 'Scheduled',
            count: scheduled,
            color: Colors.orangeAccent),
        const SizedBox(width: 8),
        _SummaryChip(
            label: 'Published',
            count: published,
            color: Colors.greenAccent),
        const SizedBox(width: 8),
        _SummaryChip(
            label: 'Failed',
            count: failed,
            color: Colors.redAccent),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip(
      {required this.label,
      required this.count,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18),
                  ),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar card (TableCalendar wrapper)
// ─────────────────────────────────────────────────────────────────────────────

class _CalendarCard extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final String lang;
  final LinkedHashMap<DateTime, List<ScheduledPost>> postsByDay;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onPageChanged;

  const _CalendarCard({
    required this.focusedDay,
    required this.selectedDay,
    required this.lang,
    required this.postsByDay,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: TableCalendar<ScheduledPost>(
          locale: lang == 'ar' ? 'ar_SA' : 'en_US',
          firstDay: DateTime.utc(2020),
          lastDay: DateTime.utc(2030),
          focusedDay: focusedDay,
          selectedDayPredicate: (d) => isSameDay(selectedDay, d),
          onDaySelected: onDaySelected,
          onPageChanged: onPageChanged,
          eventLoader: (day) => postsByDay[day] ?? [],
          // Hide the built-in header — we have our own in the SliverAppBar
          headerVisible: false,
          calendarStyle: CalendarStyle(
            // Today
            todayDecoration: BoxDecoration(
              color: gold.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            todayTextStyle: TextStyle(
                color: gold, fontWeight: FontWeight.w700),
            // Selected
            selectedDecoration: BoxDecoration(
              color: gold,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.w800),
            // Regular
            defaultTextStyle:
                const TextStyle(color: Colors.white70),
            weekendTextStyle:
                TextStyle(color: gold.withValues(alpha: 0.7)),
            outsideDaysVisible: false,
            outsideTextStyle:
                const TextStyle(color: Colors.white24),
            // Disable default markers — we use markerBuilder
            markersMaxCount: 0,
            cellMargin: const EdgeInsets.all(4),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600),
            weekendStyle: TextStyle(
                color: gold.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          calendarBuilders: CalendarBuilders(
            // Custom marker: colored dots by status
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return null;
              // Collect up to 3 distinct status colours
              final seen = <Color>{};
              for (final e in events) {
                seen.add(_dotColor(e.status));
                if (seen.length >= 3) break;
              }
              return Positioned(
                bottom: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: seen
                      .map((c) => Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 1),
                            decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle),
                          ))
                      .toList(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Color _dotColor(PostStatus s) {
    switch (s) {
      case PostStatus.published:
        return Colors.greenAccent;
      case PostStatus.scheduled:
        return Colors.orangeAccent;
      case PostStatus.failed:
        return Colors.redAccent;
      case PostStatus.publishing:
        return Colors.purpleAccent;
      default:
        return Colors.white38;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status filter row
// ─────────────────────────────────────────────────────────────────────────────

class _StatusFilterRow extends ConsumerWidget {
  final List<ScheduledPost> allDayEvents;
  final String lang;
  const _StatusFilterRow(
      {required this.allDayEvents, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gold = Theme.of(context).colorScheme.primary;
    final current = ref.watch(calFilterProvider);

    int count(PostStatus? s) => s == null
        ? allDayEvents.length
        : allDayEvents.where((p) => p.status == s).length;

    String label(PostStatus? s) {
      if (s == null) return 'All';
      switch (s) {
        case PostStatus.scheduled:
          return S.tr('scheduled', lang);
        case PostStatus.published:
          return S.tr('published', lang);
        case PostStatus.failed:
          return S.tr('failed', lang);
        case PostStatus.draft:
          return 'Draft';
        default:
          return s.name;
      }
    }

    final filters = <PostStatus?>[
      null,
      PostStatus.scheduled,
      PostStatus.published,
      PostStatus.failed,
      PostStatus.draft,
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final f = filters[i];
          final c = count(f);
          final sel = current == f;
          return GestureDetector(
            onTap: () =>
                ref.read(calFilterProvider.notifier).state = f,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: sel
                    ? gold
                    : gold.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: sel
                      ? gold
                      : gold.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                c > 0 ? '${label(f)} ($c)' : label(f),
                style: TextStyle(
                  color:
                      sel ? Colors.black : Colors.white70,
                  fontSize: 12,
                  fontWeight: sel
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
// Selected-day panel
// ─────────────────────────────────────────────────────────────────────────────

class _DayPanel extends StatelessWidget {
  final DateTime selectedDay;
  final List<ScheduledPost> events;
  final String lang;
  final bool isLoading;
  final VoidCallback onCreatePost;

  const _DayPanel({
    required this.selectedDay,
    required this.events,
    required this.lang,
    required this.isLoading,
    required this.onCreatePost,
  });

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final dateLabel =
        DateFormat('EEEE, MMMM d').format(selectedDay);
    final isToday = isSameDay(selectedDay, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day label
        Row(
          children: [
            Container(
              width: 3, height: 16,
              decoration: BoxDecoration(
                color: gold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dateLabel.toUpperCase(),
              style: TextStyle(
                color: gold,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            if (isToday) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('TODAY',
                    style: TextStyle(
                        color: gold,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        if (isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child:
                  CircularProgressIndicator(color: gold),
            ),
          )
        else if (events.isEmpty)
          _DayEmptyState(onCreatePost: onCreatePost)
        else
          ...events.map((p) => _CalEventCard(post: p, lang: lang)),
      ],
    );
  }
}

class _DayEmptyState extends StatelessWidget {
  final VoidCallback onCreatePost;
  const _DayEmptyState({required this.onCreatePost});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_rounded,
              color: Colors.white12, size: 40),
          const SizedBox(height: 10),
          const Text('No content scheduled for this day.',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Tap Create to schedule a new post.',
              style: TextStyle(
                  color: Colors.white30, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onCreatePost,
            icon:
                const Icon(Icons.add_rounded, size: 16),
            label: const Text('Create Post'),
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: Colors.black,
              textStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar event card
// ─────────────────────────────────────────────────────────────────────────────

class _CalEventCard extends StatelessWidget {
  final ScheduledPost post;
  final String lang;
  const _CalEventCard({required this.post, required this.lang});

  Color _statusColor() {
    switch (post.status) {
      case PostStatus.published:
        return Colors.greenAccent;
      case PostStatus.scheduled:
        return Colors.orangeAccent;
      case PostStatus.failed:
        return Colors.redAccent;
      case PostStatus.publishing:
        return Colors.purpleAccent;
      case PostStatus.caption_ready:
        return Colors.tealAccent;
      case PostStatus.approved:
        return Colors.lightBlueAccent;
      default:
        return Colors.white38;
    }
  }

  String _statusLabel() {
    switch (post.status) {
      case PostStatus.published:
        return S.tr('published', lang);
      case PostStatus.scheduled:
        return S.tr('scheduled', lang);
      case PostStatus.failed:
        return S.tr('failed', lang);
      case PostStatus.publishing:
        return 'Publishing';
      case PostStatus.caption_ready:
        return 'Caption Ready';
      case PostStatus.approved:
        return 'Approved';
      default:
        return 'Draft';
    }
  }

  String? _timeLabel() {
    final dt = post.scheduledAt ?? post.publishedAt;
    if (dt == null) return null;
    return DateFormat('h:mm a').format(dt.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    final statusColor = _statusColor();
    final thumb = post.imageUrl ?? post.mediaUrl;
    final timeStr = _timeLabel();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: post.status == PostStatus.failed
              ? Colors.redAccent.withValues(alpha: 0.3)
              : gold.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(13)),
            child: SizedBox(
              width: 62, height: 68,
              child: thumb.isNotEmpty &&
                      thumb.startsWith('http')
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

          // Content
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    post.caption?.isNotEmpty == true
                        ? post.caption!
                        : S.tr('noCaption', lang),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          post.caption?.isNotEmpty == true
                              ? Colors.white
                              : Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor
                            .withValues(alpha: 0.13),
                        borderRadius:
                            BorderRadius.circular(12),
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
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    if (timeStr != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.access_time_rounded,
                          size: 11, color: Colors.white38),
                      const SizedBox(width: 3),
                      Text(timeStr,
                          style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11)),
                    ],
                  ]),
                ],
              ),
            ),
          ),

          // Media type + chevron
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              children: [
                Icon(
                  post.mediaType == MediaType.video
                      ? Icons.videocam_outlined
                      : Icons.image_outlined,
                  color: Colors.white24, size: 16,
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
            color: Colors.white24, size: 24,
          ),
        ),
      );
}
