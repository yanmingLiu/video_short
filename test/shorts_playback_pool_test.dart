import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_short/src/feed/shorts_playback_pool.dart';
import 'package:video_short/src/youtube/youtube_playback_resolver.dart';

void main() {
  test('prepare records resolver failures without throwing', () async {
    final resolver = _FakePlaybackResolver(
      onResolve: (_) async => throw StateError('network failed'),
    );
    final entry = ShortsPlaybackEntry(videoId: 'video', resolver: resolver);
    var notifications = 0;
    entry.addListener(() => notifications += 1);

    await entry.prepare();

    expect(entry.error, '视频流加载失败');
    expect(notifications, greaterThanOrEqualTo(2));
    expect(resolver.resolveCount, 1);
    entry.dispose();
  });

  test('prepare reuses the in-flight resolver request', () async {
    final completer = Completer<Uri>();
    final resolver = _FakePlaybackResolver(onResolve: (_) => completer.future);
    final entry = ShortsPlaybackEntry(videoId: 'video', resolver: resolver);

    final first = entry.prepare();
    final second = entry.prepare();

    expect(identical(first, second), isTrue);
    expect(resolver.resolveCount, 1);

    completer.complete(Uri.parse('https://example.com/video.mp4'));
    await first;
    await second;

    expect(entry.error, '视频流加载失败');
    entry.dispose();
  });

  test('release ignores late resolver completion', () async {
    final completer = Completer<Uri>();
    final resolver = _FakePlaybackResolver(onResolve: (_) => completer.future);
    final entry = ShortsPlaybackEntry(videoId: 'video', resolver: resolver);
    var notifications = 0;
    entry.addListener(() => notifications += 1);

    final preparing = entry.prepare();
    entry.release();
    completer.complete(Uri.parse('https://example.com/video.mp4'));
    await preparing;

    expect(entry.error, isNull);
    expect(entry.controller, isNull);
    expect(notifications, 2);
    entry.dispose();
  });
}

class _FakePlaybackResolver implements PlaybackUrlResolver {
  _FakePlaybackResolver({required this.onResolve});

  final Future<Uri> Function(String videoId) onResolve;
  var resolveCount = 0;
  var isClosed = false;

  @override
  Future<Uri> resolveMuxedUrl(String videoId) {
    resolveCount += 1;
    return onResolve(videoId);
  }

  @override
  void close() {
    isClosed = true;
  }
}
