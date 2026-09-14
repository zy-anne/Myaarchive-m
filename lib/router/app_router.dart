import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../screens/auth/sign_in_screen.dart';
import '../screens/auth/sign_up_screen.dart';
import '../screens/catalog/series_detail_screen.dart';
import '../screens/catalog/series_form_screen.dart';
import '../screens/home/home_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/home',
    redirect: (BuildContext context, GoRouterState state) {
      if (authState.isLoading) return null;

      final user = authState.value;
      final isAuthRoute = state.uri.path == '/sign-in' || state.uri.path == '/sign-up';

      // If not signed in, redirect to /sign-in
      if (user == null) {
        return isAuthRoute ? null : '/sign-in';
      }

      // If signed in and on auth route, redirect to /home
      if (isAuthRoute) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/series/add',
        builder: (context, state) => const SeriesFormScreen(),
      ),
      GoRoute(
        path: '/series/edit/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return SeriesFormScreen(seriesId: id);
        },
      ),
      GoRoute(
        path: '/series/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return SeriesDetailScreen(seriesId: id);
        },
      ),
    ],
  );
});
