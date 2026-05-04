import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/brand_profile.dart';
import '../../../services/settings_service.dart';

class BrandProfileScreen extends ConsumerStatefulWidget {
  const BrandProfileScreen({super.key});

  @override
  ConsumerState<BrandProfileScreen> createState() => _BrandProfileScreenState();
}

class _BrandProfileScreenState extends ConsumerState<BrandProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // Controllers
  late final TextEditingController _businessName;
  late final TextEditingController _instagramUsername;
  late final TextEditingController _businessType;
  late final TextEditingController _productsOrServices;
  late final TextEditingController _targetAudience;
  late final TextEditingController _location;
  late final TextEditingController _toneOfVoice;
  late final TextEditingController _mainSellingPoints;
  late final TextEditingController _customerProblems;
  late final TextEditingController _ctaStyle;
  late final TextEditingController _requiredHashtags;
  late final TextEditingController _bannedHashtagsOrWords;
  late final TextEditingController _competitors;
  late final TextEditingController _contentGoals;
  late final TextEditingController _brandNotes;
  String _preferredLanguage = 'en';

  @override
  void initState() {
    super.initState();
    final profile = ref.read(settingsProvider).brandProfile;
    _businessName = TextEditingController(text: profile.businessName);
    _instagramUsername = TextEditingController(text: profile.instagramUsername);
    _businessType = TextEditingController(text: profile.businessType);
    _productsOrServices = TextEditingController(text: profile.productsOrServices);
    _targetAudience = TextEditingController(text: profile.targetAudience);
    _location = TextEditingController(text: profile.location);
    _toneOfVoice = TextEditingController(text: profile.toneOfVoice);
    _mainSellingPoints = TextEditingController(text: profile.mainSellingPoints);
    _customerProblems = TextEditingController(text: profile.customerProblems);
    _ctaStyle = TextEditingController(text: profile.ctaStyle);
    _requiredHashtags = TextEditingController(text: profile.requiredHashtags);
    _bannedHashtagsOrWords = TextEditingController(text: profile.bannedHashtagsOrWords);
    _competitors = TextEditingController(text: profile.competitors);
    _contentGoals = TextEditingController(text: profile.contentGoals);
    _brandNotes = TextEditingController(text: profile.brandNotes);
    _preferredLanguage = profile.preferredLanguage.isNotEmpty ? profile.preferredLanguage : 'en';
  }

  @override
  void dispose() {
    for (final c in [
      _businessName, _instagramUsername, _businessType, _productsOrServices,
      _targetAudience, _location, _toneOfVoice, _mainSellingPoints,
      _customerProblems, _ctaStyle, _requiredHashtags, _bannedHashtagsOrWords,
      _competitors, _contentGoals, _brandNotes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final updated = BrandProfile(
      businessName: _businessName.text.trim(),
      instagramUsername: _instagramUsername.text.trim(),
      businessType: _businessType.text.trim(),
      productsOrServices: _productsOrServices.text.trim(),
      targetAudience: _targetAudience.text.trim(),
      location: _location.text.trim(),
      toneOfVoice: _toneOfVoice.text.trim(),
      preferredLanguage: _preferredLanguage,
      mainSellingPoints: _mainSellingPoints.text.trim(),
      customerProblems: _customerProblems.text.trim(),
      ctaStyle: _ctaStyle.text.trim(),
      requiredHashtags: _requiredHashtags.text.trim(),
      bannedHashtagsOrWords: _bannedHashtagsOrWords.text.trim(),
      competitors: _competitors.text.trim(),
      contentGoals: _contentGoals.text.trim(),
      brandNotes: _brandNotes.text.trim(),
    );

    final current = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).save(
      current.copyWith(brandProfile: updated),
    );

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(S.tr('brandProfileSaved', ref.read(languageProvider))),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _reset() async {
    final lang = ref.read(languageProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.tr('deleteRule', lang)), // reuse "Delete Rule?" style pattern
        content: const Text('All brand profile data will be cleared.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.tr('cancel', lang))),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: Text(S.tr('delete', lang), style: const TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final current = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).save(
      current.copyWith(brandProfile: const BrandProfile()),
    );
    for (final c in [
      _businessName, _instagramUsername, _businessType, _productsOrServices,
      _targetAudience, _location, _toneOfVoice, _mainSellingPoints,
      _customerProblems, _ctaStyle, _requiredHashtags, _bannedHashtagsOrWords,
      _competitors, _contentGoals, _brandNotes,
    ]) {
      c.clear();
    }
    setState(() => _preferredLanguage = 'en');
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final lang = ref.watch(languageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(S.tr('brandProfile', lang).toUpperCase()),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_outlined), tooltip: S.tr('refresh', lang), onPressed: _reset),
          const SizedBox(width: 4),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionHeader('🏢 Business Identity', gold),
            _field(_businessName, 'Business Name *', hint: 'e.g. Al Noor Flowers',
                validator: (v) => v?.trim().isEmpty == true ? 'Business name is required' : null),
            _field(_instagramUsername, 'Instagram Username', hint: 'e.g. alnoor_flowers'),
            _field(_businessType, 'Business Type / Industry', hint: 'e.g. Floral shop, Real estate, Fashion brand'),
            _field(_location, 'Country / City / Service Area', hint: 'e.g. Dubai, UAE'),

            const SizedBox(height: 8),
            _sectionHeader('🛍️ Products & Services', gold),
            _field(_productsOrServices, 'Products or Services', hint: 'Describe what you sell or offer', maxLines: 3),
            _field(_mainSellingPoints, 'Main Selling Points', hint: 'What makes you stand out?', maxLines: 2),
            _field(_customerProblems, 'Common Customer Problems', hint: 'What problems does your product solve?', maxLines: 2),

            const SizedBox(height: 8),
            _sectionHeader('🎯 Audience & Goals', gold),
            _field(_targetAudience, 'Target Audience', hint: 'e.g. Women 25–40, luxury buyers, UAE residents', maxLines: 2),
            _field(_contentGoals, 'Content Goals', hint: 'e.g. Sales, brand awareness, engagement, leads, store visits'),

            const SizedBox(height: 8),
            _sectionHeader('🗣️ Brand Voice & Style', gold),
            _field(_toneOfVoice, 'Brand Tone of Voice', hint: 'e.g. Luxury, friendly, professional, bold, Arabic warmth'),
            _field(_ctaStyle, 'Call-to-Action Style', hint: 'e.g. WhatsApp us, DM to order, Shop now, Book now'),

            const SizedBox(height: 8),
            _sectionHeader('🌐 Language', gold),
            _buildLanguagePicker(gold, surface),

            const SizedBox(height: 8),
            _sectionHeader('#️⃣ Hashtag Rules', gold),
            _field(_requiredHashtags, 'Required Hashtags', hint: 'Always include: e.g. #Dubai #DubaiFlowers #زهور_دبي'),
            _field(_bannedHashtagsOrWords, 'Banned Hashtags / Words', hint: 'Never use: e.g. #cheap #discount'),

            const SizedBox(height: 8),
            _sectionHeader('📌 Additional Context', gold),
            _field(_competitors, 'Competitors / Inspiration Accounts', hint: 'e.g. @competitor1, @inspiration_brand'),
            _field(_brandNotes, 'Brand Notes', hint: 'Any other important brand context for the AI', maxLines: 4),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? '${S.tr('saveBrandProfile', lang)}...' : S.tr('saveBrandProfile', lang)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, Color gold) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(child: Divider(color: gold.withValues(alpha: 0.2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(title, style: TextStyle(color: gold, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        Expanded(child: Divider(color: gold.withValues(alpha: 0.2))),
      ]),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }

  Widget _buildLanguagePicker(Color gold, Color surface) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Preferred Language', style: TextStyle(color: gold.withValues(alpha: 0.8), fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final entry in {'en': 'English 🇬🇧', 'ar': 'Arabic 🇦🇪', 'both': 'Bilingual 🌐'}.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _preferredLanguage == entry.key,
                onSelected: (_) => setState(() => _preferredLanguage = entry.key),
                selectedColor: gold,
                labelStyle: TextStyle(
                  color: _preferredLanguage == entry.key ? Colors.black : Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ]),
        ],
      ),
    );
  }
}


