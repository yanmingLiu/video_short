import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../youtube/shorts_item.dart';
import '../youtube/youtube_playback_resolver.dart';

const _preloadPreviousCount = 1;
const _preloadNextCount = 3;
const _keepPreviousCount = 2;
const _keepNextCount = 5;

class ShortsPlaybackPool {
  ShortsPlaybackPool({PlaybackUrlResolver? resolver})
    : _resolver = resolver ?? YoutubePlaybackResolver();

  final PlaybackUrlResolver _resolver;
  final _entries = <String, ShortsPlaybackEntry>{};

  ShortsPlaybackEntry entryFor(String videoId) {
    return _entries.putIfAbsent(
      videoId,
      () => ShortsPlaybackEntry(videoId: videoId, resolver: _resolver),
    );
  }

  void preloadAround(List<ShortsItem> items, int currentIndex) {
    if (items.isEmpty) {
      releaseAll();
      return;
    }

    final activeIndex = currentIndex.clamp(0, items.length - 1);
    final preloadIndexes = _orderedPreloadIndexes(items.length, activeIndex);
    for (final index in preloadIndexes) {
      unawaited(entryFor(items[index].videoId).prepare());
    }

    final keepStart = math.max(0, activeIndex - _keepPreviousCount);
    final keepEnd = math.min(items.length - 1, activeIndex + _keepNextCount);
    final keepIds = {
      for (var index = keepStart; index <= keepEnd; index++)
        items[index].videoId,
    };
    final staleIds = _entries.keys
        .where((videoId) => !keepIds.contains(videoId))
        .toList();
    for (final videoId in staleIds) {
      _entries.remove(videoId)?.release();
    }
  }

  List<int> _orderedPreloadIndexes(int itemCount, int activeIndex) {
    final indexes = <int>[activeIndex];
    for (var offset = 1; offset <= _preloadNextCount; offset++) {
      final index = activeIndex + offset;
      if (index < itemCount) {
        indexes.add(index);
      }
    }
    for (var offset = 1; offset <= _preloadPreviousCount; offset++) {
      final index = activeIndex - offset;
      if (index >= 0) {
        indexes.add(index);
      }
    }
    return indexes;
  }

  void releaseAll() {
    for (final entry in _entries.values) {
      entry.release();
    }
    _entries.clear();
  }

  void dispose() {
    for (final entry in _entries.values) {
      entry.dispose();
    }
    _entries.clear();
    _resolver.close();
  }
}

class ShortsPlaybackEntry extends ChangeNotifier {
  ShortsPlaybackEntry({
    required this.videoId,
    required PlaybackUrlResolver resolver,
  }) : _resolver = resolver;

  final String videoId;
  final PlaybackUrlResolver _resolver;

  VideoPlayerController? _controller;
  Future<void>? _prepareFuture;
  String? _error;
  var _wantsPlay = false;
  var _generation = 0;
  var _isReleased = false;

  VideoPlayerController? get controller => _controller;
  String? get error => _error;
  bool get isPreparing =>
      _prepareFuture != null && _controller?.value.isInitialized != true;

  Future<void> prepare() {
    if (_controller?.value.isInitialized == true) {
      return Future<void>.value();
    }
    final preparing = _prepareFuture;
    if (preparing != null) {
      return preparing;
    }
    final generation = _generation;
    final future = _prepare(generation);
    _prepareFuture = future;
    return future;
  }

  Future<void> activate() async {
    _wantsPlay = true;
    _isReleased = false;
    await prepare();
    await _playIfWanted();
  }

  Future<void> deactivate() async {
    _wantsPlay = false;
    await _guardPlaybackCommand(() async {
      await _controller?.pause();
    });
    _notifyIfAlive();
  }

  Future<void> togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      await activate();
      return;
    }
    if (controller.value.isPlaying) {
      _wantsPlay = false;
      await _guardPlaybackCommand(controller.pause);
    } else {
      _wantsPlay = true;
      await _guardPlaybackCommand(controller.play);
    }
    _notifyIfAlive();
  }

  Future<void> seekTo(Duration position) {
    return _guardPlaybackCommand(() async {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) {
        return;
      }
      await controller.seekTo(position);
    });
  }

  void release() {
    _generation += 1;
    _wantsPlay = false;
    _isReleased = true;
    _error = null;
    _prepareFuture = null;
    final controller = _controller;
    _controller = null;
    _notifyIfAlive();
    unawaited(_disposeController(controller));
  }

  Future<void> _prepare(int generation) async {
    _error = null;
    _isReleased = false;
    _notifyIfAlive();
    VideoPlayerController? nextController;
    try {
      final url = await _resolver.resolveMuxedUrl(videoId);
      if (!_isCurrent(generation)) {
        return;
      }
      nextController = VideoPlayerController.networkUrl(url);
      await nextController.initialize();
      await nextController.setLooping(true);
      await nextController.setVolume(1);
      if (!_isCurrent(generation)) {
        await _disposeController(nextController);
        return;
      }
      final oldController = _controller;
      _controller = nextController;
      nextController = null;
      unawaited(_disposeController(oldController));
      _error = null;
      _notifyIfAlive();
      await _playIfWanted();
    } catch (_) {
      if (!_isCurrent(generation)) {
        return;
      }
      _prepareFuture = null;
      _error = '视频流加载失败';
      _notifyIfAlive();
      if (nextController != null) {
        unawaited(_disposeController(nextController));
      }
    }
  }

  Future<void> _playIfWanted() async {
    final controller = _controller;
    if (!_wantsPlay ||
        controller == null ||
        !controller.value.isInitialized ||
        _isReleased) {
      return;
    }
    await _guardPlaybackCommand(controller.play);
    _notifyIfAlive();
  }

  Future<void> _guardPlaybackCommand(Future<void> Function() command) async {
    try {
      await command();
    } catch (_) {
      if (_isDisposed) {
        return;
      }
      _error = '视频流加载失败';
    }
  }

  Future<void> _disposeController(VideoPlayerController? controller) async {
    if (controller == null) {
      return;
    }
    try {
      await controller.dispose();
    } catch (_) {
      // Disposing is best-effort during rapid page changes.
    }
  }

  bool _isCurrent(int generation) {
    return !_isReleased && _generation == generation && !_isDisposed;
  }

  var _isDisposed = false;

  void _notifyIfAlive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    final controller = _controller;
    _controller = null;
    unawaited(_disposeController(controller));
    super.dispose();
  }
}
