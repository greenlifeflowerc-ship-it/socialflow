import 'package:cached_network_image/cached_network_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../services/accounts_service.dart';
import '../../../services/settings_service.dart';
import '../services/insights_service.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const _gold = Color(0xFFD4AF37);
const _goldDim = Color(0xFF8A6D1A);
const _bg = Color(0xFF0A0A0A);
const _cardBg = Color(0xFF131313);
const _cardBg2 = Color(0xFF1A1A1A);
const _border = Color(0xFF242424);
const _muted = Color(0xFF666666);
const _textSub = Color(0xFF999999);

// ─── InsightsGateway ──────────────────────────────────────────────────────────

class InsightsGateway extends ConsumerWidget {
  const InsightsGateway({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    final accountsAsync = ref.watch(socialAccountsProvider);
    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return _emptyAccountScaffold(context, lang);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go('/dashboard/insights/${accounts.first.id}');
          }
        });
        return const _LoadingScaffold();
      },
      loading: () => const _LoadingScaffold(),
      error: (e, _) => Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Text('Error loading accounts: $e',
              style: const TextStyle(color: Colors.white70)),
        ),
      ),
    );
  }

  Widget _emptyAccountScaffold(BuildContext context, String lang) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(context, S.tr('insights', lang), null),
      body: _EmptyState(
        icon: Icons.insights_outlined,
        title: S.tr('noConnectedAccount', lang),
        subtitle: S.tr('connectToViewAnalytics', lang),
        actionLabel: S.tr('connectAccount', lang),
        actionRoute: '/settings/instagram-accounts',
      ),
    );
  }
}

// ─── InsightsScreen ───────────────────────────────────────────────────────────

class InsightsScreen extends ConsumerWidget {
  final String accountId;
  const InsightsScreen({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(realInsightsProvider(accountId));
    final accountsAsync = ref.watch(socialAccountsProvider);
    final lang = ref.watch(settingsProvider).language;

    // Resolve display name for the header
    final accountName = accountsAsync.asData?.value
        .where((a) => a.id == accountId)
        .firstOrNull
        ?.displayName;

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(
        context,
        S.tr('insights', lang).toUpperCase(),
        accountName,
        trailing: IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _gold, size: 20),
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(realInsightsProvider(accountId)),
        ),
      ),
      body: dataAsync.when(
        data: (data) => _InsightsDashboard(
          data: data,
          accountId: accountId,
          lang: lang,
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: _gold),
        ),
        error: (err, _) => _ErrorBody(
          message: err.toString(),
          onRetry: () => ref.invalidate(realInsightsProvider(accountId)),
        ),
      ),
    );
  }
}

// ─── Dashboard body ───────────────────────────────────────────────────────────

class _InsightsDashboard extends StatelessWidget {
  final InsightsData data;
  final String accountId;
  final String lang;

  const _InsightsDashboard({
    required this.data,
    required this.accountId,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final isWide = w >= 700;
      final padding = EdgeInsets.symmetric(
        horizontal: isWide ? 28.0 : 16.0,
        vertical: 20.0,
      );

      return ListView(
        padding: padding,
        children: [
          // ── Error / warning banner ─────────────────────────────────────
          if (data.partialError != null) ...[
            _WarningBanner(message: data.partialError!),
            const SizedBox(height: 20),
          ],

          // ── A. KPI grid ────────────────────────────────────────────────
          _SectionHeader(label: S.tr('accountOverview', lang)),
          const SizedBox(height: 12),
          _KpiGrid(data: data, isWide: isWide),
          const SizedBox(height: 28),

          // ── B. Engagement + Timing (side by side on wide) ──────────────
          _SectionHeader(label: S.tr('performance', lang)),
          const SizedBox(height: 12),
          isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _EngagementCard(data: data)),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _TimingColumn(data: data, lang: lang)),
                  ],
                )
              : Column(
                  children: [
                    _EngagementCard(data: data),
                    const SizedBox(height: 12),
                    _TimingRow(data: data, lang: lang),
                  ],
                ),
          const SizedBox(height: 28),

          // ── C. Recommendations ─────────────────────────────────────────
          _SectionHeader(label: S.tr('smartRecommendations', lang)),
          const SizedBox(height: 12),
          _RecommendationsCard(data: data),
          const SizedBox(height: 28),

          // ── D. Top Posts ───────────────────────────────────────────────
          _SectionHeader(label: S.tr('topPosts', lang)),
          const SizedBox(height: 12),
          _TopPostsSection(data: data, isWide: isWide),
          const SizedBox(height: 32),
        ],
      );
    });
  }
}

// ─── KPI Grid ─────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final InsightsData data;
  final bool isWide;
  const _KpiGrid({required this.data, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final totalInteractions = data.totalInteractionsFromMedia;

    final metrics = [
      _KpiDef(
        label: 'Followers',
        icon: Icons.people_outline,
        value: data.metricStr('follower_count',
            fallback: data.metricStr('followers',
                fallback: data.metricStr('total_followers'))),
      ),
      _KpiDef(
        label: 'Reach',
        icon: Icons.sensors_outlined,
        value: data.metricStr('reach',
            fallback: data.metricStr('total_reach')),
      ),
      _KpiDef(
        label: 'Impressions',
        icon: Icons.visibility_outlined,
        value: data.metricStr('impressions',
            fallback: data.metricStr('total_impressions')),
      ),
      _KpiDef(
        label: 'Interactions',
        icon: Icons.favorite_border,
        value: totalInteractions > 0
            ? totalInteractions.toString()
            : data.metricStr('total_interactions',
                fallback: data.metricStr('accounts_engaged')),
      ),
      _KpiDef(
        label: 'Posts',
        icon: Icons.grid_view_outlined,
        value: data.hasMedia
            ? data.mediaList.length.toString()
            : data.metricStr('media_count', fallback: 'N/A'),
      ),
      _KpiDef(
        label: 'Profile Views',
        icon: Icons.account_circle_outlined,
        value: data.metricStr('profile_views',
            fallback: data.metricStr('website_clicks')),
      ),
    ];

    final cols = isWide ? 6 : 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: isWide ? 1.2 : 1.05,
      ),
      itemCount: metrics.length,
      itemBuilder: (_, i) => _KpiCard(def: metrics[i]),
    );
  }
}

class _KpiDef {
  final String label;
  final IconData icon;
  final String value;
  const _KpiDef({required this.label, required this.icon, required this.value});
}

class _KpiCard extends StatelessWidget {
  final _KpiDef def;
  const _KpiCard({required this.def});

  @override
  Widget build(BuildContext context) {
    final isNA = def.value == 'N/A';
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_cardBg, const Color(0xFF161610)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(def.icon, size: 18, color: isNA ? _muted : _gold),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              def.value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isNA ? _muted : Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            def.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              color: _textSub,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Engagement chart card ─────────────────────────────────────────────────────

class _EngagementCard extends ConsumerWidget {
  final InsightsData data;
  const _EngagementCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final byType = data.engagementByType;

    return _DashCard(
      title: S.tr('engByType', lang),
      child: byType.isEmpty
          ? const _EmptyPlaceholder(
              'Not enough media data to calculate engagement breakdown.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 150,
                  child: BarChart(
                    BarChartData(
                      borderData: FlBorderData(show: false),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: _border,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            getTitlesWidget: (val, _) {
                              final idx = val.toInt();
                              if (idx < 0 || idx >= byType.length) {
                                return const SizedBox.shrink();
                              }
                              final raw =
                                  (byType[idx]['label'] as String?) ?? '';
                              final short = raw == 'CAROUSEL_ALBUM'
                                  ? 'Album'
                                  : raw == 'VIDEO'
                                      ? 'Video'
                                      : raw == 'IMAGE'
                                          ? 'Image'
                                          : raw.length > 6
                                              ? raw.substring(0, 6)
                                              : raw;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  short,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: _textSub,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      barGroups: byType.asMap().entries.map((e) {
                        final val =
                            ((e.value['value'] as num?) ?? 0).toDouble();
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: val,
                              width: 28,
                              gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [_goldDim, _gold],
                              ),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Legend
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: byType.map((e) {
                    final raw = (e['label'] as String?) ?? '';
                    final short = raw == 'CAROUSEL_ALBUM'
                        ? 'Carousel'
                        : raw == 'VIDEO'
                            ? 'Video'
                            : raw == 'IMAGE'
                                ? 'Image'
                                : raw;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$short: ${e['value']}',
                          style: const TextStyle(
                              fontSize: 11, color: _textSub),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}

// ─── Timing ────────────────────────────────────────────────────────────────────

class _TimingColumn extends StatelessWidget {
  final InsightsData data;
  final String lang;
  const _TimingColumn({required this.data, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TimingCard(
          label: S.tr('bestTimeToPost', lang),
          value: data.bestTimeFromMedia,
          icon: Icons.schedule_outlined,
        ),
        const SizedBox(height: 10),
        _TimingCard(
          label: S.tr('bestDayToPost', lang),
          value: data.bestDayFromMedia,
          icon: Icons.calendar_today_outlined,
        ),
      ],
    );
  }
}

class _TimingRow extends StatelessWidget {
  final InsightsData data;
  final String lang;
  const _TimingRow({required this.data, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TimingCard(
            label: S.tr('bestTimeToPost', lang),
            value: data.bestTimeFromMedia,
            icon: Icons.schedule_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TimingCard(
            label: S.tr('bestDayToPost', lang),
            value: data.bestDayFromMedia,
            icon: Icons.calendar_today_outlined,
          ),
        ),
      ],
    );
  }
}

class _TimingCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _TimingCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isNA = value == 'N/A';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _gold.withAlpha(22),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold.withAlpha(50)),
            ),
            child: Icon(icon, size: 18, color: isNA ? _muted : _gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 10, color: _textSub)),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isNA ? _muted : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recommendations ──────────────────────────────────────────────────────────

class _RecommendationsCard extends StatelessWidget {
  final InsightsData data;
  const _RecommendationsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      title: 'Insights',
      child: Column(
        children: data.recommendations.asMap().entries.map((e) {
          return Padding(
            padding: EdgeInsets.only(top: e.key == 0 ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _gold.withAlpha(22),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _gold.withAlpha(60)),
                  ),
                  child: const Icon(Icons.lightbulb_outline,
                      size: 12, color: _gold),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.value,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Top Posts ────────────────────────────────────────────────────────────────

class _TopPostsSection extends StatelessWidget {
  final InsightsData data;
  final bool isWide;
  const _TopPostsSection({required this.data, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final posts = data.topPosts;

    if (posts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: const _EmptyPlaceholder('No top-performing posts available yet.'),
      );
    }

    final cardW = isWide ? 160.0 : 140.0;
    final cardH = isWide ? 190.0 : 170.0;

    return SizedBox(
      height: cardH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          return _TopPostCard(
            post: posts[i],
            width: cardW,
            height: cardH,
          );
        },
      ),
    );
  }
}

class _TopPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final double width;
  final double height;
  const _TopPostCard(
      {required this.post, required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    final thumbUrl =
        (post['thumbnail_url'] ?? post['media_url'] ?? '').toString();
    final likes = (post['like_count'] as num? ?? 0).toInt();
    final comments = (post['comments_count'] as num? ?? 0).toInt();
    final caption = (post['caption'] ?? '').toString();
    final mediaType = (post['media_type'] ?? '').toString();

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail
            thumbUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: thumbUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(color: _cardBg2),
                    errorWidget: (_, __, ___) =>
                        _PostPlaceholder(mediaType: mediaType),
                  )
                : _PostPlaceholder(mediaType: mediaType),

            // Bottom gradient
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.4, 1.0],
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(220),
                    ],
                  ),
                ),
              ),
            ),

            // Media type badge (top-right)
            if (mediaType.isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _border),
                  ),
                  child: Text(
                    mediaType == 'VIDEO'
                        ? '▶ Video'
                        : mediaType == 'CAROUSEL_ALBUM'
                            ? '⊞ Album'
                            : '◻ Image',
                    style: const TextStyle(
                        fontSize: 8, color: Colors.white70),
                  ),
                ),
              ),

            // Caption + stats
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption.isNotEmpty)
                      Text(
                        caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                          height: 1.3,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.favorite_rounded,
                            color: Color(0xFFE8455A), size: 12),
                        const SizedBox(width: 3),
                        Text('$likes',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 10),
                        const Icon(Icons.chat_bubble_outline,
                            color: Colors.white54, size: 12),
                        const SizedBox(width: 3),
                        Text('$comments',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostPlaceholder extends StatelessWidget {
  final String mediaType;
  const _PostPlaceholder({required this.mediaType});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _cardBg2,
      child: Center(
        child: Icon(
          mediaType == 'VIDEO'
              ? Icons.videocam_outlined
              : Icons.image_outlined,
          color: _muted,
          size: 32,
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: _gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _gold,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

class _DashCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _DashCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Divider(color: _border, height: 18),
          child,
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;
  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1200),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A2800)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFFFB300), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFDDA000),
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final String? actionRoute;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.actionRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: _muted),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _muted)),
            if (actionLabel != null && actionRoute != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(actionRoute!),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: Text(actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final String message;
  const _EmptyPlaceholder(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline, size: 15, color: _muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(fontSize: 12, color: _muted, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFE05555), size: 52),
            const SizedBox(height: 16),
            Text('Something went wrong',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: _muted)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _bg,
      body: Center(child: CircularProgressIndicator(color: _gold)),
    );
  }
}

// ─── AppBar builder ───────────────────────────────────────────────────────────

PreferredSizeWidget _buildAppBar(
  BuildContext context,
  String title,
  String? subtitle, {
  Widget? trailing,
}) {
  return PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight + 1),
    child: AppBar(
      backgroundColor: _bg,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _gold, size: 18),
        onPressed: () => context.go('/dashboard'),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _gold,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty)
            Text(
              subtitle,
              style: const TextStyle(
                color: _textSub,
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
      actions: [if (trailing != null) trailing],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border),
      ),
    ),
  );
}
