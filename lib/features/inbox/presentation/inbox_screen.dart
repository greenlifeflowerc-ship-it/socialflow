import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/ig_models.dart';
import '../../../models/social_account.dart';
import '../../../services/api_client.dart';
import '../../../services/accounts_service.dart';
import '../../../services/settings_service.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Resolves the first connected SocialAccount (full object — needed for ig_user_id).
final _inboxAccountProvider =
    FutureProvider.autoDispose<SocialAccount>((ref) async {
  final accounts = await ref.watch(socialAccountsProvider.future);
  if (accounts.isEmpty) {
    throw Exception(
        'No connected Instagram accounts. Please connect an account in Settings.');
  }
  return accounts.first;
});

/// Fetches conversations via GET /api/messages/conversations?account_id={id}
final inboxProvider =
    FutureProvider.autoDispose<List<IgConversation>>((ref) async {
  final account = await ref.watch(_inboxAccountProvider.future);
  final api = ref.read(apiClientProvider);

  debugPrint('SELECTED ACCOUNT ID: ${account.id}');
  debugPrint('MY IG USER ID: ${account.instagramUserId}');

  final response = await api.getConversations(account.id);

  debugPrint('CONVERSATIONS RESPONSE KEYS: ${response.keys.toList()}');

  final conversationsRaw = response['conversations'];
  List<dynamic> list = [];
  if (conversationsRaw is Map && conversationsRaw['data'] is List) {
    list = conversationsRaw['data'] as List;
  } else if (conversationsRaw is List) {
    list = conversationsRaw;
  } else {
    for (final key in ['data', 'items', 'results']) {
      if (response[key] is List) {
        list = response[key] as List;
        break;
      }
    }
  }

  debugPrint('CONVERSATIONS COUNT: ${list.length}');
  return list
      .map((e) => IgConversation.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ─────────────────────────────────────────────────────────────────────────────
// InboxScreen
// ─────────────────────────────────────────────────────────────────────────────

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  IgConversation? _selectedConversation;
  bool _isSyncing = false;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh conversations every 15 s (silent — no full-screen spinner)
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) ref.invalidate(inboxProvider);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncInbox() async {
    final lang = ref.read(settingsProvider).language;
    setState(() => _isSyncing = true);
    try {
      final account = await ref.read(_inboxAccountProvider.future);
      final response =
          await ref.read(apiClientProvider).getConversations(account.id);
      debugPrint('MESSAGES SYNC OK: ${response.keys.toList()}');
      if (mounted) {
        ref.invalidate(inboxProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.amber,
          content: Text('Conversations refreshed.',
              style: TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold)),
          duration: Duration(seconds: 3),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${S.tr('syncFailed', lang)}: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showDebugInfo() async {
    try {
      final debugData =
          await ref.read(apiClientProvider).getDebugInbox();
      final conversations = ref
          .read(apiClientProvider)
          .parseListFromAnyKey(debugData, ['conversations']);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('Inbox Debug',
              style: TextStyle(color: Colors.amber)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Conversations Count: ${debugData['conversationsCount']}',
                    style: const TextStyle(color: Colors.white)),
                Text('Messages Count: ${debugData['messagesCount']}',
                    style: const TextStyle(color: Colors.white)),
                const Divider(color: Colors.amber),
                const Text('First 5 Conversations (Raw):',
                    style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(conversations.take(5).toList().toString(),
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 10)),
                const Divider(color: Colors.amber),
                const Text('Full Response:',
                    style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(debugData.toString(),
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close',
                  style: TextStyle(color: Colors.amber)),
            )
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Debug failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // skipLoadingOnRefresh: true (default in Riverpod 2) keeps previous data
    // visible while the auto-refresh fetch is running — no full-screen spinner.
    final inboxAsync = ref.watch(inboxProvider);
    final accountAsync = ref.watch(_inboxAccountProvider);
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final lang = ref.watch(settingsProvider).language;
    final theme = Theme.of(context);

    final String? myIgUserId = accountAsync.valueOrNull?.instagramUserId;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(S.tr('inbox', lang).toUpperCase(),
            style: TextStyle(color: theme.colorScheme.primary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
          // /inbox is a ShellRoute sibling of /posts — context.go is required;
          // Navigator.pop() does nothing inside the shell.
          onPressed: () => context.go('/posts'),
        ),
        actions: [
          if (_isSyncing)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary),
                ),
              ),
            ),
          IconButton(
            icon: Icon(Icons.sync_alt, color: theme.colorScheme.primary),
            tooltip: S.tr('syncChats', lang),
            onPressed: _isSyncing ? null : _syncInbox,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
            onPressed: () => ref.invalidate(inboxProvider),
          ),
          IconButton(
            icon: Icon(Icons.bug_report, color: theme.colorScheme.primary),
            onPressed: _showDebugInfo,
          ),
        ],
      ),
      body: inboxAsync.when(
        // Keep showing previous data while silently refreshing (no spinner flash)
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        data: (conversations) {
          // Silently update the selected conversation when inbox refreshes so
          // the chat thread sees fresh messages without closing/reopening.
          if (_selectedConversation != null) {
            final idx = conversations
                .indexWhere((c) => c.id == _selectedConversation!.id);
            if (idx != -1 &&
                !identical(conversations[idx], _selectedConversation)) {
              SchedulerBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(
                      () => _selectedConversation = conversations[idx]);
                }
              });
            }
          }

          if (conversations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      S.tr('noConversations', lang),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.7)),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _syncInbox,
                      icon: const Icon(Icons.sync),
                      label: Text(S.tr('syncChats', lang)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (isDesktop) {
            return Row(
              children: [
                SizedBox(
                  width: 350,
                  child: _ConversationList(
                    conversations: conversations,
                    selectedId: _selectedConversation?.id,
                    myIgUserId: myIgUserId,
                    onTap: (conv) =>
                        setState(() => _selectedConversation = conv),
                  ),
                ),
                VerticalDivider(width: 1, color: theme.dividerColor),
                Expanded(
                  child: _selectedConversation == null
                      ? Center(
                          child: Text(
                            S.tr('selectConversation', lang),
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.5)),
                          ),
                        )
                      : _ChatThread(
                          // ValueKey(id) ensures fresh state only on conv switch
                          key: ValueKey(_selectedConversation!.id),
                          conversation: _selectedConversation!,
                          myIgUserId: myIgUserId,
                          accountId:
                              accountAsync.valueOrNull?.id ?? '',
                        ),
                ),
              ],
            );
          }

          return _ConversationList(
            conversations: conversations,
            myIgUserId: myIgUserId,
            onTap: (conv) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: theme.colorScheme.surface,
                  body: _ChatThread(
                    conversation: conv,
                    myIgUserId: myIgUserId,
                    accountId: accountAsync.valueOrNull?.id ?? '',
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => Center(
            child: CircularProgressIndicator(
                color: theme.colorScheme.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Error: $e', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(inboxProvider),
                child: Text(S.tr('retry', lang)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Conversation list
// ─────────────────────────────────────────────────────────────────────────────

class _ConversationList extends ConsumerWidget {
  final List<IgConversation> conversations;
  final String? selectedId;
  final String? myIgUserId;
  final Function(IgConversation) onTap;

  const _ConversationList({
    required this.conversations,
    this.selectedId,
    this.myIgUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView.separated(
      itemCount: conversations.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),
      itemBuilder: (context, index) {
        final conv = conversations[index];
        final isSelected = conv.id == selectedId; // use conversation.id

        // Other participant: username > name > id > fallback
        final other = conv.getOtherParticipant(myIgUserId);
        final otherName = (other?['username'] as String?)?.isNotEmpty == true
            ? other!['username'] as String
            : (other?['name'] as String?)?.isNotEmpty == true
                ? other!['name'] as String
                : (other?['id'] as String?)?.isNotEmpty == true
                    ? other!['id'] as String
                    : conv.id;

        debugPrint('OTHER PARTICIPANT (conv ${conv.id}): $other');

        final lastMsg = conv.lastMessageText ?? '';
        final lastAt = conv.lastMessageAt != null
            ? DateFormat('MMM d, HH:mm')
                .format(conv.lastMessageAt!.toLocal())
            : '';

        return ListTile(
          selected: isSelected,
          selectedTileColor:
              theme.colorScheme.primary.withOpacity(0.1),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            backgroundImage: (conv.profilePicUrl != null &&
                    conv.profilePicUrl!.isNotEmpty)
                ? NetworkImage(conv.profilePicUrl!)
                : null,
            child: (conv.profilePicUrl == null ||
                    conv.profilePicUrl!.isEmpty)
                ? Text(
                    otherName.isNotEmpty
                        ? otherName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          title: Text(
            otherName,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            lastMsg,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7)),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                lastAt,
                style: theme.textTheme.labelSmall?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.5)),
              ),
              if (conv.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    conv.unreadCount.toString(),
                    style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          onTap: () => onTap(conv),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat thread
// ─────────────────────────────────────────────────────────────────────────────

class _ChatThread extends ConsumerStatefulWidget {
  final IgConversation conversation;

  /// social_accounts.id (UUID) — used as account_id for POST /api/messages/send
  final String accountId;

  /// My Instagram professional account ID — used to determine message ownership
  final String? myIgUserId;

  const _ChatThread({
    super.key,
    required this.conversation,
    required this.accountId,
    required this.myIgUserId,
  });

  @override
  ConsumerState<_ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends ConsumerState<_ChatThread> {
  final _messageController = TextEditingController();
  final List<IgMessage> _messages = [];
  bool _isLoadingMessages = true;
  Timer? _messagesRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Auto-refresh messages every 15 s while this chat is open
    _messagesRefreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadMessages(silent: true),
    );
  }

  @override
  void didUpdateWidget(_ChatThread old) {
    super.didUpdateWidget(old);
    // Reload whenever the conversation object changes (new conv selected, or
    // parent silently refreshed the selected conversation with fresh data)
    if (old.conversation.id != widget.conversation.id ||
        !identical(old.conversation, widget.conversation)) {
      _loadMessages(silent: old.conversation.id == widget.conversation.id);
    }
  }

  @override
  void dispose() {
    _messagesRefreshTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _isLoadingMessages = true);
    try {
      final embedded = widget.conversation.messages;
      debugPrint(
          'LOADED ${embedded.length} embedded messages '
          'for conversation ${widget.conversation.id} (silent=$silent)');
      setState(() {
        _messages.clear();
        _messages.addAll(embedded);
        _isLoadingMessages = false;
      });
    } catch (e) {
      debugPrint('LOAD MESSAGES ERROR: $e');
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading messages: $e')));
      }
      if (!silent) setState(() => _isLoadingMessages = false);
    }
  }

  /// Extracts the OTHER participant's IG-scoped user ID.
  String _getRecipientId() {
    final other =
        widget.conversation.getOtherParticipant(widget.myIgUserId);
    final recipientId = other?['id']?.toString();

    debugPrint('SELECTED ACCOUNT ID: ${widget.accountId}');
    debugPrint('MY IG USER ID: ${widget.myIgUserId}');
    debugPrint('SELECTED CONVERSATION ID: ${widget.conversation.id}');
    debugPrint('OTHER PARTICIPANT: $other');
    debugPrint('SEND MESSAGE RECIPIENT ID: $recipientId');

    if (recipientId == null || recipientId.isEmpty) {
      throw Exception(
          'Could not find recipient id. '
          'Participants: ${widget.conversation.rawParticipants}');
    }
    return recipientId;
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final text = _messageController.text.trim();
    _messageController.clear();

    try {
      final recipientId = _getRecipientId();
      debugPrint('SEND MESSAGE TEXT: $text');

      await ref.read(apiClientProvider).sendMessage(
            accountId: widget.accountId,
            recipientId: recipientId,
            message: text,
          );

      // Silent refresh after sending — don't flash loading
      _loadMessages(silent: true);
    } on DioException catch (e) {
      final data = e.response?.data;
      final errorMessage = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Send message failed';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Send failed: $errorMessage'),
            backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Send failed: $e'),
            backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final theme = Theme.of(context);

    // Other participant display name for app bar
    final other =
        widget.conversation.getOtherParticipant(widget.myIgUserId);
    final otherName = (other?['username'] as String?)?.isNotEmpty == true
        ? other!['username'] as String
        : (other?['name'] as String?)?.isNotEmpty == true
            ? other!['name'] as String
            : (other?['id'] as String?)?.isNotEmpty == true
                ? other!['id'] as String
                : widget.conversation.id;

    return Column(
      children: [
        // ── App bar ──────────────────────────────────────────────────────
        AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          title: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary,
                backgroundImage: (widget.conversation.profilePicUrl !=
                            null &&
                        widget.conversation.profilePicUrl!.isNotEmpty)
                    ? NetworkImage(widget.conversation.profilePicUrl!)
                    : null,
                child: (widget.conversation.profilePicUrl == null ||
                        widget.conversation.profilePicUrl!.isEmpty)
                    ? Icon(Icons.person,
                        color: theme.colorScheme.onPrimary, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(otherName, style: theme.textTheme.titleMedium),
                    if (widget.conversation.status != 'active')
                      Text(
                        widget.conversation.status,
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.5)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          leading: Navigator.canPop(context)
              ? IconButton(
                  icon: Icon(Icons.arrow_back,
                      color: theme.colorScheme.primary),
                  // Pop the MaterialPageRoute that was pushed for mobile chat view
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
              onPressed: () => _loadMessages(),
            ),
          ],
        ),
        Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),

        // ── Message list ─────────────────────────────────────────────────
        Expanded(
          child: _isLoadingMessages
              ? Center(
                  child: CircularProgressIndicator(
                      color: theme.colorScheme.primary))
              : _messages.isEmpty
                  ? Center(
                      child: Text(
                        S.tr('noMessages', lang),
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.5)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      reverse: true,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg =
                            _messages[_messages.length - 1 - index];

                        // Determine ownership using fromId first (Facebook API),
                        // fall back to direction field (DB records)
                        final fromId = msg.fromId;
                        final isMine = fromId != null
                            ? fromId == widget.myIgUserId
                            : msg.direction == 'outbound';

                        debugPrint(
                            'MESSAGE FROM ID: $fromId | IS MINE: $isMine | '
                            'MY IG: ${widget.myIgUserId}');

                        final senderLabel = isMine
                            ? 'You'
                            : otherName;

                        final msgText = (msg.text != null &&
                                msg.text!.isNotEmpty)
                            ? msg.text!
                            : '[Unsupported message type]';

                        final timeStr = DateFormat('HH:mm')
                            .format(msg.sentAt.toLocal());

                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: isMine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              // Sender label
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                child: Text(
                                  senderLabel,
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              // Message bubble
                              Align(
                                alignment: isMine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.72,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isMine
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.surfaceVariant,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft:
                                          Radius.circular(isMine ? 16 : 0),
                                      bottomRight:
                                          Radius.circular(isMine ? 0 : 16),
                                    ),
                                    border: isMine
                                        ? null
                                        : Border.all(
                                            color: theme.dividerColor
                                                .withOpacity(0.15)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msgText,
                                        style: TextStyle(
                                          color: isMine
                                              ? theme.colorScheme.onPrimary
                                              : theme.colorScheme.onSurface,
                                          fontSize: 15,
                                          fontStyle: (msg.text == null ||
                                                  msg.text!.isEmpty)
                                              ? FontStyle.italic
                                              : FontStyle.normal,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          color: isMine
                                              ? theme.colorScheme.onPrimary
                                                  .withOpacity(0.65)
                                              : theme.colorScheme.onSurface
                                                  .withOpacity(0.45),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),

        // ── Input bar ────────────────────────────────────────────────────
        Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: S.tr('typeMessage', lang),
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.5)),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon:
                      Icon(Icons.send, color: theme.colorScheme.onPrimary),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
