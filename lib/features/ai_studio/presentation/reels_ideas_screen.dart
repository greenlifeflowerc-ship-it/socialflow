import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../services/ai_service.dart';
import '../../../services/settings_service.dart';

class ReelsIdeasScreen extends ConsumerStatefulWidget {
  const ReelsIdeasScreen({super.key});

  @override
  ConsumerState<ReelsIdeasScreen> createState() => _ReelsIdeasScreenState();
}

class _ReelsIdeasScreenState extends ConsumerState<ReelsIdeasScreen> {
  bool _loading = false;
  String _result = '';
  String _error = '';

  int _count = 3;
  final _topicController = TextEditingController();
  String? _overrideLanguage;
  String? _overrideTone;

  final _languages = [null, 'English', 'Arabic', 'Bilingual'];
  final _tones = [null, 'energetic', 'luxury', 'friendly', 'professional', 'bold', 'emotional'];

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _result = ''; _error = ''; });

    try {
      final settings = ref.read(settingsProvider);
      final profile = settings.brandProfile;

      if (!profile.isConfigured) {
        setState(() {
          _error = 'Please set up your AI Brand Profile first to generate personalised Reels ideas.';
          _loading = false;
        });
        return;
      }
      if (settings.selectedTextModel == null) {
        setState(() { _error = 'No AI text model selected in settings.'; _loading = false; });
        return;
      }

      final text = await ref.read(aiServiceProvider).generateReelsIdeas(
        provider: settings.selectedAiProvider,
        model: settings.selectedTextModel!,
        profile: profile,
        apiKey: settings.geminiApiKey,
        count: _count,
        topic: _topicController.text.trim().isEmpty ? null : _topicController.text.trim(),
        overrideLanguage: _overrideLanguage,
        overrideTone: _overrideTone,
      );
      setState(() { _result = text; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final profile = ref.watch(settingsProvider).brandProfile;

    return Scaffold(
      appBar: AppBar(title: const Text('REELS IDEAS')),
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
                            'Set up your AI Brand Profile first for personalised Reels ideas.',
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                          )),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.orange, size: 12),
                        ]),
                      ),
                    ),

                  // Optional topic
                  TextField(
                    controller: _topicController,
                    decoration: const InputDecoration(
                      labelText: 'Reel Topic / Theme (optional)',
                      hintText: 'e.g. New collection launch, behind the scenes, tutorial',
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildOptionRow('Number of Reels Ideas', children: [
                    for (final n in [2, 3, 5])
                      _chip(n.toString(), _count == n, () => setState(() => _count = n)),
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
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.videocam_outlined),
                      label: Text(_loading ? 'Generating...' : 'Generate Reels Ideas'),
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
                    Icon(Icons.video_library_outlined, color: gold, size: 18),
                    const SizedBox(width: 6),
                    Text('Generated Reels Ideas',
                        style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 15)),
                  ]),
                  const SizedBox(height: 12),
                  ..._parseReels(_result).map((reel) => _ReelCard(reel: reel, gold: gold)),
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

  List<String> _parseReels(String raw) {
    final parts = raw.split(RegExp(r'---?\s*REEL\s*\d+\s*---?', caseSensitive: false));
    if (parts.length > 1) return parts.skip(1).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return [raw.trim()];
  }
}

class _ReelCard extends StatelessWidget {
  final String reel;
  final Color gold;
  const _ReelCard({required this.reel, required this.gold});

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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.videocam_rounded, color: gold, size: 16),
          const SizedBox(width: 6),
          Text('Reel Idea', style: TextStyle(color: gold, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        SelectableText(
          reel,
          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
        ),
      ]),
    );
  }
}

