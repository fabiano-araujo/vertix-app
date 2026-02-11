import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/for_you/presentation/pages/for_you_page.dart';
import '../../features/my_vertix/presentation/pages/my_vertix_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/main/presentation/pages/main_shell.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/series/presentation/pages/series_detail_page.dart';
import '../../features/player/presentation/pages/player_page.dart';
import '../../features/admin/presentation/pages/admin_panel_page.dart';

/// App Router Configuration
/// Uses go_router for declarative routing
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      // Main Shell with Bottom Navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomePage(),
            ),
          ),
          GoRoute(
            path: '/for-you',
            name: 'forYou',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ForYouPage(),
            ),
          ),
          GoRoute(
            path: '/my-vertix',
            name: 'myVertix',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MyVertixPage(),
            ),
          ),
          GoRoute(
            path: '/search',
            name: 'search',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SearchPage(),
            ),
          ),
        ],
      ),

      // Full screen routes (outside shell)
      GoRoute(
        path: '/player/:episodeId',
        name: 'player',
        builder: (context, state) => PlayerPage(
          episodeId: int.parse(state.pathParameters['episodeId']!),
        ),
      ),
      GoRoute(
        path: '/series/:id',
        name: 'seriesDetail',
        builder: (context, state) => SeriesDetailPage(
          seriesId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => const AdminPanelPage(),
      ),
    ],
  );
}
