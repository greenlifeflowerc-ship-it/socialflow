import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/prompt_builder.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/ai_studio_models.dart';
import '../../../services/api_client.dart';
import '../../../services/settings_service.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AiChatMessage> _messages = [];
  bool _isLoading = false;
  bool _useBrandContext = true;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final settings = ref.read(settingsProvider);
    final profile = settings.brandProfile;

    // Guard: model must be selected
    if (settings.selectedTextModel == null) {
      _showError('No AI model selected. Go to Settings → Configurations → Refresh Available Models.');
      return;
    }

    final userMessage = AiChatMessage(
      id: DateTime.now().toString(),
      conversationId: 'current',
      role: 'user',
      text: text,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      // Guard: brand toggle on but profile not configured
      if (_useBrandContext && !profile.isConfigured) {
        _showError('Set up your AI Brand Profile first or turn off Brand context.');
        setState(() => _isLoading = false);
        return;
      }

      // Build finalPrompt: optionally prepend brand context
      final String finalPrompt;
      if (_useBrandContext && profile.isConfigured) {
        final systemCtx = AiPromptBuilder.buildChatSystemContext(profile);
        final history = _messages
            .where((m) => m.role != 'user' || m.text != text)
            .map((m) => '${m.role == 'user' ? 'User' : 'Assistant'}: ${m.text}')
            .join('\n');
        finalPrompt = history.isNotEmpty
            ? '$systemCtx\n\nConversation so far:\n$history\n\nUser question: $text'
            : '$systemCtx\n\nUser question: $text';
      } else {
        finalPrompt = text;
      }

      final apiKey = settings.geminiApiKey;
      final response = await ref.read(apiClientProvider).aiChat({
        'model': settings.selectedTextModel,
        'prompt': finalPrompt,
        if (apiKey != null && apiKey.isNotEmpty) 'api_key': apiKey,
      });

      if (response['ok'] == true) {
        final reply = response['text'] as String?
            ?? response['result']?['text'] as String?
            ?? '';
        final assistantMessage = AiChatMessage(
          id: '${DateTime.now().millisecondsSinceEpoch}',
          conversationId: 'current',
          role: 'assistant',
          text: reply,
          createdAt: DateTime.now(),
        );
        setState(() => _messages.add(assistantMessage));
        _scrollToBottom();
      } else {
        _showError(response['error']?.toString() ?? 'AI response failed. Please try again.');
      }
    } on Exception catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;
    final settings = ref.watch(settingsProvider);
    final profile = settings.brandProfile;
    final lang = settings.language;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.tr('aiChat', lang).toUpperCase()),
        actions: [
          if (profile.isConfigured)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(S.tr('brandProfile', lang), style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w600)),
                Switch(
                  value: _useBrandContext,
                  onChanged: (v) => setState(() => _useBrandContext = v),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ]),
            ),
        ],
      ),
      body: Column(
        children: [
          // Brand context indicator
          if (profile.isConfigured && _useBrandContext)
            Container(
              width: double.infinity,
              color: gold.withValues(alpha: 0.07),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(children: [
                Icon(Icons.verified_rounded, color: gold, size: 12),
                const SizedBox(width: 6),
                Text('AI knows: ${profile.businessName}', style: TextStyle(color: gold, fontSize: 11)),
              ]),
            ),

          // Messages
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState(profile.isConfigured, gold)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _ChatBubble(message: msg, gold: gold);
                    },
                  ),
          ),

          // Loading
          if (_isLoading)
            LinearProgressIndicator(color: gold, backgroundColor: gold.withValues(alpha: 0.15)),

          // Input
          _ChatInput(
            controller: _messageController,
            onSend: _sendMessage,
            isLoading: _isLoading,
            gold: gold,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool hasProfile, Color gold) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.chat_bubble_outline_rounded, size: 64, color: gold.withValues(alpha: 0.2)),
        const SizedBox(height: 16),
        Text(
          hasProfile ? 'Ask anything about your brand,\ncontent or Instagram strategy.' : 'Start a conversation.\nSet up Brand Profile for personalised answers.',
          style: const TextStyle(color: Colors.white38, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final AiChatMessage message;
  final Color gold;
  const _ChatBubble({required this.message, required this.gold});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? gold : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: isUser ? null : Border.all(color: gold.withValues(alpha: 0.15)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: SelectableText(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.black : Colors.white,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _ChatInput extends ConsumerWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;
  final Color gold;
  const _ChatInput({required this.controller, required this.onSend, required this.isLoading, required this.gold});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: gold.withValues(alpha: 0.1))),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: S.tr('askAiHint', lang),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: isLoading ? null : (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(color: isLoading ? Colors.grey : gold, shape: BoxShape.circle),
            child: IconButton(
              icon: Icon(Icons.send_rounded, color: isLoading ? Colors.white38 : Colors.black, size: 20),
              onPressed: isLoading ? null : onSend,
            ),
          ),
        ]),
      ),
    );
  }
}
