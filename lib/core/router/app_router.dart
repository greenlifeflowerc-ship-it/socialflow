import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/sign_up_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/update/presentation/update_required_screen.dart';
import '../../services/version_check_service.dart';
import '../../features/media/presentation/media_library_screen.dart';
import '../../features/media/presentation/upload_queue_screen.dart';
import '../../features/ai_studio/presentation/ai_studio_screen.dart';
import '../../features/ai_studio/presentation/ai_chat_screen.dart';
import '../../features/ai_studio/presentation/single_edit_screen.dart';
import '../../features/ai_studio/presentation/bulk_edit_screen.dart';
import '../../features/ai_studio/presentation/history_screen.dart';
import '../../features/ai_studio/presentation/brand_profile_screen.dart';
import '../../features/ai_studio/presentation/post_ideas_screen.dart';
import '../../features/ai_studio/presentation/reels_ideas_screen.dart';
import '../../features/posts/presentation/editor/post_editor_screen.dart';
import '../../features/posts/presentation/bulk_scheduler_screen.dart';
import '../../features/posts/presentation/bulk_schedule_preview_screen.dart';
import '../../features/posts/presentation/posts_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/instagram_accounts_screen.dart';
import '../../features/settings/presentation/about_me_screen.dart';
import '../../features/dashboard/presentation/insights_screen.dart';
import '../../features/inbox/presentation/inbox_screen.dart';
import '../../features/comments/presentation/comments_screen.dart';
import '../../features/auto_reply/presentation/auto_reply_screen.dart';
import '../../widgets/main_scaffold.dart';
import '../../models/media_asset.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

class AppStateNotifier extends ChangeNotifier {
  StreamSubscription<AuthState>? _sub;

  AppStateNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final appStateNotifier = AppStateNotifier();

final appRouter = GoRouter(
  initialLocation: '/login',
  navigatorKey: _rootNavigatorKey,
  refreshListenable: appStateNotifier,
  redirect: (context, state) {
    if (appVersionResult.needsUpdate &&
        state.matchedLocation != '/update-required') {
      return '/update-required';
    }

    final session = Supabase.instance.client.auth.currentSession;
    final location = state.matchedLocation;
    final isPublicRoute = location == '/login' ||
        location == '/signup' ||
        location == '/forgot-password';

    if (session == null && !isPublicRoute) return '/login';
    if (session != null && isPublicRoute) return '/dashboard';
    return null;
  },
  routes: [
    GoRoute(
      path: '/update-required',
      builder: (context, state) => const UpdateRequiredScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignUpScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/ai',
      builder: (context, state) => const AiStudioScreen(),
      routes: [
        GoRoute(
          path: 'chat',
          builder: (context, state) => const AiChatScreen(),
        ),
        GoRoute(
          path: 'single-edit',
          builder: (context, state) =>
              SingleEditScreen(asset: state.extra as MediaAsset?),
        ),
        GoRoute(
          path: 'bulk-edit',
          builder: (context, state) {
            final extra = state.extra;
            final List<MediaAsset> assets = extra is List<MediaAsset>
                ? extra
                : extra is List
                    ? extra.whereType<MediaAsset>().toList()
                    : <MediaAsset>[];
            return BulkEditScreen(assets: assets);
          },
        ),
        GoRoute(
          path: 'history',
          builder: (context, state) => const HistoryScreen(),
        ),
        GoRoute(
          path: 'brand-profile',
          builder: (context, state) => const BrandProfileScreen(),
        ),
        GoRoute(
          path: 'post-ideas',
          builder: (context, state) => const PostIdeasScreen(),
        ),
        GoRoute(
          path: 'reels-ideas',
          builder: (context, state) => const ReelsIdeasScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/post-editor',
      builder: (context, state) =>
          PostEditorScreen(asset: state.extra as MediaAsset),
    ),
    GoRoute(
      path: '/upload-queue',
      builder: (context, state) => const UploadQueueScreen(),
    ),
    GoRoute(
      path: '/bulk-scheduler',
      builder: (context, state) => const BulkSchedulerScreen(),
    ),
    GoRoute(
      path: '/bulk-scheduler-preview',
      builder: (context, state) => BulkSchedulePreviewScreen(
          scheduleSettings: state.extra as Map<String, dynamic>),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const DashboardScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
          routes: [
            // Parameterless fallback: /dashboard/insights
            // Used when igBusinessAccountId is null/empty — auto-picks first account.
            GoRoute(
              path: 'insights',
              builder: (context, state) => const InsightsGateway(),
            ),
            // Full route with account: /dashboard/insights/:accountId
            GoRoute(
              path: 'insights/:accountId',
              builder: (context, state) => InsightsScreen(
                accountId: state.pathParameters['accountId']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/media',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const MediaLibraryScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/posts',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const PostsScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/inbox',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const InboxScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/comments',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const CommentsScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/auto-reply',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const AutoReplyScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/calendar',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const CalendarScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const SettingsScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
          routes: [
            GoRoute(
              path: 'instagram-accounts',
              builder: (context, state) => const InstagramAccountsScreen(),
            ),
            GoRoute(
              path: 'about',
              builder: (context, state) => const AboutMeScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
