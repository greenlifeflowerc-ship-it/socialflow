/// Defines a client/business AI Brand Profile.
/// This is persisted inside AppSettings via FlutterSecureStorage.
/// It is loaded into every AI prompt so captions, hashtags, and ideas
/// are personalised to the specific business.
class BrandProfile {
  final String businessName;
  final String instagramUsername;
  final String businessType;
  final String productsOrServices;
  final String targetAudience;
  final String location;
  final String toneOfVoice;
  final String preferredLanguage; // 'en', 'ar', 'both'
  final String mainSellingPoints;
  final String customerProblems;
  final String ctaStyle;
  final String requiredHashtags;
  final String bannedHashtagsOrWords;
  final String competitors;
  final String contentGoals;
  final String brandNotes;

  const BrandProfile({
    this.businessName = '',
    this.instagramUsername = '',
    this.businessType = '',
    this.productsOrServices = '',
    this.targetAudience = '',
    this.location = '',
    this.toneOfVoice = '',
    this.preferredLanguage = 'en',
    this.mainSellingPoints = '',
    this.customerProblems = '',
    this.ctaStyle = '',
    this.requiredHashtags = '',
    this.bannedHashtagsOrWords = '',
    this.competitors = '',
    this.contentGoals = '',
    this.brandNotes = '',
  });

  /// True if the minimum required field (business name) is filled.
  bool get isConfigured => businessName.trim().isNotEmpty;

  BrandProfile copyWith({
    String? businessName,
    String? instagramUsername,
    String? businessType,
    String? productsOrServices,
    String? targetAudience,
    String? location,
    String? toneOfVoice,
    String? preferredLanguage,
    String? mainSellingPoints,
    String? customerProblems,
    String? ctaStyle,
    String? requiredHashtags,
    String? bannedHashtagsOrWords,
    String? competitors,
    String? contentGoals,
    String? brandNotes,
  }) {
    return BrandProfile(
      businessName: businessName ?? this.businessName,
      instagramUsername: instagramUsername ?? this.instagramUsername,
      businessType: businessType ?? this.businessType,
      productsOrServices: productsOrServices ?? this.productsOrServices,
      targetAudience: targetAudience ?? this.targetAudience,
      location: location ?? this.location,
      toneOfVoice: toneOfVoice ?? this.toneOfVoice,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      mainSellingPoints: mainSellingPoints ?? this.mainSellingPoints,
      customerProblems: customerProblems ?? this.customerProblems,
      ctaStyle: ctaStyle ?? this.ctaStyle,
      requiredHashtags: requiredHashtags ?? this.requiredHashtags,
      bannedHashtagsOrWords:
          bannedHashtagsOrWords ?? this.bannedHashtagsOrWords,
      competitors: competitors ?? this.competitors,
      contentGoals: contentGoals ?? this.contentGoals,
      brandNotes: brandNotes ?? this.brandNotes,
    );
  }

  factory BrandProfile.fromJson(Map<String, dynamic> json) {
    return BrandProfile(
      businessName: json['businessName'] as String? ?? '',
      instagramUsername: json['instagramUsername'] as String? ?? '',
      businessType: json['businessType'] as String? ?? '',
      productsOrServices: json['productsOrServices'] as String? ?? '',
      targetAudience: json['targetAudience'] as String? ?? '',
      location: json['location'] as String? ?? '',
      toneOfVoice: json['toneOfVoice'] as String? ?? '',
      preferredLanguage: json['preferredLanguage'] as String? ?? 'en',
      mainSellingPoints: json['mainSellingPoints'] as String? ?? '',
      customerProblems: json['customerProblems'] as String? ?? '',
      ctaStyle: json['ctaStyle'] as String? ?? '',
      requiredHashtags: json['requiredHashtags'] as String? ?? '',
      bannedHashtagsOrWords: json['bannedHashtagsOrWords'] as String? ?? '',
      competitors: json['competitors'] as String? ?? '',
      contentGoals: json['contentGoals'] as String? ?? '',
      brandNotes: json['brandNotes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'businessName': businessName,
        'instagramUsername': instagramUsername,
        'businessType': businessType,
        'productsOrServices': productsOrServices,
        'targetAudience': targetAudience,
        'location': location,
        'toneOfVoice': toneOfVoice,
        'preferredLanguage': preferredLanguage,
        'mainSellingPoints': mainSellingPoints,
        'customerProblems': customerProblems,
        'ctaStyle': ctaStyle,
        'requiredHashtags': requiredHashtags,
        'bannedHashtagsOrWords': bannedHashtagsOrWords,
        'competitors': competitors,
        'contentGoals': contentGoals,
        'brandNotes': brandNotes,
      };
}

