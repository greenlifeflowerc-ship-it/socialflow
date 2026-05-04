import '../../models/brand_profile.dart';

/// A reusable utility that builds dynamic AI prompts from a [BrandProfile]
/// and optional per-post context.
///
/// Used by:
/// - PostEditorScreen (caption/hashtag generation)
/// - PostIdeasScreen  (post idea generation)
/// - ReelsIdeasScreen (reels idea generation)
/// - AiChatScreen     (brand-aware system context)
class AiPromptBuilder {
  AiPromptBuilder._();

  // ─────────────────────────────────────────────────────────────────────────
  // Caption / Hashtag prompt
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds a complete caption-generation prompt from [profile] and
  /// an optional per-post [context].
  ///
  /// Returns a map of parameters ready to be spread into
  /// [AiService.generateCaption()].
  static Map<String, dynamic> buildCaptionParams(
    BrandProfile profile, {
    String? postAbout,
    String? productName,
    String? offer,
    String? postAudience,
    String? postTone,
    String? postLanguage,
    String? postCta,
    String? extraNotes,
  }) {
    final effectiveTone =
        postTone?.isNotEmpty == true ? postTone! : profile.toneOfVoice.isNotEmpty ? profile.toneOfVoice : 'professional';
    final effectiveLanguage = _resolveLanguage(postLanguage, profile.preferredLanguage);
    final effectiveCta = postCta?.isNotEmpty == true ? postCta! : profile.ctaStyle;
    final effectiveHashtagCount = 12;

    return {
      'language': effectiveLanguage,
      'tone': effectiveTone,
      'businessName': profile.businessName,
      'location': profile.location,
      'cta': effectiveCta.isNotEmpty ? effectiveCta : null,
      'hashtagCount': effectiveHashtagCount,
      'captionPreset': 'Instagram Marketing Caption',
      'customPrompt': _buildCaptionCustomPrompt(
        profile,
        postAbout: postAbout,
        productName: productName,
        offer: offer,
        postAudience: postAudience,
        effectiveTone: effectiveTone,
        effectiveLanguage: effectiveLanguage,
        effectiveCta: effectiveCta,
        extraNotes: extraNotes,
      ),
    };
  }

  static String _buildCaptionCustomPrompt(
    BrandProfile profile, {
    String? postAbout,
    String? productName,
    String? offer,
    String? postAudience,
    required String effectiveTone,
    required String effectiveLanguage,
    required String effectiveCta,
    String? extraNotes,
  }) {
    final buf = StringBuffer();

    // Business identity
    if (profile.businessName.isNotEmpty) {
      buf.writeln('You are an expert Instagram marketing copywriter for ${profile.businessName}.');
    } else {
      buf.writeln('You are an expert Instagram marketing copywriter.');
    }
    if (profile.businessType.isNotEmpty) buf.writeln('Business type: ${profile.businessType}');
    if (profile.location.isNotEmpty) buf.writeln('Location: ${profile.location}');
    if (profile.instagramUsername.isNotEmpty) buf.writeln('Instagram: @${profile.instagramUsername}');

    // Products / services
    if (profile.productsOrServices.isNotEmpty) buf.writeln('Products/services: ${profile.productsOrServices}');

    // Audience
    final audience = postAudience?.isNotEmpty == true ? postAudience! : profile.targetAudience;
    if (audience.isNotEmpty) buf.writeln('Target audience: $audience');

    // Selling points
    if (profile.mainSellingPoints.isNotEmpty) buf.writeln('Key selling points: ${profile.mainSellingPoints}');

    // Goals
    if (profile.contentGoals.isNotEmpty) buf.writeln('Content goals: ${profile.contentGoals}');

    // Extra brand notes
    if (profile.brandNotes.isNotEmpty) buf.writeln('Brand notes: ${profile.brandNotes}');

    buf.writeln('');

    // Per-post context
    if (postAbout?.isNotEmpty == true) buf.writeln('This post is about: $postAbout');
    if (productName?.isNotEmpty == true) buf.writeln('Featured product/service: $productName');
    if (offer?.isNotEmpty == true) buf.writeln('Offer or promotion: $offer');
    if (extraNotes?.isNotEmpty == true) buf.writeln('Extra notes: $extraNotes');
    buf.writeln('');

    // Instructions
    buf.writeln('Instructions:');
    buf.writeln('- Write an engaging Instagram caption in $effectiveLanguage');
    buf.writeln('- Tone: $effectiveTone');
    buf.writeln('- Do NOT invent fake prices, offers, or claims not provided');
    buf.writeln('- Make it suitable for Instagram — vary line breaks for readability');
    buf.writeln('- Use emojis naturally if it fits the tone');
    buf.writeln('- Generate 10–15 relevant hashtags');

    if (effectiveCta.isNotEmpty) buf.writeln('- End with CTA: $effectiveCta');

    if (profile.requiredHashtags.isNotEmpty) {
      buf.writeln('- Always include these hashtags: ${profile.requiredHashtags}');
    }
    if (profile.bannedHashtagsOrWords.isNotEmpty) {
      buf.writeln('- NEVER use these words or hashtags: ${profile.bannedHashtagsOrWords}');
    }

    buf.writeln('');
    buf.writeln('Output format (exactly this structure):');
    buf.writeln('Caption:');
    buf.writeln('[your caption here]');
    buf.writeln('');
    buf.writeln('Hashtags:');
    buf.writeln('[#tag1 #tag2 #tag3 ...]');
    buf.writeln('');
    buf.writeln('CTA:');
    buf.writeln('[short call to action]');

    return buf.toString();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Post Ideas prompt
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds a full prompt for generating Instagram post ideas.
  static String buildPostIdeasPrompt(
    BrandProfile profile, {
    int count = 5,
    String goal = 'sales',
    String contentType = 'image post',
    String? overrideLanguage,
    String? overrideTone,
  }) {
    final lang = _resolveLanguage(overrideLanguage, profile.preferredLanguage);
    final tone = overrideTone?.isNotEmpty == true ? overrideTone! : profile.toneOfVoice.isNotEmpty ? profile.toneOfVoice : 'professional';
    final buf = StringBuffer();

    buf.writeln('Generate $count Instagram post ideas for the following business:');
    buf.writeln('');
    if (profile.businessName.isNotEmpty) buf.writeln('Business name: ${profile.businessName}');
    if (profile.businessType.isNotEmpty) buf.writeln('Industry: ${profile.businessType}');
    if (profile.location.isNotEmpty) buf.writeln('Location: ${profile.location}');
    if (profile.productsOrServices.isNotEmpty) buf.writeln('Products/services: ${profile.productsOrServices}');
    if (profile.targetAudience.isNotEmpty) buf.writeln('Target audience: ${profile.targetAudience}');
    if (profile.mainSellingPoints.isNotEmpty) buf.writeln('Selling points: ${profile.mainSellingPoints}');
    buf.writeln('');
    buf.writeln('Post goal: $goal');
    buf.writeln('Content type: $contentType');
    buf.writeln('Language: $lang');
    buf.writeln('Tone: $tone');
    if (profile.requiredHashtags.isNotEmpty) buf.writeln('Required hashtags: ${profile.requiredHashtags}');
    if (profile.bannedHashtagsOrWords.isNotEmpty) buf.writeln('Avoid: ${profile.bannedHashtagsOrWords}');
    buf.writeln('');
    buf.writeln('For each idea, provide exactly this format:');
    buf.writeln('');
    buf.writeln('--- IDEA [N] ---');
    buf.writeln('Title: [post title]');
    buf.writeln('Concept: [what this post is about]');
    buf.writeln('Caption angle: [how the caption should be written]');
    buf.writeln('Visual direction: [what the image/graphic should show]');
    buf.writeln('CTA: [call to action]');
    buf.writeln('Hashtags: [#tag1 #tag2]');
    buf.writeln('');
    buf.writeln('Do not generate generic ideas. Make them specific to this business and its audience.');

    return buf.toString();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Reels Ideas prompt
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds a full prompt for generating Instagram Reels ideas.
  static String buildReelsIdeasPrompt(
    BrandProfile profile, {
    int count = 3,
    String? topic,
    String? overrideLanguage,
    String? overrideTone,
  }) {
    final lang = _resolveLanguage(overrideLanguage, profile.preferredLanguage);
    final tone = overrideTone?.isNotEmpty == true ? overrideTone! : profile.toneOfVoice.isNotEmpty ? profile.toneOfVoice : 'professional';
    final buf = StringBuffer();

    buf.writeln('Generate $count Instagram Reels ideas for the following business:');
    buf.writeln('');
    if (profile.businessName.isNotEmpty) buf.writeln('Business name: ${profile.businessName}');
    if (profile.businessType.isNotEmpty) buf.writeln('Industry: ${profile.businessType}');
    if (profile.location.isNotEmpty) buf.writeln('Location: ${profile.location}');
    if (profile.productsOrServices.isNotEmpty) buf.writeln('Products/services: ${profile.productsOrServices}');
    if (profile.targetAudience.isNotEmpty) buf.writeln('Target audience: ${profile.targetAudience}');
    if (topic?.isNotEmpty == true) buf.writeln('Reel topic/theme: $topic');
    buf.writeln('');
    buf.writeln('Language: $lang');
    buf.writeln('Tone: $tone');
    if (profile.contentGoals.isNotEmpty) buf.writeln('Goals: ${profile.contentGoals}');
    if (profile.ctaStyle.isNotEmpty) buf.writeln('CTA style: ${profile.ctaStyle}');
    buf.writeln('');
    buf.writeln('For each Reels idea, provide exactly this format:');
    buf.writeln('');
    buf.writeln('--- REEL [N] ---');
    buf.writeln('Hook: [first 3 seconds — what grabs attention immediately]');
    buf.writeln('Scene 1: [description]');
    buf.writeln('Scene 2: [description]');
    buf.writeln('Scene 3: [description]');
    buf.writeln('Text overlays: [text shown on screen during reel]');
    buf.writeln('Voiceover/caption idea: [what to say or show on caption]');
    buf.writeln('Music direction: [describe energy and style of background music]');
    buf.writeln('CTA: [call to action at the end]');
    buf.writeln('Hashtags: [#tag1 #tag2]');
    buf.writeln('');
    buf.writeln('Make each reel idea specific to this business, not generic.');

    return buf.toString();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AI Chat system context
  // ─────────────────────────────────────────────────────────────────────────

  /// Builds a system context string to prepend to AI Chat messages
  /// when "Use brand profile" is enabled.
  static String buildChatSystemContext(BrandProfile profile) {
    final buf = StringBuffer();
    buf.writeln('You are an AI marketing assistant specialised in Instagram content.');
    if (profile.businessName.isNotEmpty) buf.writeln('You are helping ${profile.businessName}.');
    if (profile.businessType.isNotEmpty) buf.writeln('Business type: ${profile.businessType}');
    if (profile.location.isNotEmpty) buf.writeln('Location: ${profile.location}');
    if (profile.productsOrServices.isNotEmpty) buf.writeln('Products/services: ${profile.productsOrServices}');
    if (profile.targetAudience.isNotEmpty) buf.writeln('Target audience: ${profile.targetAudience}');
    if (profile.toneOfVoice.isNotEmpty) buf.writeln('Brand tone: ${profile.toneOfVoice}');
    if (profile.contentGoals.isNotEmpty) buf.writeln('Content goals: ${profile.contentGoals}');
    if (profile.bannedHashtagsOrWords.isNotEmpty) buf.writeln('Never use: ${profile.bannedHashtagsOrWords}');
    if (profile.brandNotes.isNotEmpty) buf.writeln('Additional brand notes: ${profile.brandNotes}');
    buf.writeln('');
    buf.writeln('Always answer based on this business context. '
        'Do not invent fake data. Be specific and practical.');
    return buf.toString();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  static String _resolveLanguage(String? override, String profileLang) {
    if (override?.isNotEmpty == true) return override!;
    switch (profileLang) {
      case 'ar':
        return 'Arabic';
      case 'both':
        return 'Arabic and English (bilingual)';
      default:
        return 'English';
    }
  }
}

