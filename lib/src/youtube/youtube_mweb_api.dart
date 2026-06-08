import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../core/app_config.dart';
import 'shorts_item.dart';
import 'youtube_exception.dart';
import 'youtube_parser.dart';

class YoutubeMwebApi {
  YoutubeMwebApi(this._config)
    : _dio = Dio(
        BaseOptions(
          baseUrl: 'https://m.youtube.com',
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 25),
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 500,
        ),
      ),
      _parser = YoutubeParser() {
    if (_config.proxyUrl.trim().isNotEmpty) {
      final adapter = _dio.httpClientAdapter;
      if (adapter is IOHttpClientAdapter) {
        adapter.createHttpClient = () {
          final client = HttpClient();
          client.findProxy = (_) => 'PROXY ${_config.proxyUrl.trim()}';
          return client;
        };
      }
    }
  }

  final AppConfig _config;
  final Dio _dio;
  final YoutubeParser _parser;

  Future<InitialShortsPayload> fetchInitialShort(String videoId) async {
    final html = await fetchShortsPageHtml(videoId);
    final initialData = _parser.parseInitialDataFromPage(html);
    final command = _parser.parseCommandFromPage(html);
    final sequence = _parser.parseInitialReelWatchSequencePage(html);
    final sequenceParams = _parser.parseSequenceParamsFromPage(html);
    return InitialShortsPayload(
      item: _parser.parseInitialPage(html, videoId),
      endpoints: [
        ..._parser.parseReelEndpoints(command),
        ..._parser.parseReelEndpoints(initialData),
        ...sequence.endpoints,
      ],
      sequence: sequence,
      sequenceParams: sequenceParams,
    );
  }

  Future<String> fetchShortsPageHtml(String videoId) async {
    final response = await _dio.get<String>(
      '/shorts/$videoId',
      options: Options(
        responseType: ResponseType.plain,
        headers: _pageHeaders('/shorts/$videoId'),
      ),
    );
    _throwIfBad(response);
    final html = response.data ?? '';
    if (html.isEmpty) {
      throw const YoutubeException('YouTube 页面返回为空');
    }
    return html;
  }

  Future<ReelEndpoint?> fetchGuideEndpoint() async {
    final response = await _postJson('/youtubei/v1/guide?prettyPrint=false', {
      'context': _context(
        originalUrl: _config.seedUrl,
        graftUrl: _config.seedUrl,
      ),
      'fetchLiveState': true,
    });
    _throwIfBad(response);
    return _parser.parseGuideEndpoint(_asMap(response.data));
  }

  Future<Map<String, dynamic>> fetchPlayer(ReelEndpoint endpoint) async {
    final shortsUrl = _shortsUrl(endpoint.videoId);
    final response = await _postJson('/youtubei/v1/player?prettyPrint=false', {
      'context': _context(
        originalUrl: shortsUrl,
        graftUrl: '/shorts/${endpoint.videoId}',
        clientScreen: 'WATCH',
        isPrefetch: true,
        clickTrackingParams: endpoint.clickTrackingParams,
      ),
      'videoId': endpoint.videoId,
      if (endpoint.playerParams.isNotEmpty) 'params': endpoint.playerParams,
      'playbackContext': {
        'contentPlaybackContext': {'html5Preference': 'HTML5_PREF_WANTS'},
      },
      'racyCheckOk': true,
      'contentCheckOk': true,
      'serviceIntegrityDimensions': const {},
    });
    _throwIfBad(response);
    return _asMap(response.data);
  }

  Future<ReelItemPayload> fetchReelItem(ReelEndpoint endpoint) async {
    if (!endpoint.canRequestReelItem) {
      throw const YoutubeException('缺少 reelWatchEndpoint 参数，无法请求 Shorts 元数据');
    }
    final shortsUrl = _shortsUrl(endpoint.videoId);
    final response = await _postJson(
      '/youtubei/v1/reel/reel_item_watch?prettyPrint=false',
      {
        'context': _context(
          originalUrl: shortsUrl,
          graftUrl: shortsUrl,
          clickTrackingParams: endpoint.clickTrackingParams,
        ),
        'playerRequest': {
          'videoId': endpoint.videoId,
          'params': endpoint.playerParams,
        },
        'params': endpoint.params,
        'disablePlayerResponse': true,
      },
    );
    _throwIfBad(response);
    final json = _asMap(response.data);
    return ReelItemPayload(
      item: _parser.parseReelResponse(json, endpoint.videoId),
      endpoints: _parser.parseReelEndpoints(json),
    );
  }

  Future<ReelSequencePage> fetchReelWatchSequence({
    String sequenceParams = '',
    String continuationToken = '',
    String clickTrackingParams = '',
  }) async {
    if (sequenceParams.isEmpty && continuationToken.isEmpty) {
      throw const YoutubeException('缺少 reel_watch_sequence 参数');
    }
    final response = await _postJson(
      '/youtubei/v1/reel/reel_watch_sequence?prettyPrint=false',
      {
        'context': _context(
          originalUrl: 'https://m.youtube.com/shorts',
          graftUrl: 'https://m.youtube.com/shorts/',
          clickTrackingParams: clickTrackingParams,
        ),
        if (sequenceParams.isNotEmpty) 'sequenceParams': sequenceParams,
        if (continuationToken.isNotEmpty) 'continuation': continuationToken,
      },
    );
    _throwIfBad(response);
    return _parser.parseReelSequencePage(_asMap(response.data));
  }

  Future<Response<dynamic>> _postJson(String path, Map<String, dynamic> body) {
    final raw = jsonEncode(body);
    final data = _config.useGzipBody
        ? Uint8List.fromList(gzip.encode(utf8.encode(raw)))
        : raw;
    return _dio.post<dynamic>(
      path,
      data: data,
      options: Options(
        headers: _apiHeaders(path, gzipBody: _config.useGzipBody),
      ),
    );
  }

  String _shortsUrl(String videoId) => 'https://m.youtube.com/shorts/$videoId';

  Map<String, dynamic> _context({
    required String originalUrl,
    required String graftUrl,
    String clientScreen = '',
    bool isPrefetch = false,
    String clickTrackingParams = '',
  }) {
    final request = <String, dynamic>{
      'useSsl': true,
      'internalExperimentFlags': const [],
      'consistencyTokenJars': const [],
      if (isPrefetch) 'isPrefetch': true,
    };
    return {
      'client': {
        'hl': _config.locale,
        'gl': _config.region,
        'deviceMake': 'Google',
        'deviceModel': 'Nexus 5',
        if (_config.visitorData.isNotEmpty) 'visitorData': _config.visitorData,
        'userAgent': '${AppConfig.defaultUserAgent},gzip(gfe)',
        'clientName': 'MWEB',
        'clientVersion': _config.clientVersion,
        'osName': 'Android',
        'osVersion': '6.0',
        'originalUrl': originalUrl,
        'playerType': 'UNIPLAYER',
        'screenPixelDensity': 2,
        'platform': 'MOBILE',
        'clientFormFactor': 'SMALL_FORM_FACTOR',
        'windowWidthPoints': 333,
        'screenWidthPoints': 333,
        'screenHeightPoints': 720,
        'utcOffsetMinutes': 480,
        if (clientScreen.isNotEmpty) 'clientScreen': clientScreen,
        'mainAppWebInfo': {
          'graftUrl': graftUrl,
          'webDisplayMode': 'WEB_DISPLAY_MODE_BROWSER',
          'isWebNativeShareAvailable': true,
        },
        'timeZone': 'Asia/Shanghai',
      },
      'user': {'lockedSafetyMode': false},
      'request': request,
      if (clickTrackingParams.isNotEmpty)
        'clickTracking': {'clickTrackingParams': clickTrackingParams},
      'adSignalsInfo': {
        'params': [
          {'key': 'u_tz', 'value': '480'},
          {'key': 'u_h', 'value': '720'},
          {'key': 'u_w', 'value': '333'},
          {'key': 'u_ah', 'value': '720'},
          {'key': 'u_aw', 'value': '333'},
          {'key': 'u_cd', 'value': '24'},
          {'key': 'bih', 'value': '720'},
          {'key': 'biw', 'value': '333'},
        ],
      },
    };
  }

  Map<String, String> _pageHeaders(String path) {
    return {
      'accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
      'accept-language':
          '${_config.locale},zh;q=0.9,ja-JP;q=0.8,ja;q=0.7,en-US;q=0.6,en;q=0.5',
      'origin': 'https://m.youtube.com',
      'referer': 'https://m.youtube.com/',
      'user-agent': AppConfig.defaultUserAgent,
      'sec-ch-ua-mobile': '?1',
      'sec-ch-ua-model': '"Nexus 5"',
      'sec-ch-ua-platform': '"Android"',
      'sec-ch-viewport-width': '333',
      if (_config.cookie.isNotEmpty) 'cookie': _config.cookie,
    };
  }

  Map<String, String> _apiHeaders(String path, {required bool gzipBody}) {
    return {
      'accept': '*/*',
      'accept-language':
          '${_config.locale},zh;q=0.9,ja-JP;q=0.8,ja;q=0.7,en-US;q=0.6,en;q=0.5',
      'content-type': 'application/json',
      if (gzipBody) 'content-encoding': 'gzip',
      'origin': 'https://m.youtube.com',
      'referer': 'https://m.youtube.com/',
      'user-agent': AppConfig.defaultUserAgent,
      'x-youtube-client-name': '2',
      'x-youtube-client-version': _config.clientVersion,
      if (_config.visitorData.isNotEmpty)
        'x-goog-visitor-id': _config.visitorData,
      'x-youtube-bootstrap-logged-in': 'false',
      'sec-ch-ua-mobile': '?1',
      'sec-ch-ua-model': '"Nexus 5"',
      'sec-ch-ua-platform': '"Android"',
      'sec-ch-viewport-width': '333',
      if (_config.cookie.isNotEmpty) 'cookie': _config.cookie,
    };
  }

  void _throwIfBad(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw YoutubeException('YouTube 请求失败', statusCode: status);
    }
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } on FormatException catch (error) {
        final compact = value.replaceAll(RegExp(r'\s+'), ' ');
        final preview = compact.length > 120
            ? compact.substring(0, 120)
            : compact;
        throw YoutubeException('YouTube 返回不是 JSON：$preview (${error.message})');
      }
    }
    throw const YoutubeException('YouTube 返回格式无法解析');
  }
}

String redactForLog(String value) {
  if (value.length <= 12) {
    return '[redacted]';
  }
  return '${value.substring(0, 6)}...[redacted]...${value.substring(value.length - 4)}';
}

class InitialShortsPayload {
  const InitialShortsPayload({
    required this.item,
    required this.endpoints,
    required this.sequence,
    required this.sequenceParams,
  });

  final ShortsItem item;
  final List<ReelEndpoint> endpoints;
  final ReelSequencePage sequence;
  final String sequenceParams;
}

class ReelItemPayload {
  const ReelItemPayload({required this.item, required this.endpoints});

  final ShortsItem item;
  final List<ReelEndpoint> endpoints;
}
