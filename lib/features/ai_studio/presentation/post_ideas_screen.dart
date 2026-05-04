import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/ai_service.dart';
import '../../../services/settings_service.dart';

class PostIdeasScreen extends ConsumerStatefulWidget {
  const PostIdeasScreen({super.key});

  @override
  ConsumerState<PostIdeasScreen> createState() => _PostIdeasScreenState();
}

class _PostIdeasScreenState extends ConsumerState<PostIdeasScreen> {
  bool _loading = false;
  String _result = '';
  String _error = '';

  int _count = 5;
  String _goal = 'sales';
  String _contentType = 'image post';
  String? _overrideLanguage;
  String? _overrideTone;

  final _goals = ['sales', 'awareness', 'engagement', 'education', 'product launch', 'offer / promotion'];
  final _types = ['image post', 'carousel', 'story', 'mixed'];
  final _languages = [null, 'English', 'Arabic', 'Bilingual'];
  final _tones = [null, 'luxury', 'friendly', 'professional', 'playful', 'bold', 'minimal'];

  Future<void> _generate() async {
    setState(() { _loading = true; _result = ''; _error = ''; });

    try {
      final settings = ref.read(settingsProvider);
      final profile = settings.brandProfile;

      if (!profile.isConfigured) {
        setState(() {
          _error = 'Please set up your AI Brand Profile first to generate personalised ideas.';
          _loading = false;
        });
        return;
      }
      if (settings.selectedTextModel == null) {
        setState(() { _error = 'No AI text model selected in settings.'; _loading = false; });
        return;
      }

      final text = await ref.read(aiServiceProvider).generatePostIdeas(
        provider: settings.selectedAiProvider,
        model: settings.selectedTextModel!,
        profile: profile,
        apiKey: settings.geminiApiKey,
        count: _count,
        goal: _goal,
        contentType: _contentType,
        overrideLanguage: _overrideLanguage,
        overrideTone: _overrideTone,
      );
      setState(() { _result = text; _loading = false; });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final profile = ref.watch(settingsProvider).brandProfile;

    return Scaffold(
      appBar: AppBar(title: const Text('POST IDEAS')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile badge
                  if (profile.isConfigured)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: gold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: gold.withValues(alpha: 0.25)),
                      ),
                      child: Row(children: [
                        Icon(Icons.verified_rounded, color: gold, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Generating for: ${profile.businessName}',
                            style: TextStyle(color: gold, fontSize: 12, fontWeight: FontWeight.w600))),
                      ]),
                    )
                  else
                    GestureDetector(
                      onTap: () => context.push('/ai/brand-profile'),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(child: Text(
                            'Set up your AI Brand Profile first for personalised ideas.',
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                          )),
                          Icon(Icons.arrow_forward_ios_rounded, color: Colors.orange, size: 12),
                        ]),
                      ),
                    ),

                  // Options
                  _buildOptionRow('Number of Ideas', children: [
                    for (final n in [3, 5, 7, 10])
                      _chip(n.toString(), _count == n, () => setState(() => _count = n)),
                  ]),
                  const SizedBox(height: 12),
                  _buildOptionRow('Goal', children: [
                    for (final g in _goals)
                      _chip(g, _goal == g, () => setState(() => _goal = g)),
                  ]),
                  const SizedBox(height: 12),
                  _buildOptionRow('Content Type', children: [
                    for (final t in _types)
                      _chip(t, _contentType == t, () => setState(() => _contentType = t)),
                  ]),
                  const SizedBox(height: 12),
                  _buildOptionRow('Language Override', children: [
                    for (final l in _languages)
                      _chip(l ?? 'From profile', _overrideLanguage == l,
                          () => setState(() => _overrideLanguage = l)),
                  ]),
                  const SizedBox(height: 12),
                  _buildOptionRow('Tone Override', children: [
                    for (final t in _tones)
                      _chip(t ?? 'From profile', _overrideTone == t,
                          () => setState(() => _overrideTone = t)),
                  ]),

                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _generate,
                      icon: _loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.auto_awesome),
                      label: Text(_loading ? 'Generating...' : 'Generate Post Ideas'),
                    ),
                  ),

                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error,
                                  style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                            ]),
                            const SizedBox(height: 8),
                            const Text(
                              'Try refreshing models or selecting another Gemini model.',
                              style: TextStyle(color: Colors.white38, fontSize: 11),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _generate,
                              icon: const Icon(Icons.refresh, size: 15, color: Colors.redAccent),
                              label: const Text('Retry', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Results
          if (_result.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Row(children: [
                    Icon(Icons.lightbulb_outline_rounded, color: gold, size: 18),
                    const SizedBox(width: 6),
                    Text('Generated Ideas', style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  const SizedBox(height: 12),
                  ..._parseIdeas(_result).map((idea) => _IdeaCard(idea: idea, gold: gold)),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionRow(String label, {required List<Widget> children}) {
    final gold = Theme.of(context).colorScheme.primary;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: gold.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: children),
    ]);
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    final gold = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? gold : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? gold : gold.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white70,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
            )),
      ),
    );
  }

  List<String> _parseIdeas(String raw) {
    // Split on "--- IDEA N ---" or "**IDEA N**" patterns
    final parts = raw.split(RegExp(r'---?\s*IDEA\s*\d+\s*---?', caseSensitive: false));
    if (parts.length > 1) return parts.skip(1).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    // Fallback: split on double newline
    return [raw.trim()];
  }
}

class _IdeaCard extends StatelessWidget {
  final String idea;
  final Color gold;
  const _IdeaCard({required this.idea, required this.gold});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: gold.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: SelectableText(
        idea,
        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
      ),
    );
  }
}


