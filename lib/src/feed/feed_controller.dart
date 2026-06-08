import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/app_config.dart';
import '../core/config_store.dart';
import '../youtube/shorts_item.dart';
import '../youtube/shorts_repository.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final configStoreProvider = Provider<ConfigStore>((ref) {
  return ConfigStore(ref.watch(secureStorageProvider));
});

final appConfigProvider = AsyncNotifierProvider<AppConfigController, AppConfig>(
  AppConfigController.new,
);

class AppConfigController extends AsyncNotifier<AppConfig> {
  @override
  Future<AppConfig> build() {
    return ref.watch(configStoreProvider).load();
  }

  Future<void> save(AppConfig config) async {
    state = const AsyncLoading();
    await ref.watch(configStoreProvider).save(config);
    state = AsyncData(config);
  }
}

final feedProvider = AsyncNotifierProvider<FeedController, FeedState>(
  FeedController.new,
);

const _targetBufferedItems = 8;
const _minRemainingBufferedItems = 4;

class FeedController extends AsyncNotifier<FeedState> {
  late ShortsRepository _repository;

  void _log(String message) {
    developer.log(message, name: 'VideoShort.Feed');
  }

  @override
  Future<FeedState> build() async {
    final config = await ref.watch(appConfigProvider.future);
    _repository = ShortsRepository(config);
    _log('build seed=${config.seedUrl}');
    final loaded = await _repository.loadInitial();
    final initial = FeedState(
      items: loaded.items,
      queue: loaded.endpoints,
      isLoadingMore: false,
      lastRequestedSwipeIndex: 0,
      sequenceContinuationToken: loaded.sequenceContinuationToken,
      sequenceClickTrackingParams: loaded.sequenceClickTrackingParams,
    );
    final buffered = await _loadUntilBuffered(
      initial,
      targetCount: _targetBufferedItems,
    );
    _log(
      'build done items=${buffered.items.length} queue=${buffered.queue.length}',
    );
    return buffered;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<void> loadNextForSwipe(int index) async {
    final value = state.value;
    if (value == null || value.isLoadingMore) {
      _log(
        'loadNextForSwipe ignored index=$index loading=${value?.isLoadingMore}',
      );
      return;
    }
    if (index <= value.lastRequestedSwipeIndex) {
      _log(
        'loadNextForSwipe ignored old index=$index last=${value.lastRequestedSwipeIndex}',
      );
      return;
    }
    if (value.queue.isEmpty && value.sequenceContinuationToken.isEmpty) {
      _log(
        'loadNextForSwipe queue empty index=$index items=${value.items.length}',
      );
      return;
    }
    final remainingItems = value.items.length - index - 1;
    _log(
      'loadNextForSwipe index=$index items=${value.items.length} '
      'queue=${value.queue.length} remaining=$remainingItems',
    );
    if (remainingItems > _minRemainingBufferedItems) {
      state = AsyncData(value.copyWith(lastRequestedSwipeIndex: index));
      return;
    }
    state = AsyncData(
      value.copyWith(
        isLoadingMore: true,
        lastError: null,
        lastRequestedSwipeIndex: index,
      ),
    );
    final loaded = await _loadUntilBuffered(
      value,
      targetCount: index + 1 + _targetBufferedItems,
    );
    state = AsyncData(
      loaded.copyWith(
        lastRequestedSwipeIndex: index,
        lastError: loaded.lastError,
      ),
    );
  }

  Future<FeedState> _loadNext(FeedState value) async {
    var current = value;
    if (current.queue.isEmpty && current.sequenceContinuationToken.isNotEmpty) {
      _log('_loadNext queue empty, fetching sequence continuation');
      current = await _loadSequenceContinuation(current);
    }
    if (current.queue.isEmpty) {
      _log('_loadNext skipped empty queue items=${current.items.length}');
      return current.copyWith(isLoadingMore: false);
    }
    final endpoint = current.queue.first;
    try {
      _log(
        '_loadNext request=${endpoint.videoId} items=${current.items.length} '
        'queue=${current.queue.length}',
      );
      final loaded = await _repository.loadEndpoint(
        endpoint,
        sequenceContinuationToken: current.sequenceContinuationToken,
        sequenceClickTrackingParams: current.sequenceClickTrackingParams,
      );
      final existingIds = current.items.map((item) => item.videoId).toSet();
      final newItems = loaded.items
          .where(
            (item) => item.videoId.isNotEmpty && existingIds.add(item.videoId),
          )
          .toList();
      final nextQueue = [...current.queue.skip(1), ...loaded.endpoints];
      final next = current.copyWith(
        items: [...current.items, ...newItems],
        queue: _dedupeQueue(nextQueue),
        isLoadingMore: false,
        lastError: null,
        sequenceContinuationToken: loaded.sequenceContinuationToken,
        sequenceClickTrackingParams: loaded.sequenceClickTrackingParams,
      );
      _log(
        '_loadNext done request=${endpoint.videoId} newItems=${newItems.length} '
        'items=${next.items.length} queue=${next.queue.length}',
      );
      return next;
    } catch (error) {
      _log('_loadNext error request=${endpoint.videoId} error=$error');
      return current.copyWith(
        queue: current.queue.skip(1).toList(),
        isLoadingMore: false,
        lastError: userFacingError(error),
      );
    }
  }

  Future<FeedState> _loadUntilBuffered(
    FeedState value, {
    required int targetCount,
  }) async {
    var next = value;
    var attempts = 0;
    final maxAttempts = targetCount * 4;
    while (next.items.length < targetCount &&
        (next.queue.isNotEmpty || next.sequenceContinuationToken.isNotEmpty) &&
        attempts < maxAttempts) {
      _log(
        '_loadUntilBuffered items=${next.items.length}/$targetCount '
        'queue=${next.queue.length}',
      );
      attempts += 1;
      next = await _loadNext(next);
    }
    return next.copyWith(isLoadingMore: false, lastError: next.lastError);
  }

  Future<FeedState> _loadSequenceContinuation(FeedState value) async {
    try {
      final loaded = await _repository.loadSequenceContinuation(
        continuationToken: value.sequenceContinuationToken,
        clickTrackingParams: value.sequenceClickTrackingParams,
      );
      return value.copyWith(
        queue: _dedupeQueue([...value.queue, ...loaded.endpoints]),
        sequenceContinuationToken: loaded.sequenceContinuationToken,
        sequenceClickTrackingParams: loaded.sequenceClickTrackingParams,
        lastError: null,
      );
    } catch (error) {
      _log('_loadSequenceContinuation error=$error');
      return value.copyWith(lastError: userFacingError(error));
    }
  }

  List<ReelEndpoint> _dedupeQueue(List<ReelEndpoint> endpoints) {
    final seen = <String>{};
    return [
      for (final endpoint in endpoints)
        if (endpoint.canRequestReelItem &&
            seen.add('${endpoint.videoId}:${endpoint.params}'))
          endpoint,
    ];
  }
}

class FeedState {
  const FeedState({
    required this.items,
    required this.queue,
    required this.isLoadingMore,
    required this.lastRequestedSwipeIndex,
    required this.sequenceContinuationToken,
    required this.sequenceClickTrackingParams,
    this.lastError,
  });

  final List<ShortsItem> items;
  final List<ReelEndpoint> queue;
  final bool isLoadingMore;
  final int lastRequestedSwipeIndex;
  final String sequenceContinuationToken;
  final String sequenceClickTrackingParams;
  final String? lastError;

  FeedState copyWith({
    List<ShortsItem>? items,
    List<ReelEndpoint>? queue,
    bool? isLoadingMore,
    int? lastRequestedSwipeIndex,
    String? sequenceContinuationToken,
    String? sequenceClickTrackingParams,
    String? lastError,
  }) {
    return FeedState(
      items: items ?? this.items,
      queue: queue ?? this.queue,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastRequestedSwipeIndex:
          lastRequestedSwipeIndex ?? this.lastRequestedSwipeIndex,
      sequenceContinuationToken:
          sequenceContinuationToken ?? this.sequenceContinuationToken,
      sequenceClickTrackingParams:
          sequenceClickTrackingParams ?? this.sequenceClickTrackingParams,
      lastError: lastError,
    );
  }
}
