import 'dart:developer' as developer;

import '../core/app_config.dart';
import 'shorts_item.dart';
import 'youtube_exception.dart';
import 'youtube_mweb_api.dart';
import 'youtube_parser.dart';

class ShortsRepository {
  ShortsRepository(this._config)
    : _api = YoutubeMwebApi(_config),
      _parser = YoutubeParser();

  final AppConfig _config;
  final YoutubeMwebApi _api;
  final YoutubeParser _parser;

  void _log(String message) {
    developer.log(message, name: 'VideoShort.Repository');
  }

  Future<ShortsLoadResult> loadInitial() async {
    final seedId = _config.seedVideoId;
    _log('loadInitial seedId=$seedId seedUrl=${_config.seedUrl}');
    final initialPayload = await _api.fetchInitialShort(seedId);
    final initial = initialPayload.item;
    final guideEndpoint = await _api.fetchGuideEndpoint().catchError(
      (_) => null,
    );
    final initialSequence = await _loadSequenceParams(
      sequenceParams: initialPayload.sequenceParams,
      clickTrackingParams: initial.clickTrackingParams,
    );
    final seedPlayer = await _api
        .fetchPlayer(
          ReelEndpoint(
            videoId: initial.videoId,
            playerParams: initial.playerParams,
            params: initial.reelParams,
            clickTrackingParams: initial.clickTrackingParams,
            thumbnailUrl: initial.thumbnailUrl,
          ),
        )
        .catchError((_) => <String, dynamic>{});

    final endpoints = <ReelEndpoint>[
      if (initial.canLoadReel)
        ReelEndpoint(
          videoId: initial.videoId,
          playerParams: initial.playerParams,
          params: initial.reelParams,
          clickTrackingParams: initial.clickTrackingParams,
          thumbnailUrl: initial.thumbnailUrl,
        ),
      ?guideEndpoint,
      ...initialPayload.endpoints,
      ...?initialSequence?.endpoints,
      ..._parser.parseReelEndpoints(seedPlayer),
    ];
    final deduped = _dedupeEndpoints(endpoints);
    _log(
      'loadInitial item=${initial.videoId} title="${initial.title}" '
      'rawEndpoints=${endpoints.length} endpoints=${deduped.length} '
      'ids=${deduped.map((e) => e.videoId).take(8).join(',')}',
    );

    return ShortsLoadResult(
      items: [initial],
      endpoints: deduped,
      sequenceContinuationToken:
          initialSequence?.continuationToken ??
          initialPayload.sequence.continuationToken,
      sequenceClickTrackingParams:
          initialSequence?.clickTrackingParams ??
          initialPayload.sequence.clickTrackingParams,
    );
  }

  Future<ShortsLoadResult> loadEndpoint(
    ReelEndpoint endpoint, {
    String sequenceContinuationToken = '',
    String sequenceClickTrackingParams = '',
  }) async {
    _log(
      'loadEndpoint request=${endpoint.videoId} '
      'playerParams=${endpoint.playerParams.length} params=${endpoint.params.length} '
      'queueContinuation=${sequenceContinuationToken.isNotEmpty}',
    );
    if (!endpoint.canRequestReelItem) {
      _log('loadEndpoint skipped invalid endpoint videoId=${endpoint.videoId}');
      return const ShortsLoadResult(items: [], endpoints: []);
    }
    final playerFuture = _api
        .fetchPlayer(endpoint)
        .catchError((_) => <String, dynamic>{});
    final reelFuture = _api.fetchReelItem(endpoint);
    final player = await playerFuture;
    final reelPayload = await reelFuture;
    final reel = reelPayload.item;
    final title = _parser.parsePlayerTitle(player);
    final endpoints = [
      ..._parser.parseReelEndpoints(player),
      ...reelPayload.endpoints,
    ];
    _log(
      'loadEndpoint response item=${reel.videoId} title="${reel.title}" '
      'responseEndpoints=${endpoints.length} '
      'ids=${endpoints.map((e) => e.videoId).take(8).join(',')}',
    );
    var nextContinuationToken = sequenceContinuationToken;
    var nextContinuationClick = sequenceClickTrackingParams;
    if (endpoints.isEmpty && sequenceContinuationToken.isNotEmpty) {
      _log('loadEndpoint endpoints empty, fetching sequence continuation');
      final sequence = await _api.fetchReelWatchSequence(
        continuationToken: sequenceContinuationToken,
        clickTrackingParams: sequenceClickTrackingParams,
      );
      endpoints.addAll(sequence.endpoints);
      nextContinuationToken = sequence.continuationToken;
      nextContinuationClick = sequence.clickTrackingParams;
      _log(
        'sequence continuation endpoints=${sequence.endpoints.length} '
        'hasNext=${sequence.hasContinuation}',
      );
    }
    if (endpoints.isEmpty && reel.videoId.isNotEmpty) {
      _log('loadEndpoint endpoints empty, crawling page for ${reel.videoId}');
      final crawled = await _crawlEndpointsFromPage(reel.videoId);
      endpoints.addAll(crawled);
      _log(
        'page crawl endpoints=${crawled.length} '
        'ids=${crawled.map((e) => e.videoId).take(8).join(',')}',
      );
    }
    final deduped = _dedupeEndpoints(endpoints);
    _log(
      'loadEndpoint done item=${reel.videoId} endpoints=${deduped.length} '
      'ids=${deduped.map((e) => e.videoId).take(8).join(',')}',
    );
    return ShortsLoadResult(
      items: [
        title == null || title.isEmpty ? reel : reel.copyWith(title: title),
      ],
      endpoints: deduped,
      sequenceContinuationToken: nextContinuationToken,
      sequenceClickTrackingParams: nextContinuationClick,
    );
  }

  Future<ShortsItem> loadByVideoId(String videoId) async {
    return (await _api.fetchInitialShort(videoId)).item;
  }

  Future<ShortsLoadResult> loadSequenceContinuation({
    required String continuationToken,
    required String clickTrackingParams,
  }) async {
    if (continuationToken.isEmpty) {
      return const ShortsLoadResult(items: [], endpoints: []);
    }
    final sequence = await _api.fetchReelWatchSequence(
      continuationToken: continuationToken,
      clickTrackingParams: clickTrackingParams,
    );
    return ShortsLoadResult(
      items: const [],
      endpoints: _dedupeEndpoints(sequence.endpoints),
      sequenceContinuationToken: sequence.continuationToken,
      sequenceClickTrackingParams: sequence.clickTrackingParams,
    );
  }

  Future<ReelSequencePage?> _loadSequenceParams({
    required String sequenceParams,
    required String clickTrackingParams,
  }) async {
    if (sequenceParams.isEmpty) {
      return null;
    }
    try {
      return await _api.fetchReelWatchSequence(
        sequenceParams: sequenceParams,
        clickTrackingParams: clickTrackingParams,
      );
    } catch (error) {
      _log('sequence params failed error=$error');
      return null;
    }
  }

  Future<List<ReelEndpoint>> _crawlEndpointsFromPage(String videoId) async {
    try {
      final payload = await _api.fetchInitialShort(videoId);
      return payload.endpoints;
    } catch (error) {
      _log('page crawl failed videoId=$videoId error=$error');
      return const [];
    }
  }

  List<ReelEndpoint> _dedupeEndpoints(List<ReelEndpoint> endpoints) {
    final seen = <String>{};
    final result = <ReelEndpoint>[];
    for (final endpoint in endpoints) {
      if (!endpoint.canRequestReelItem) {
        continue;
      }
      final key = '${endpoint.videoId}:${endpoint.params}';
      if (seen.add(key)) {
        result.add(endpoint);
      }
    }
    return result;
  }
}

class ShortsLoadResult {
  const ShortsLoadResult({
    required this.items,
    required this.endpoints,
    this.sequenceContinuationToken = '',
    this.sequenceClickTrackingParams = '',
  });

  final List<ShortsItem> items;
  final List<ReelEndpoint> endpoints;
  final String sequenceContinuationToken;
  final String sequenceClickTrackingParams;
}

String userFacingError(Object error) {
  if (error is YoutubeException) {
    return error.toString();
  }
  return '加载失败：$error';
}
