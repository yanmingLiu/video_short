import 'dart:convert';
import 'dart:io';

import 'package:video_short/src/core/app_config.dart';
import 'package:video_short/src/youtube/shorts_item.dart';
import 'package:video_short/src/youtube/youtube_mweb_api.dart';

Future<void> main(List<String> args) async {
  final seedUrl = args.isNotEmpty ? args[0] : AppConfig.defaultSeedUrl;
  final limit = args.length > 1 ? int.tryParse(args[1]) ?? 10 : 10;
  final videoId = extractVideoId(seedUrl) ?? AppConfig.defaults().seedVideoId;
  final api = YoutubeMwebApi(
    AppConfig.defaults().copyWith(
      seedUrl: seedUrl,
      clientVersion: AppConfig.defaultClientVersion,
      useGzipBody: false,
    ),
  );

  final initial = await api.fetchInitialShort(videoId);
  final items = <ShortsItem>[initial.item];
  final queue = <ReelEndpoint>[
    if (initial.item.canLoadReel)
      ReelEndpoint(
        videoId: initial.item.videoId,
        playerParams: initial.item.playerParams,
        params: initial.item.reelParams,
        clickTrackingParams: initial.item.clickTrackingParams,
        thumbnailUrl: initial.item.thumbnailUrl,
      ),
    ...initial.endpoints,
  ];
  var continuationToken = initial.sequence.continuationToken;
  var continuationClick = initial.sequence.clickTrackingParams;
  final seenItems = {initial.item.videoId};
  final seenQueue = <String>{};

  while (items.length < limit) {
    final endpoint = _popNext(queue, seenQueue);
    if (endpoint == null) {
      if (continuationToken.isEmpty) {
        break;
      }
      final page = await api.fetchReelWatchSequence(
        continuationToken: continuationToken,
        clickTrackingParams: continuationClick,
      );
      queue.addAll(page.endpoints);
      continuationToken = page.continuationToken;
      continuationClick = page.clickTrackingParams;
      continue;
    }
    final payload = await api.fetchReelItem(endpoint);
    final item = payload.item;
    if (item.videoId.isNotEmpty && seenItems.add(item.videoId)) {
      items.add(item);
    }
    queue.addAll(payload.endpoints);
  }

  final encoder = JsonEncoder.withIndent('  ');
  stdout.writeln(
    encoder.convert({
      'seed': seedUrl,
      'count': items.length,
      'items': [
        for (final item in items.take(limit))
          {
            'videoId': item.videoId,
            'title': item.title,
            'channelName': item.channelName,
            'thumbnailUrl': item.thumbnailUrl,
            'pageUrl': item.pageUrl.replaceFirst(
              'm.youtube.com',
              'www.youtube.com',
            ),
          },
      ],
    }),
  );
}

ReelEndpoint? _popNext(List<ReelEndpoint> queue, Set<String> seenQueue) {
  while (queue.isNotEmpty) {
    final endpoint = queue.removeAt(0);
    if (!endpoint.canRequestReelItem) {
      continue;
    }
    final key = '${endpoint.videoId}:${endpoint.params}';
    if (seenQueue.add(key)) {
      return endpoint;
    }
  }
  return null;
}
