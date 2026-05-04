import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/brand_profile.dart';
import '../../../services/settings_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Root screen
// ─────────────────────────────────────────────────────────────────────────────
class AiStudioScreen extends ConsumerWidget {
  const AiStudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final lang = settings.language;
    final profile = settings.brandProfile;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1000;
    final isTablet = size.width >= 640 && size.width < 1000;
    final toolColumns = isDesktop ? 4 : (isTablet ? 3 : 2);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Custom header ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _AiStudioHeader(lang: lang),
          ),

          // ── Hero: Brand Profile ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: AiBrandProfileCard(profile: profile),
            ),
          ),

          // ── Section: AI Tools ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionLabel(label: S.tr('aiTools', lang).toUpperCase(), topPadding: 24),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: toolColumns,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: isDesktop ? 2.0 : (isTablet ? 1.8 : 1.55),
              ),
              delegate: SliverChildListDelegate([
                AiToolCard(
                  icon: Icons.chat_bubble_rounded,
                  accentColor: const Color(0xFF4A9EFF),
                  title: S.tr('aiChat', lang),
                  description: S.tr('aiChatDesc', lang),
                  onTap: () => context.push('/ai/chat'),
                ),
                AiToolCard(
                  icon: Icons.edit_note_rounded,
                  accentColor: const Color(0xFFD4AF37),
                  title: S.tr('captionGenerator', lang),
                  description: S.tr('captionGeneratorDesc', lang),
                  onTap: () => context.push('/ai/chat'),
                  badgeLabel: profile.isConfigured ? S.tr('personalised', lang) : null,
                ),
                AiToolCard(
                  icon: Icons.tag_rounded,
                  accentColor: const Color(0xFF26C6DA),
                  title: S.tr('hashtagGenerator', lang),
                  description: S.tr('hashtagGeneratorDesc', lang),
                  onTap: () => context.push('/ai/chat'),
                  badgeLabel: profile.isConfigured ? S.tr('personalised', lang) : null,
                ),
                AiToolCard(
                  icon: Icons.lightbulb_rounded,
                  accentColor: const Color(0xFFFFB74D),
                  title: S.tr('postIdeas', lang),
                  description: S.tr('postIdeasDesc', lang),
                  onTap: () => context.push('/ai/post-ideas'),
                ),
                AiToolCard(
                  icon: Icons.videocam_rounded,
                  accentColor: const Color(0xFFEF5350),
                  title: S.tr('reelsIdeas', lang),
                  description: S.tr('reelsIdeasDesc', lang),
                  onTap: () => context.push('/ai/reels-ideas'),
                ),
                AiToolCard(
                  icon: Icons.image_search_rounded,
                  accentColor: const Color(0xFF9C27B0),
                  title: S.tr('singleEdit', lang),
                  description: S.tr('singleEditDesc', lang),
                  onTap: () => context.push('/ai/single-edit'),
                ),
                AiToolCard(
                  icon: Icons.auto_fix_high_rounded,
                  accentColor: const Color(0xFF00BCD4),
                  title: S.tr('bulkEdit', lang),
                  description: S.tr('bulkEditDesc', lang),
                  onTap: () => context.push('/ai/bulk-edit'),
                ),
                AiToolCard(
                  icon: Icons.history_rounded,
                  accentColor: const Color(0xFF66BB6A),
                  title: S.tr('editHistory', lang),
                  description: S.tr('editHistoryDesc', lang),
                  onTap: () => context.push('/ai/history'),
                ),
              ]),
            ),
          ),

          // ── Tips section ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionLabel(label: S.tr('tipsSection', lang).toUpperCase(), topPadding: 24),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: AiTipsCard(isProfileConfigured: profile.isConfigured),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────
class _AiStudioHeader extends StatelessWidget {
  final String lang;
  const _AiStudioHeader({required this.lang});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Container(
      color: bg,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 20,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => context.go('/media'),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(top: 2, right: 12),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: gold.withValues(alpha: 0.2)),
              ),
              child: Icon(Icons.arrow_back_ios_new_rounded, color: gold, size: 16),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.tr('aiStudio', lang).toUpperCase(),
                  style: TextStyle(
                    color: gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  S.tr('yourAiAssistant', lang),
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          // New AI Task button
          GestureDetector(
            onTap: () => context.push('/ai/chat'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: gold,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_rounded, color: Colors.black, size: 16),
                const SizedBox(width: 4),
                Text(S.tr('newTask', lang), style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final double topPadding;
  const _SectionLabel({required this.label, this.topPadding = 16});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 10),
      child: Row(children: [
        Text(
          label,
          style: TextStyle(
            color: gold.withValues(alpha: 0.6),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: gold.withValues(alpha: 0.1), height: 1)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Brand Profile Hero Card  (exported so other screens can use it)
// ─────────────────────────────────────────────────────────────────────────────
class AiBrandProfileCard extends ConsumerWidget {
  final BrandProfile profile;
  const AiBrandProfileCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final isConfigured = profile.isConfigured;

    return GestureDetector(
      onTap: () => context.push('/ai/brand-profile'),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isConfigured ? gold.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isConfigured ? gold : Colors.orange).withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Card top bar ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: (isConfigured ? gold : Colors.orange).withValues(alpha: 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  bottom: BorderSide(
                    color: (isConfigured ? gold : Colors.orange).withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isConfigured ? gold : Colors.orange).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isConfigured ? Icons.verified_rounded : Icons.business_center_outlined,
                    color: isConfigured ? gold : Colors.orange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                  Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(S.tr('brandProfile', lang),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      S.tr('brandProfileCardDesc', lang),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isConfigured ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isConfigured ? Colors.green : Colors.orange).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    isConfigured ? S.tr('active', lang) : S.tr('setupNeeded', lang),
                    style: TextStyle(
                      color: isConfigured ? Colors.greenAccent : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ]),
            ),

            // ── Card body ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: isConfigured
                  ? _ConfiguredBody(profile: profile, gold: gold)
                  : _EmptyBody(gold: gold),
            ),

            // ── Card footer action ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: _GoldOutlineButton(
                  label: isConfigured ? S.tr('editBrandProfile', lang) : S.tr('createAiProfile', lang),
                  icon: isConfigured ? Icons.edit_rounded : Icons.add_rounded,
                  onTap: () => context.push('/ai/brand-profile'),
                  gold: isConfigured ? gold : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfiguredBody extends StatelessWidget {
  final BrandProfile profile;
  final Color gold;
  const _ConfiguredBody({required this.profile, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (profile.businessName.isNotEmpty) _ProfileChip(label: profile.businessName, icon: Icons.storefront_rounded, gold: gold),
        if (profile.instagramUsername.isNotEmpty) _ProfileChip(label: '@${profile.instagramUsername}', icon: Icons.alternate_email_rounded, gold: gold),
        if (profile.businessType.isNotEmpty) _ProfileChip(label: profile.businessType, icon: Icons.category_rounded, gold: gold),
        if (profile.location.isNotEmpty) _ProfileChip(label: profile.location, icon: Icons.location_on_rounded, gold: gold),
        if (profile.preferredLanguage.isNotEmpty) _ProfileChip(
          label: profile.preferredLanguage == 'ar' ? 'Arabic' : profile.preferredLanguage == 'both' ? 'Bilingual' : 'English',
          icon: Icons.language_rounded,
          gold: gold,
        ),
        if (profile.toneOfVoice.isNotEmpty) _ProfileChip(label: '${profile.toneOfVoice} tone', icon: Icons.record_voice_over_rounded, gold: gold),
        if (profile.targetAudience.isNotEmpty) _ProfileChip(label: profile.targetAudience, icon: Icons.people_rounded, gold: gold, maxWidth: 180),
      ],
    );
  }
}

class _EmptyBody extends ConsumerWidget {
  final Color gold;
  const _EmptyBody({required this.gold});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.tr('setBrandProfileFirst', lang),
          style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _FeatureHint(icon: Icons.edit_note_rounded, label: S.tr('personalisedCaptions', lang), gold: gold),
            _FeatureHint(icon: Icons.tag_rounded, label: S.tr('smartHashtags', lang), gold: gold),
            _FeatureHint(icon: Icons.lightbulb_rounded, label: S.tr('postIdeas', lang), gold: gold),
            _FeatureHint(icon: Icons.videocam_rounded, label: S.tr('reelsScripts', lang), gold: gold),
          ],
        ),
      ],
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color gold;
  final double? maxWidth;
  const _ProfileChip({required this.label, required this.icon, required this.gold, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: maxWidth != null ? BoxConstraints(maxWidth: maxWidth!) : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: gold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.18)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: gold.withValues(alpha: 0.7), size: 12),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label,
              style: TextStyle(color: gold.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

class _FeatureHint extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color gold;
  const _FeatureHint({required this.icon, required this.label, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: gold.withValues(alpha: 0.5), size: 13),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
    ]);
  }
}

class _GoldOutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color gold;
  const _GoldOutlineButton({required this.label, required this.icon, required this.onTap, required this.gold});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gold.withValues(alpha: 0.5)),
          color: gold.withValues(alpha: 0.06),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: gold, size: 15),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: gold, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Tool Card  (compact, content-height-driven)
// ─────────────────────────────────────────────────────────────────────────────
class AiToolCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;
  final VoidCallback onTap;
  final String? badgeLabel;

  const AiToolCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
    required this.onTap,
    this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: accentColor.withValues(alpha: 0.08),
        highlightColor: accentColor.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accentColor.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, color: accentColor, size: 18),
                  ),
                  const Spacer(),
                  if (badgeLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeLabel!,
                        style: TextStyle(color: accentColor, fontSize: 8, fontWeight: FontWeight.w700),
                      ),
                    )
                  else
                    Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.18), size: 16),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                description,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.42), fontSize: 10, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tips card
// ─────────────────────────────────────────────────────────────────────────────
class AiTipsCard extends StatelessWidget {
  final bool isProfileConfigured;
  const AiTipsCard({super.key, required this.isProfileConfigured});

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;

    final tips = [
      if (!isProfileConfigured)
        _Tip(icon: Icons.person_add_rounded, color: Colors.orange,
            text: 'Set up your AI Brand Profile first for personalised output.'),
      _Tip(icon: Icons.lightbulb_rounded, color: const Color(0xFFFFB74D),
          text: 'Use Post Ideas for campaign planning and content calendars.'),
      _Tip(icon: Icons.videocam_rounded, color: const Color(0xFFEF5350),
          text: 'Use Reels Ideas to get hook concepts and scene structures.'),
      _Tip(icon: Icons.chat_bubble_rounded, color: const Color(0xFF4A9EFF),
          text: 'Turn on "Brand context" in AI Chat for strategy advice.'),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: tips.map((t) => _TipRow(tip: t)).toList(),
      ),
    );
  }
}

class _Tip {
  final IconData icon;
  final Color color;
  final String text;
  const _Tip({required this.icon, required this.color, required this.text});
}

class _TipRow extends StatelessWidget {
  final _Tip tip;
  const _TipRow({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: tip.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(tip.icon, color: tip.color, size: 13),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            tip.text,
            style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
          ),
        ),
      ]),
    );
  }
}
