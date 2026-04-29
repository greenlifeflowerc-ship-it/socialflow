import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/ig_models.dart';
import '../../../services/api_client.dart';
import '../../../services/settings_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

final commentMediaProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.getCommentMedia();
  final list = api.parseListFromAnyKey(response, ['media']);
  return List<Map<String, dynamic>>.from(list);
});

final allCommentsProvider = FutureProvider.autoDispose<List<IgMediaComment>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.getComments();
  final list = api.parseListFromAnyKey(response, ['comments']);
  return (list).map((e) => IgMediaComment.fromJson(e)).toList();
});

final commentsByMediaProvider = FutureProvider.family.autoDispose<List<IgMediaComment>, String?>((ref, igMediaId) async {
  final api = ref.read(apiClientProvider);
  final response = await api.getComments(igMediaId: igMediaId);
  final list = api.parseListFromAnyKey(response, ['comments']);
  return (list).map((e) => IgMediaComment.fromJson(e)).toList();
});

class CommentsScreen extends ConsumerStatefulWidget {
  const CommentsScreen({super.key});

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedMediaId;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _syncAllComments() async {
    final lang = ref.read(settingsProvider).language;
    setState(() => _isSyncing = true);
    try {
      final response = await ref.read(apiClientProvider).syncAllComments();
      debugPrint('Sync All Comments Full Response: $response');
      
      if (mounted) {
        if (response['ok'] == false) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.grey[900],
              title: Text(S.tr('syncFailed', lang), style: const TextStyle(color: Colors.red)),
              content: SingleChildScrollView(child: Text(response.toString(), style: const TextStyle(color: Colors.white, fontSize: 12))),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(S.tr('ok', lang), style: const TextStyle(color: Colors.amber)))],
            ),
          );
        } else {
          final errors = response['errors'] is List ? response['errors'] : [];
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.amber,
            content: Text(
              'Sync complete: ${response['mediaCount'] ?? 0} media, ${response['commentsCount'] ?? 0} comments, ${errors.length} errors',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ));
        }
      }
      
      ref.invalidate(commentMediaProvider);
      ref.invalidate(allCommentsProvider);
      if (_selectedMediaId != null) {
        ref.invalidate(commentsByMediaProvider(_selectedMediaId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showDebugInfo() async {
    try {
      final debugData = await ref.read(apiClientProvider).getDebugComments();
      final api = ref.read(apiClientProvider);
      final comments = api.parseListFromAnyKey(debugData, ['comments']);
      final count = debugData['count'] ?? (comments).length;
      
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('Comments Debug', style: TextStyle(color: Colors.amber)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total Count: $count', style: const TextStyle(color: Colors.white)),
                const Divider(color: Colors.amber),
                const Text('First 5 Comments (Raw):', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                Text((comments).take(5).toList().toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                const Divider(color: Colors.amber),
                const Text('Full Backend Response:', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                Text(debugData.toString(), style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Colors.amber)))],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Debug failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(S.tr('comments', lang).toUpperCase(), style: const TextStyle(color: Colors.amber)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.amber),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isSyncing)
            const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)))),
          IconButton(icon: const Icon(Icons.sync_alt, color: Colors.amber), tooltip: S.tr('syncAllComments', lang), onPressed: _isSyncing ? null : _syncAllComments),
          IconButton(icon: const Icon(Icons.refresh, color: Colors.amber), onPressed: () {
            ref.invalidate(commentMediaProvider);
            ref.invalidate(allCommentsProvider);
            if (_selectedMediaId != null) ref.invalidate(commentsByMediaProvider(_selectedMediaId));
          }),
          IconButton(icon: const Icon(Icons.bug_report, color: Colors.amber), onPressed: _showDebugInfo),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: S.tr('allComments', lang)),
            Tab(text: S.tr('byMedia', lang)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllCommentsTab(),
          _buildByMediaTab(),
        ],
      ),
    );
  }

  Widget _buildAllCommentsTab() {
    final commentsAsync = ref.watch(allCommentsProvider);
    final lang = ref.watch(settingsProvider).language;
    return commentsAsync.when(
      data: (comments) => _buildCommentsList(comments, 'No comments loaded. Tap Sync All Comments or open Debug.', lang),
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.amber)),
      error: (e, _) => _buildErrorState(e, () => ref.refresh(allCommentsProvider)),
    );
  }

  Widget _buildByMediaTab() {
    final mediaAsync = ref.watch(commentMediaProvider);
    final commentsAsync = _selectedMediaId == null 
        ? const AsyncValue.data(<IgMediaComment>[]) 
        : ref.watch(commentsByMediaProvider(_selectedMediaId));
    final lang = ref.watch(settingsProvider).language;

    return Column(
      children: [
        _buildMediaSelector(mediaAsync),
        const Divider(height: 1, color: Colors.white10),
        Expanded(
          child: commentsAsync.when(
            data: (comments) {
              if (_selectedMediaId == null) {
                return const Center(child: Text('Select a media item above to see its comments.', style: TextStyle(color: Colors.white54)));
              }
              return _buildCommentsList(comments, 'No comments for this media. Tap sync if you think there should be some.', lang);
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.amber)),
            error: (e, _) => _buildErrorState(e, () => ref.refresh(commentsByMediaProvider(_selectedMediaId))),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsList(List<IgMediaComment> comments, String emptyMessage, String lang) {
    if (comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.comment_bank_outlined, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              Text(emptyMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _syncAllComments, 
                icon: const Icon(Icons.sync),
                label: Text(S.tr('syncAllComments', lang)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: comments.length,
      itemBuilder: (context, index) => _CommentCard(comment: comments[index]),
    );
  }

  Widget _buildErrorState(Object e, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error: $e', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry, 
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSelector(AsyncValue<List<Map<String, dynamic>>> mediaAsync) {
    return mediaAsync.when(
      data: (mediaList) {
        if (mediaList.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('No media synced. Tap sync to load Instagram posts.', style: TextStyle(color: Colors.white54)));
        return SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: mediaList.length,
            itemBuilder: (context, index) {
              final item = mediaList[index];
              final isSelected = _selectedMediaId == item['igMediaId'];
              return GestureDetector(
                onTap: () => setState(() => _selectedMediaId = item['igMediaId']),
                child: Container(
                  width: 80,
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: isSelected ? Colors.amber : Colors.transparent, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: item['mediaUrl'] ?? '', 
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[900]),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.white24),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: Colors.amber))),
      error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Error loading media: $e', style: const TextStyle(color: Colors.red))),
    );
  }
}

class _CommentCard extends ConsumerWidget {
  final IgMediaComment comment;
  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(settingsProvider).language;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.white10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  comment.username ?? comment.userId ?? 'Unknown', 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)
                ),
                const Spacer(),
                Text(
                  comment.timestamp.toLocal().toString().substring(0, 16), 
                  style: const TextStyle(fontSize: 10, color: Colors.white54)
                ),
              ],
            ),
            if (comment.igMediaId != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Media ID: ${comment.igMediaId}', style: const TextStyle(fontSize: 9, color: Colors.white38)),
              ),
            const SizedBox(height: 8),
            Text(comment.text, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 12),
            Row(
              children: [
                if (comment.repliedByApp) _Badge(text: S.tr('replied', lang), color: Colors.green),
                if (comment.privateRepliedByApp) _Badge(text: S.tr('private', lang), color: Colors.blue),
                const Spacer(),
                TextButton(
                  onPressed: () => _showReplyDialog(context, ref, isPrivate: false, lang: lang),
                  child: Text(S.tr('reply', lang), style: const TextStyle(color: Colors.amber, fontSize: 13)),
                ),
                TextButton(
                  onPressed: () => _showReplyDialog(context, ref, isPrivate: true, lang: lang),
                  child: Text(S.tr('private', lang), style: const TextStyle(color: Colors.blueAccent, fontSize: 13)),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite_border, size: 18, color: Colors.white54),
                  onPressed: () async {
                    try {
                      await ref.read(apiClientProvider).likeComment(comment.id);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Liked!'), backgroundColor: Colors.amber,));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Like failed or not supported.'), backgroundColor: Colors.red,));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReplyDialog(BuildContext context, WidgetRef ref, {required bool isPrivate, required String lang}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(isPrivate ? S.tr('private', lang) : S.tr('reply', lang), style: const TextStyle(color: Colors.amber)),
        content: TextField(
          controller: controller, 
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: S.tr('enterMessage', lang),
            hintStyle: const TextStyle(color: Colors.white30),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber, width: 2)),
          )
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(S.tr('cancel', lang), style: const TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              try {
                if (isPrivate) {
                  await ref.read(apiClientProvider).privateReplyToComment(commentId: comment.id, message: controller.text);
                } else {
                  await ref.read(apiClientProvider).replyToComment(commentId: comment.id, message: controller.text);
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent!'), backgroundColor: Colors.green,));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red,));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: Text(S.tr('send', lang)),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color, width: 0.5)),
      child: Text(text, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
