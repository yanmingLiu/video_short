import 'package:youtube_explode_dart/youtube_explode_dart.dart';

abstract interface class PlaybackUrlResolver {
  Future<Uri> resolveMuxedUrl(String videoId);

  void close();
}

class YoutubePlaybackResolver implements PlaybackUrlResolver {
  YoutubePlaybackResolver({YoutubeExplode? youtube})
    : _youtube = youtube ?? YoutubeExplode();

  final YoutubeExplode _youtube;
  final _cache = <String, Future<Uri>>{};

  @override
  Future<Uri> resolveMuxedUrl(String videoId) {
    final cached = _cache[videoId];
    if (cached != null) {
      return cached;
    }
    final future = _resolveMuxedUrl(videoId).catchError((Object error) {
      _cache.remove(videoId);
      throw error;
    });
    _cache[videoId] = future;
    return future;
  }

  Future<Uri> _resolveMuxedUrl(String videoId) async {
    final manifest = await _youtube.videos.streamsClient.getManifest(videoId);
    if (manifest.muxed.isNotEmpty) {
      return manifest.muxed.withHighestBitrate().url;
    }
    final hlsMuxed = manifest.streams.whereType<HlsMuxedStreamInfo>().toList();
    if (hlsMuxed.isNotEmpty) {
      return hlsMuxed.withHighestBitrate().url;
    }
    throw StateError('没有找到可直接播放的音视频合一流：$videoId');
  }

  @override
  void close() {
    _youtube.close();
  }
}
