import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../services/settings_service.dart';

class AboutMeScreen extends ConsumerWidget {
  const AboutMeScreen({super.key});

  static const _gold = Color(0xFFD4AF37);
  static const _cardBg = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.tr('aboutMe', lang)),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 620 : double.infinity),
          child: FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final version = snapshot.data?.version ?? '—';
              final build = snapshot.data?.buildNumber ?? '—';
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                children: [
                  _buildHeader(lang),
                  const SizedBox(height: 28),
                  _buildAppInfoCard(lang, version, build),
                  const SizedBox(height: 16),
                  _buildLegalCard(lang),
                  const SizedBox(height: 32),
                  _buildFooter(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String lang) {
    return Column(
      children: [
        // App logo
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _gold.withOpacity(0.45), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _gold.withOpacity(0.18),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/icons/app_icon.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.auto_awesome, color: _gold, size: 50),
            ),
          ),
        ),
        const SizedBox(height: 18),
        // App name
        const Text(
          'SOCIALFLOW',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: _gold,
            letterSpacing: 3.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'SOCIAL SCHEDULER',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.45),
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 24),
        // Developer card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _gold.withOpacity(0.28), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.10),
                  shape: BoxShape.circle,
                  border: Border.all(color: _gold.withOpacity(0.4)),
                ),
                child: const Icon(Icons.person_rounded, color: _gold, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MOHAMMAD YAZAN HAIDAR',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _gold.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Developer / App Owner',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _gold.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppInfoCard(String lang, String version, String build) {
    return _SectionCard(
      title: S.tr('appInfo', lang),
      children: [
        _InfoRow(
            label: S.tr('appNameLabel', lang), value: 'SOCIALFLOW'),
        _InfoRow(
            label: S.tr('versionInfo', lang), value: version),
        _InfoRow(label: S.tr('buildNumber', lang), value: build),
        _InfoRow(
            label: S.tr('contact', lang),
            value: S.tr('notProvided', lang),
            isLast: false),
        _MultiLineRow(
          label: 'Description',
          value: S.tr('appDescriptionText', lang),
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildLegalCard(String lang) {
    return _SectionCard(
      title: S.tr('legalLinks', lang),
      children: [
        _LinkRow(
            label: S.tr('privacyPolicy', lang),
            icon: Icons.privacy_tip_outlined),
        _LinkRow(
            label: S.tr('termsOfService', lang),
            icon: Icons.gavel_outlined),
        _LinkRow(
            label: S.tr('dataDeletion', lang),
            icon: Icons.delete_sweep_outlined,
            isLast: true),
      ],
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        '© 2025 – 2026  SOCIALFLOW',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withOpacity(0.25),
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ─── Supporting widgets ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  static const _gold = Color(0xFFD4AF37);
  static const _cardBg = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _gold.withOpacity(0.75),
              letterSpacing: 1.6,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _gold.withOpacity(0.13), width: 1),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _InfoRow(
      {required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.white.withOpacity(0.52)),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
              height: 1,
              color: Colors.white.withOpacity(0.07),
              indent: 16,
              endIndent: 16),
      ],
    );
  }
}

class _MultiLineRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  const _MultiLineRow(
      {required this.label, required this.value, this.isLast = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(
            height: 1,
            color: Colors.white.withOpacity(0.07),
            indent: 16,
            endIndent: 16),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.42),
                    letterSpacing: 0.4),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Colors.white70,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLast;
  const _LinkRow(
      {required this.label, required this.icon, this.isLast = false});

  static const _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {}, // placeholder — wire up url_launcher if needed
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(18))
              : BorderRadius.zero,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 18, color: _gold.withOpacity(0.72)),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 13.5, color: Colors.white70),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: Colors.white.withOpacity(0.28)),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
              height: 1,
              color: Colors.white.withOpacity(0.07),
              indent: 16,
              endIndent: 16),
      ],
    );
  }
}

