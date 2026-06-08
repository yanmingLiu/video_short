import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../youtube/shorts_repository.dart';
import 'feed_controller.dart';
import 'shorts_player_page.dart';

class ShortsFeedPage extends ConsumerStatefulWidget {
  const ShortsFeedPage({super.key});

  @override
  ConsumerState<ShortsFeedPage> createState() => _ShortsFeedPageState();
}

class _ShortsFeedPageState extends ConsumerState<ShortsFeedPage> {
  final _pageController = PageController();
  var _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: feed.when(
        data: (state) => Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: state.items.length,
              onPageChanged: (index) {
                final previousIndex = _currentIndex;
                setState(() => _currentIndex = index);
                if (index > previousIndex) {
                  ref.read(feedProvider.notifier).loadNextForSwipe(index);
                }
                if (state.items.length - index <= 2) {
                  ref.read(feedProvider.notifier).loadNextForSwipe(index + 1);
                }
              },
              itemBuilder: (context, index) {
                final item = state.items[index];
                return ShortsPlayerPage(
                  key: ValueKey(item.videoId),
                  item: item,
                  isActive: index == _currentIndex,
                );
              },
            ),
            if (state.isLoadingMore)
              const Positioned(
                right: 18,
                top: 112,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (state.lastError != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: _ErrorBanner(message: state.lastError!),
              ),
          ],
        ),
        error: (error, stackTrace) => _InitialError(
          message: userFacingError(error),
          onRetry: () => ref.read(feedProvider.notifier).refresh(),
          onDebug: () => context.go('/debug'),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}

class _InitialError extends StatelessWidget {
  const _InitialError({
    required this.message,
    required this.onRetry,
    required this.onDebug,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDebug;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.error_outline, size: 40, color: Colors.white70),
            const SizedBox(height: 18),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
            TextButton.icon(
              onPressed: onDebug,
              icon: const Icon(Icons.settings),
              label: const Text('打开调试配置'),
            ),
          ],
        ),
      ),
    );
  }
}
