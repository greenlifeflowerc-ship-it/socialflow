import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/ig_models.dart';
import '../../../services/api_client.dart';
import '../../../services/settings_service.dart';
import 'package:intl/intl.dart';

final inboxProvider = FutureProvider.autoDispose<List<IgConversation>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.getConversations();
  final list = api.parseListFromAnyKey(response, ['conversations']);
  return (list).map((e) => IgConversation.fromJson(e)).toList();
});

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  IgConversation? _selectedConversation;
  bool _isSyncing = false;

  Future<void> _syncInbox() async {
    final lang = ref.read(settingsProvider).language;
    setState(() => _isSyncing = true);
    try {
      final response = await ref.read(apiClientProvider).syncConversations();
      debugPrint('Sync Inbox Full Response: $response');

      if (mounted) {
        if (response['ok'] == false) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text(S.tr('syncFailed', lang), style: const TextStyle(color: Colors.red)),
              content: SingleChildScrollView(
                child: Text(response.toString(), style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(S.tr('ok', lang), style: const TextStyle(color: Colors.amber)),
                )
              ],
            ),
          );
        } else {
          final errors = response['errors'] is List ? response['errors'] : [];
          final prevErrors = response['previousErrors'] is List ? response['previousErrors'] : [];
          
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.amber,
            content: Text(
              'Sync Result: ok=${response['ok']}, mode=${response['mode']}\n'
              'Convs: ${response['conversationsCount'] ?? 0}, Msgs: ${response['messagesCount'] ?? 0}\n'
              'Errors: ${errors.length}, PrevErrors: ${prevErrors.length}',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            duration: const Duration(seconds: 5),
          ));
        }
      }
      
      ref.invalidate(inboxProvider);
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
      final debugData = await ref.read(apiClientProvider).getDebugInbox();
      final conversations = ref.read(apiClientProvider).parseListFromAnyKey(debugData, ['conversations']);
      
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('Inbox Debug', style: TextStyle(color: Colors.amber)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Conversations Count: ${debugData['conversationsCount']}', style: const TextStyle(color: Colors.white)),
                Text('Messages Count: ${debugData['messagesCount']}', style: const TextStyle(color: Colors.white)),
                const Divider(color: Colors.amber),
                const Text('First 5 Conversations (Raw):', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  (conversations).take(5).toList().toString(),
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
                const Divider(color: Colors.amber),
                const Text('Full Response:', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  debugData.toString(),
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.amber)),
            )
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Debug failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inboxAsync = ref.watch(inboxProvider);
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final lang = ref.watch(settingsProvider).language;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(S.tr('inbox', lang).toUpperCase(), style: TextStyle(color: theme.colorScheme.primary)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isSyncing)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
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
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      S.tr('noConversations', lang),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
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
                    onTap: (conv) => setState(() => _selectedConversation = conv),
                  ),
                ),
                VerticalDivider(width: 1, color: theme.dividerColor),
                Expanded(
                  child: _selectedConversation == null
                      ? Center(
                          child: Text(
                            S.tr('selectConversation', lang),
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                          ),
                        )
                      : _ChatThread(conversation: _selectedConversation!),
                ),
              ],
            );
          }

          return _ConversationList(
            conversations: conversations,
            onTap: (conv) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => Scaffold(
                  backgroundColor: theme.colorScheme.surface,
                  body: _ChatThread(conversation: conv),
                ),
              ),
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
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

class _ConversationList extends ConsumerWidget {
  final List<IgConversation> conversations;
  final String? selectedId;
  final Function(IgConversation) onTap;

  const _ConversationList({required this.conversations, this.selectedId, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListView.separated(
      itemCount: conversations.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),
      itemBuilder: (context, index) {
        final conv = conversations[index];
        final isSelected = conv.id == selectedId;
        
        final lastMsg = conv.lastMessageText ?? '';
        final lastAt = conv.lastMessageAt != null 
            ? DateFormat('MMM d, HH:mm').format(conv.lastMessageAt!.toLocal())
            : '';

        return ListTile(
          selected: isSelected,
          selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            backgroundImage: (conv.profilePicUrl != null && conv.profilePicUrl!.isNotEmpty)
                ? NetworkImage(conv.profilePicUrl!)
                : null,
            child: (conv.profilePicUrl == null || conv.profilePicUrl!.isEmpty)
                ? Text(
                    (conv.username ?? conv.igScopedUserId ?? '?')[0].toUpperCase(),
                    style: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          title: Text(
            conv.username ?? conv.igScopedUserId ?? 'Unknown',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            lastMsg,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                lastAt,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
              ),
              if (conv.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    conv.unreadCount.toString(),
                    style: TextStyle(fontSize: 10, color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
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

class _ChatThread extends ConsumerStatefulWidget {
  final IgConversation conversation;
  const _ChatThread({required this.conversation});

  @override
  ConsumerState<_ChatThread> createState() => _ChatThreadState();
}

class _ChatThreadState extends ConsumerState<_ChatThread> {
  final _messageController = TextEditingController();
  final List<IgMessage> _messages = [];
  bool _isLoadingMessages = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.getMessages(widget.conversation.id, sync: true);
      final list = api.parseListFromAnyKey(response, ['messages']);
      setState(() {
        _messages.clear();
        _messages.addAll((list).map((e) => IgMessage.fromJson(e)).toList());
        _isLoadingMessages = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading messages: $e')));
      }
      setState(() => _isLoadingMessages = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final text = _messageController.text;
    _messageController.clear();
    
    try {
      await ref.read(apiClientProvider).sendTextMessage(
        conversationId: widget.conversation.id,
        recipientId: widget.conversation.igScopedUserId!,
        text: text,
      );
      _loadMessages();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final theme = Theme.of(context);
    return Column(
      children: [
        AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          title: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary,
                backgroundImage: (widget.conversation.profilePicUrl != null && widget.conversation.profilePicUrl!.isNotEmpty)
                    ? NetworkImage(widget.conversation.profilePicUrl!)
                    : null,
                child: (widget.conversation.profilePicUrl == null || widget.conversation.profilePicUrl!.isEmpty)
                    ? Icon(Icons.person, color: theme.colorScheme.onPrimary, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.conversation.username ?? widget.conversation.igScopedUserId ?? 'Chat',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (widget.conversation.status != 'active')
                      Text(
                        widget.conversation.status,
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          leading: Navigator.canPop(context) 
              ? IconButton(
                  icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
              onPressed: _loadMessages,
            ),
          ],
        ),
        Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),
        Expanded(
          child: _isLoadingMessages 
            ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
            : _messages.isEmpty
              ? Center(
                  child: Text(
                    S.tr('noMessages', lang),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  reverse: true,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[_messages.length - 1 - index];
                    final isMe = msg.direction == 'outbound';
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 16),
                          ),
                          border: isMe ? null : Border.all(color: theme.dividerColor.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.text ?? '',
                              style: TextStyle(
                                color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('HH:mm').format(msg.sentAt.toLocal()),
                              style: TextStyle(
                                color: isMe ? theme.colorScheme.onPrimary.withOpacity(0.7) : theme.colorScheme.onSurface.withOpacity(0.5),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
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
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                  icon: Icon(Icons.send, color: theme.colorScheme.onPrimary),
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
