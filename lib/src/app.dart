import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'debug/debug_page.dart';
import 'feed/shorts_feed_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const ShortsFeedPage()),
      GoRoute(path: '/debug', builder: (context, state) => const DebugPage()),
    ],
  );
});

class ShortsApp extends ConsumerWidget {
  const ShortsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Shorts Lab',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(appRouterProvider),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffe53935),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
    );
  }
}
