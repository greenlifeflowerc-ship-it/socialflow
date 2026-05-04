import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/social_account.dart';
import '../../../services/accounts_service.dart';
import '../../../services/settings_service.dart';

class InstagramAccountsScreen extends ConsumerStatefulWidget {
  const InstagramAccountsScreen({super.key});

  @override
  ConsumerState<InstagramAccountsScreen> createState() =>
      _InstagramAccountsScreenState();
}

class _InstagramAccountsScreenState
    extends ConsumerState<InstagramAccountsScreen>
    with WidgetsBindingObserver {
  StreamSubscription<Uri>? _linkSub;
  bool _isConnecting = false;
  bool _showReturnHint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForDeepLink();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  void _listenForDeepLink() {
    final appLinks = AppLinks();
    _linkSub = appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'socialflow' && uri.host == 'auth') {
        _refresh();
        if (mounted) {
          setState(() => _showReturnHint = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Instagram account connected! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    });
  }

  void _refresh() => ref.invalidate(socialAccountsProvider);

  Future<void> _connectInstagram() async {
    setState(() {
      _isConnecting = true;
      _showReturnHint = false;
    });
    try {
      final authUrl = await ref.read(accountsServiceProvider).startInstagramAuth();
      final uri = Uri.parse(authUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) setState(() => _showReturnHint = true);
      } else {
        throw Exception('Could not open authorization URL.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to start Instagram auth: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnectAccount(SocialAccount account) async {
    final lang = ref.read(settingsProvider).language;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.tr('deleteAccount', lang)),
        content: Text('Are you sure you want to disconnect ${account.displayName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.tr('cancel', lang))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.tr('ok', lang), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(accountsServiceProvider).deleteAccount(account.id);
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account disconnected.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to disconnect: $e'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(socialAccountsProvider);
    final lang = ref.watch(settingsProvider).language;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.tr('directInstagram', lang)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh accounts',
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Connect button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ElevatedButton.icon(
              onPressed: _isConnecting ? null : _connectInstagram,
              icon: _isConnecting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.add),
              label: Text(_isConnecting ? 'Opening browser…' : S.tr('connectNewAccount', lang)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),

          // Return hint — shown after browser opens
          if (_showReturnHint)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.open_in_browser, size: 18, color: Colors.amber),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'After allowing Instagram access, return here and tap Refresh.',
                        style: TextStyle(fontSize: 13, color: Colors.amber, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blueAccent),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Connect your Instagram account, then tap Refresh to see it here.',
                        style: TextStyle(fontSize: 12, color: Colors.blueAccent),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 4),

          // Accounts list
          Expanded(
            child: accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt, size: 64, color: primary.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text(S.tr('noAccountsConnected', lang), textAlign: TextAlign.center, style: TextStyle(color: theme.textTheme.bodySmall?.color)),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Refresh'), onPressed: _refresh),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: accounts.length,
                    itemBuilder: (context, index) => _AccountCard(
                      account: accounts[index],
                      onDisconnect: () => _disconnectAccount(accounts[index]),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) {
                final msg = err.toString().replaceFirst('Exception: ', '');
                final is401 = msg == '401';
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(is401 ? Icons.lock_outline : Icons.cloud_off_outlined, size: 56, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          is401 ? 'Session expired. Please login again.' : msg,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        OutlinedButton.icon(icon: const Icon(Icons.refresh), label: const Text('Retry'), onPressed: _refresh),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Account card
// ─────────────────────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final SocialAccount account;
  final VoidCallback onDisconnect;
  const _AccountCard({required this.account, required this.onDisconnect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isActive = account.isActive;
    final statusColor = isActive ? Colors.green : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundImage: account.profilePictureUrl != null ? NetworkImage(account.profilePictureUrl!) : null,
              backgroundColor: primary.withValues(alpha: 0.15),
              child: account.profilePictureUrl == null ? Icon(Icons.camera_alt, color: primary) : null,
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _Chip(label: (account.status ?? 'connected').toUpperCase(), color: statusColor),
                      if (account.accountType != null)
                        _Chip(label: account.accountType!.toUpperCase(), color: primary),
                    ],
                  ),
                  if (account.instagramUserId != null) ...[
                    const SizedBox(height: 6),
                    Text('IG ID: ${account.instagramUserId}',
                        style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                  ],
                  if (account.connectedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Connected: ${DateFormat('MMM d, yyyy').format(account.connectedAt!.toLocal())}',
                      style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                    ),
                  ],
                ],
              ),
            ),

            // Disconnect
            IconButton(
              icon: const Icon(Icons.link_off, color: Colors.redAccent),
              tooltip: 'Disconnect',
              onPressed: onDisconnect,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
