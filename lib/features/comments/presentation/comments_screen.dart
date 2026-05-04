import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../models/social_account.dart';
import '../../../services/api_client.dart';
import '../../../services/accounts_service.dart';
import '../../../services/settings_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

/// GET /api/instagram/media?account_id={accountId}
///
/// Backend response shape:
/// { "ok": true, "media": { "data": [ {...}, ... ], "paging": {} } }
/// The provider handles both the nested map shape and a flat list shape.
final igMediaProvider =
    FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>(
  (ref, accountId) async {
    final api = ref.read(apiClientProvider);
    try {
      final response = await api.getInstagramMedia(accountId);

      debugPrint('INSTAGRAM MEDIA RAW RESPONSE: $response');

      // "media" can be:
      //   • a Map  → { "data": [...], "paging": {} }  (Facebook paged response)
      //   • a List → already the flat array
      final mediaRoot = response['media'];
      debugPrint('MEDIA ROOT TYPE: ${mediaRoot.runtimeType}');

      final List<dynamic> mediaList = mediaRoot is Map &&
              mediaRoot['data'] is List
          ? mediaRoot['data'] as List<dynamic>
          : mediaRoot is List
              ? mediaRoot as List<dynamic>
              : (response['data'] is List
                  ? response['data'] as List<dynamic>
                  : <dynamic>[]);

      debugPrint('MEDIA COUNT: ${mediaList.length}');

      return mediaList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on DioException catch (e) {
      debugPrint('COMMENTS FAILED URL: ${e.requestOptions.uri}');
      debugPrint('COMMENTS FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('COMMENTS FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('COMMENTS FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Failed to load Instagram media';
      throw Exception(message);
    }
  },
);

/// GET /api/instagram/media/{mediaId}/comments?account_id={accountId}
///
/// Backend response shape:
/// { "ok": true, "comments": { "data": [ {...} ], "paging": {} } }
final igMediaCommentsProvider = FutureProvider.family
    .autoDispose<List<Map<String, dynamic>>, (String, String)>(
  (ref, params) async {
    final (mediaId, accountId) = params;
    final api = ref.read(apiClientProvider);
    try {
      final response =
          await api.getInstagramMediaComments(mediaId, accountId);

      debugPrint('COMMENTS RAW RESPONSE: $response');

      // "comments" can be a paged Map { "data": [...] } or already a List
      final commentsRoot = response['comments'];
      debugPrint('COMMENTS ROOT TYPE: ${commentsRoot.runtimeType}');

      final List<dynamic> commentsList =
          commentsRoot is Map && commentsRoot['data'] is List
              ? commentsRoot['data'] as List<dynamic>
              : commentsRoot is List
                  ? commentsRoot as List<dynamic>
                  : (response['data'] is List
                      ? response['data'] as List<dynamic>
                      : <dynamic>[]);

      debugPrint('COMMENTS COUNT: ${commentsList.length}');

      return commentsList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on DioException catch (e) {
      debugPrint('COMMENTS FAILED URL: ${e.requestOptions.uri}');
      debugPrint('COMMENTS FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('COMMENTS FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('COMMENTS FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Failed to load comments';
      throw Exception(message);
    }
  },
);

/// GET /api/instagram/comments/all?account_id={accountId}
/// Returns a list of media groups, each with embedded comments.
final igAllCommentsProvider =
    FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>(
  (ref, accountId) async {
    final api = ref.read(apiClientProvider);
    try {
      final response = await api.getInstagramAllComments(accountId);

      // Safely resolve the top-level list — never hard-cast to List?
      dynamic raw = response['media'] ??
          response['groups'] ??
          response['data'] ??
          response['items'];

      // Handle paged Map shape: { "data": [...] }
      final List<dynamic> list = raw is Map && raw['data'] is List
          ? raw['data'] as List<dynamic>
          : raw is List
              ? raw as List<dynamic>
              : <dynamic>[];

      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on DioException catch (e) {
      debugPrint('COMMENTS FAILED URL: ${e.requestOptions.uri}');
      debugPrint('COMMENTS FAILED METHOD: ${e.requestOptions.method}');
      debugPrint('COMMENTS FAILED STATUS: ${e.response?.statusCode}');
      debugPrint('COMMENTS FAILED DATA: ${e.response?.data}');
      final data = e.response?.data;
      final message = data is Map && data['error'] != null
          ? data['error'].toString()
          : e.message ?? 'Failed to load all comments';
      throw Exception(message);
    }
  },
);

// ─── Screen ──────────────────────────────────────────────────────────────────

class CommentsScreen extends ConsumerStatefulWidget {
  const CommentsScreen({super.key});

  @override
  ConsumerState<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends ConsumerState<CommentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _mediaScrollController = ScrollController();
  SocialAccount? _selectedAccount;
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
    _mediaScrollController.dispose();
    super.dispose();
  }

  void _scrollMediaLeft() {
    _mediaScrollController.animateTo(
      (_mediaScrollController.offset - 350).clamp(
          0.0, _mediaScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _scrollMediaRight() {
    _mediaScrollController.animateTo(
      (_mediaScrollController.offset + 350).clamp(
          0.0, _mediaScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _invalidateAll() {
    if (_selectedAccount == null) return;
    final id = _selectedAccount!.id;
    ref.invalidate(igMediaProvider(id));
    ref.invalidate(igAllCommentsProvider(id));
    if (_selectedMediaId != null) {
      ref.invalidate(igMediaCommentsProvider((_selectedMediaId!, id)));
    }
  }

  Future<void> _syncAllComments() async {
    setState(() => _isSyncing = true);
    try {
      _invalidateAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.amber,
          content: Text('Comments refreshed.',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          duration: Duration(seconds: 3),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(settingsProvider).language;
    final accountsAsync = ref.watch(socialAccountsProvider);

    // Auto-select first account once loaded
    accountsAsync.whenData((accounts) {
      if (_selectedAccount == null && accounts.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedAccount = accounts.first);
        });
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(S.tr('comments', lang).toUpperCase(),
            style: const TextStyle(color: Colors.amber)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.amber),
          // /comments is a ShellRoute sibling — Navigator.pop() is a no-op here.
          onPressed: () => context.go('/posts'),
        ),
        actions: [
          if (_isSyncing)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.amber),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.amber),
            tooltip: 'Refresh comments',
            onPressed: _isSyncing ? null : _syncAllComments,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAccountSelector(accountsAsync),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.amber,
                labelColor: Colors.amber,
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(text: 'By Media'),
                  Tab(text: 'All Comments'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _selectedAccount == null
          ? const Center(
              child: Text('Select an account to view comments.',
                  style: TextStyle(color: Colors.white54)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildByMediaTab(),
                _buildAllCommentsTab(),
              ],
            ),
    );
  }

  // ─── Account selector ──────────────────────────────────────────────────────

  Widget _buildAccountSelector(AsyncValue<List<SocialAccount>> accountsAsync) {
    return accountsAsync.when(
      data: (accounts) {
        if (accounts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text('No connected Instagram accounts.',
                style: TextStyle(color: Colors.red, fontSize: 12)),
          );
        }
        final current = accounts.contains(_selectedAccount)
            ? _selectedAccount!
            : accounts.first;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<SocialAccount>(
              value: current,
              isExpanded: true,
              dropdownColor: Colors.grey[900],
              iconEnabledColor: Colors.amber,
              style: const TextStyle(color: Colors.white),
              items: accounts
                  .map((a) => DropdownMenuItem(
                        value: a,
                        child: Text(a.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white)),
                      ))
                  .toList(),
              onChanged: (a) {
                if (a != null) {
                  setState(() {
                    _selectedAccount = a;
                    _selectedMediaId = null;
                  });
                }
              },
            ),
          ),
        );
      },
      loading: () => const SizedBox(
          height: 40,
          child: Center(
              child: LinearProgressIndicator(
                  backgroundColor: Colors.black, color: Colors.amber))),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text('Could not load accounts: $e',
            style: const TextStyle(color: Colors.red, fontSize: 11)),
      ),
    );
  }

  // ─── By Media tab ──────────────────────────────────────────────────────────

  Widget _buildByMediaTab() {
    final accountId = _selectedAccount!.id;
    final mediaAsync = ref.watch(igMediaProvider(accountId));
    final commentsAsync = _selectedMediaId == null
        ? const AsyncValue<List<Map<String, dynamic>>>.data([])
        : ref.watch(igMediaCommentsProvider((_selectedMediaId!, accountId)));

    return Column(
      children: [
        _buildMediaSelector(mediaAsync),
        const Divider(height: 1, color: Colors.white10),
        Expanded(
          child: commentsAsync.when(
            skipLoadingOnRefresh: true,
            data: (comments) {
              if (_selectedMediaId == null) {
                return const Center(
                  child: Text(
                    'Select a media item above to see its comments.',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }
              if (comments.isEmpty) {
                return _buildEmptyState('No comments for this post.');
              }
              return _buildFlatCommentsList(comments, accountId);
            },
            loading: () => const Center(
                child: CircularProgressIndicator(color: Colors.amber)),
            error: (e, _) => _buildErrorState(
              e,
              () => ref.invalidate(
                  igMediaCommentsProvider((_selectedMediaId!, accountId))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaSelector(
      AsyncValue<List<Map<String, dynamic>>> mediaAsync) {
    return mediaAsync.when(
      data: (mediaList) {
        if (mediaList.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No Instagram media found.',
                style: TextStyle(color: Colors.white54)),
          );
        }
        return SizedBox(
          height: 150,
          child: Row(
            children: [
              // ← left arrow
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.amber),
                onPressed: _scrollMediaLeft,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28),
              ),
              // horizontal scrollable media strip
              Expanded(
                child: Scrollbar(
                  controller: _mediaScrollController,
                  thumbVisibility: true,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                        PointerDeviceKind.trackpad,
                      },
                    ),
                    child: ListView.builder(
                      controller: _mediaScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      itemCount: mediaList.length,
                      itemBuilder: (context, index) {
                        final item = mediaList[index];
                        final mediaId = (item['id'] ?? '').toString();
                        if (mediaId.isEmpty) return const SizedBox.shrink();
                        final isSelected = _selectedMediaId == mediaId;
                        final thumbUrl = (item['thumbnail_url'] ??
                                item['media_url'] ??
                                item['image_url'] ??
                                '')
                            .toString();
                        final caption =
                            (item['caption'] ?? '').toString();
                        final commentsCount =
                            item['comments_count'] ?? 0;
                        final mediaType =
                            (item['media_type'] ?? '').toString();
                        final timestamp =
                            item['timestamp']?.toString();

                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedMediaId = mediaId),
                          child: Container(
                            width: 95,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: isSelected
                                      ? Colors.amber
                                      : Colors.white12,
                                  width: 2),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[900],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius:
                                        const BorderRadius.vertical(
                                            top: Radius.circular(6)),
                                    child: thumbUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: thumbUrl,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            placeholder: (c, u) =>
                                                Container(
                                                    color:
                                                        Colors.grey[850]),
                                            errorWidget: (c, u, e) =>
                                                const Center(
                                                    child: Icon(
                                                        Icons.broken_image,
                                                        color: Colors
                                                            .white24)),
                                          )
                                        : Center(
                                            child: Icon(
                                              mediaType == 'VIDEO'
                                                  ? Icons.videocam_outlined
                                                  : Icons.image_outlined,
                                              color: Colors.white24,
                                            ),
                                          ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.comment,
                                          size: 10, color: Colors.amber),
                                      const SizedBox(width: 2),
                                      Text('$commentsCount',
                                          style: const TextStyle(
                                              color: Colors.amber,
                                              fontSize: 9)),
                                      const Spacer(),
                                      if (mediaType.isNotEmpty)
                                        Text(
                                          mediaType == 'CAROUSEL_ALBUM'
                                              ? '🗂'
                                              : mediaType == 'VIDEO'
                                                  ? '🎥'
                                                  : '📷',
                                          style: const TextStyle(
                                              fontSize: 9),
                                        ),
                                    ],
                                  ),
                                ),
                                if (caption.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 4, right: 4, bottom: 2),
                                    child: Text(caption,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 8)),
                                  ),
                                if (timestamp != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 4, right: 4, bottom: 3),
                                    child: Text(_fmtDate(timestamp),
                                        style: const TextStyle(
                                            color: Colors.white24,
                                            fontSize: 7)),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // → right arrow
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.amber),
                onPressed: _scrollMediaRight,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
          height: 150,
          child:
              Center(child: CircularProgressIndicator(color: Colors.amber))),
      error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Error loading media: $e',
              style: const TextStyle(color: Colors.red))),
    );
  }

  // ─── All Comments tab ──────────────────────────────────────────────────────

  Widget _buildAllCommentsTab() {
    final accountId = _selectedAccount!.id;
    final grouped = ref.watch(igAllCommentsProvider(accountId));

    return grouped.when(
      skipLoadingOnRefresh: true,
      data: (groups) {
        if (groups.isEmpty) {
          return _buildEmptyState('No comments found on this account.');
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            // comments inside a group can be a paged Map or a plain List
            final commentsRaw = group['comments'];
            final List<dynamic> commentsList =
                commentsRaw is Map && commentsRaw['data'] is List
                    ? commentsRaw['data'] as List<dynamic>
                    : commentsRaw is List
                        ? commentsRaw as List<dynamic>
                        : <dynamic>[];
            final comments = commentsList
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
            return _MediaGroupCard(
              media: group,
              comments: comments,
              accountId: accountId,
            );
          },
        );
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.amber)),
      error: (e, _) => _buildErrorState(
          e, () => ref.invalidate(igAllCommentsProvider(accountId))),
    );
  }

  // ─── Shared helpers ────────────────────────────────────────────────────────

  Widget _buildFlatCommentsList(
      List<Map<String, dynamic>> comments, String accountId) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20, top: 4),
      itemCount: comments.length,
      itemBuilder: (context, index) =>
          _CommentCard(comment: comments[index], accountId: accountId),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.comment_bank_outlined,
                size: 64, color: Colors.amber),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _syncAllComments,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, foregroundColor: Colors.black),
            ),
          ],
        ),
      ),
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
            Text('Error: $e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber, foregroundColor: Colors.black),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmtDate(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }
}

// ─── Media Group Card (All Comments tab) ─────────────────────────────────────

class _MediaGroupCard extends StatelessWidget {
  final Map<String, dynamic> media;
  final List<Map<String, dynamic>> comments;
  final String accountId;

  const _MediaGroupCard({
    required this.media,
    required this.comments,
    required this.accountId,
  });

  @override
  Widget build(BuildContext context) {
    final thumbUrl =
        (media['thumbnail_url'] ?? media['media_url'] ?? '').toString();
    final caption = (media['caption'] ?? '').toString();
    final timestamp = media['timestamp']?.toString();
    final permalink = media['permalink']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Media header ────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: thumbUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorWidget: (c, u, e) => const SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(Icons.broken_image,
                                color: Colors.white24)),
                      )
                    : const SizedBox(
                        width: 56,
                        height: 56,
                        child: Icon(Icons.image_outlined,
                            color: Colors.white24)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (caption.isNotEmpty)
                      Text(caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    if (timestamp != null)
                      Text(_fmtTimestamp(timestamp),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 10)),
                    if (permalink != null && permalink.isNotEmpty)
                      Text(permalink,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.blueAccent, fontSize: 9)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber, width: 0.5),
                ),
                child: Text('${comments.length}',
                    style:
                        const TextStyle(color: Colors.amber, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // ── Comments list ───────────────────────────────────────────────
          if (comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('No comments.',
                  style: TextStyle(color: Colors.white38, fontSize: 12)),
            )
          else
            ...comments.map(
                (c) => _CommentCard(comment: c, accountId: accountId)),
          const Divider(color: Colors.white10, height: 20),
        ],
      ),
    );
  }

  static String _fmtTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }
}

// ─── Comment Card ─────────────────────────────────────────────────────────────

class _CommentCard extends ConsumerWidget {
  final Map<String, dynamic> comment;
  final String accountId;

  const _CommentCard({required this.comment, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentId = (comment['id'] ?? '').toString();
    final username = _username();
    final text = (comment['text'] ?? comment['message'] ?? '').toString();
    final timestamp = comment['timestamp']?.toString();
    final likeCount = comment['like_count'] ?? 0;

    // replies can be { "data": [...] } (Facebook paged) or a plain List
    final repliesRoot = comment['replies'];
    final List<dynamic> repliesList =
        repliesRoot is Map && repliesRoot['data'] is List
            ? repliesRoot['data'] as List<dynamic>
            : repliesRoot is List
                ? repliesRoot as List<dynamic>
                : <dynamic>[];
    final replies = repliesList
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.white10)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.account_circle, size: 16, color: Colors.amber),
                const SizedBox(width: 4),
                Text(username,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                        fontSize: 13)),
                const Spacer(),
                if (timestamp != null)
                  Text(_fmtTimestamp(timestamp),
                      style: const TextStyle(
                          fontSize: 9, color: Colors.white54)),
              ],
            ),
            const SizedBox(height: 6),
            // Comment text
            Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            const SizedBox(height: 6),
            // Stats + reply
            Row(
              children: [
                const Icon(Icons.favorite, size: 12, color: Colors.white38),
                const SizedBox(width: 3),
                Text('$likeCount',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                if (replies.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  const Icon(Icons.reply, size: 12, color: Colors.white38),
                  const SizedBox(width: 3),
                  Text('${replies.length}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11)),
                ],
                const Spacer(),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 0),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: commentId.isNotEmpty
                      ? () => _showReplyDialog(context, ref, commentId)
                      : null,
                  child: const Text('Reply',
                      style: TextStyle(color: Colors.amber, fontSize: 12)),
                ),
              ],
            ),
            // Embedded replies
            if (replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 14, top: 4),
                child: Column(
                  children:
                      replies.map((r) => _ReplyItem(reply: r)).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _username() {
    if (comment['from'] is Map) {
      final from = comment['from'] as Map;
      return from['username']?.toString() ??
          from['name']?.toString() ??
          'Unknown';
    }
    return comment['username']?.toString() ??
        comment['from_username']?.toString() ??
        'Unknown';
  }

  static String _fmtTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }

  void _showReplyDialog(
      BuildContext context, WidgetRef ref, String commentId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Reply to Comment',
            style: TextStyle(color: Colors.amber)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter your reply…',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.amber)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.amber, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final message = controller.text.trim();
              if (message.isEmpty) return;
              try {
                await ref
                    .read(apiClientProvider)
                    .replyToInstagramComment(
                      commentId: commentId,
                      accountId: accountId,
                      message: message,
                    );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Reply sent!'),
                        backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

// ─── Reply Item ───────────────────────────────────────────────────────────────

class _ReplyItem extends StatelessWidget {
  final Map<String, dynamic> reply;
  const _ReplyItem({required this.reply});

  @override
  Widget build(BuildContext context) {
    final username = reply['from'] is Map
        ? ((reply['from'] as Map)['username']?.toString() ??
            (reply['from'] as Map)['name']?.toString() ??
            'Unknown')
        : reply['username']?.toString() ?? 'Unknown';
    final text = (reply['text'] ?? reply['message'] ?? '').toString();
    final timestamp = reply['timestamp']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.subdirectory_arrow_right,
              size: 12, color: Colors.white24),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(username,
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                    if (timestamp != null) ...[
                      const SizedBox(width: 6),
                      Text(_fmtTimestamp(timestamp),
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 9)),
                    ],
                  ],
                ),
                Text(text,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtTimestamp(String ts) {
    try {
      final dt = DateTime.parse(ts).toLocal();
      return '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return ts;
    }
  }
}
