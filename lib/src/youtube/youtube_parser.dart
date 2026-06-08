import 'dart:convert';

import 'shorts_item.dart';

class YoutubeParser {
  ReelEndpoint? parseGuideEndpoint(Map<String, dynamic> json) {
    final endpoint = _findObjectWithKey(json, 'reelWatchEndpoint');
    if (endpoint == null) {
      return null;
    }
    return _endpointFromContainer(endpoint);
  }

  List<ReelEndpoint> parseReelEndpoints(Map<String, dynamic> json) {
    final endpoints = <ReelEndpoint>[];
    final seen = <String>{};
    _walk(json, (value) {
      final endpoint = value['reelWatchEndpoint'];
      if (endpoint is Map<String, dynamic>) {
        final parsed = _endpointFromContainer(value);
        if (parsed != null && parsed.isUsable) {
          final key =
              '${parsed.videoId}:${parsed.playerParams}:${parsed.params}';
          if (seen.add(key)) {
            endpoints.add(parsed);
          }
        }
      }
    });
    return endpoints;
  }

  ReelSequencePage parseReelSequencePage(Map<String, dynamic> json) {
    return ReelSequencePage(
      endpoints: parseReelEndpoints(json),
      continuationToken:
          _stringAt(json, [
            'continuationEndpoint',
            'continuationCommand',
            'token',
          ]) ??
          '',
      clickTrackingParams:
          _stringAt(json, ['continuationEndpoint', 'clickTrackingParams']) ??
          '',
    );
  }

  ShortsItem parseInitialPage(String html, String fallbackVideoId) {
    final initialData = parseInitialDataFromPage(html);
    final player = parseInitialPlayerFromPage(html);
    final command = parseCommandFromPage(html);
    final videoId =
        _stringAt(player, ['videoDetails', 'videoId']) ??
        _stringAt(command, ['reelWatchEndpoint', 'videoId']) ??
        fallbackVideoId;

    final fromCommand = parseReelResponse(command, videoId);
    final fromOverlay = parseReelResponse(initialData, videoId);
    return fromOverlay.copyWith(
      videoId: videoId,
      pageUrl: 'https://m.youtube.com/shorts/$videoId',
      title: fromOverlay.title.isNotEmpty
          ? fromOverlay.title
          : _stringAt(player, ['videoDetails', 'title']) ?? '',
      channelName: fromOverlay.channelName.isNotEmpty
          ? fromOverlay.channelName
          : _stringAt(player, ['videoDetails', 'author']) ?? '',
      thumbnailUrl:
          fromOverlay.thumbnailUrl.isNotEmpty &&
              !fromOverlay.thumbnailUrl.endsWith('/vi/$videoId/frame0.jpg')
          ? fromOverlay.thumbnailUrl
          : fromCommand.thumbnailUrl.isNotEmpty
          ? fromCommand.thumbnailUrl
          : 'https://i.ytimg.com/vi/$videoId/frame0.jpg',
      playerParams: fromCommand.playerParams,
      reelParams: fromCommand.reelParams,
      clickTrackingParams: fromCommand.clickTrackingParams,
    );
  }

  Map<String, dynamic> parseInitialDataFromPage(String html) {
    return _extractJsonAssignment(html, 'ytInitialData');
  }

  Map<String, dynamic> parseInitialPlayerFromPage(String html) {
    return _extractJsonAssignment(html, 'ytInitialPlayerResponse');
  }

  Map<String, dynamic> parseCommandFromPage(String html) {
    return _extractJsonAssignment(html, 'ytCommand');
  }

  Map<String, dynamic> parseInitialReelWatchSequenceFromPage(String html) {
    return _extractJsonAssignment(html, 'ytInitialReelWatchSequenceResponse');
  }

  ReelSequencePage parseInitialReelWatchSequencePage(String html) {
    return parseReelSequencePage(parseInitialReelWatchSequenceFromPage(html));
  }

  String parseSequenceParamsFromPage(String html) {
    return _stringAt(parseCommandFromPage(html), [
          'reelWatchEndpoint',
          'sequenceParams',
        ]) ??
        '';
  }

  List<String> parseShortsVideoIdsFromPage(
    String html, {
    String seedVideoId = '',
  }) {
    final seen = <String>{};
    final ids = <String>[];

    void add(String id) {
      if (_isVideoId(id) && seen.add(id)) {
        ids.add(id);
      }
    }

    if (seedVideoId.isNotEmpty) {
      add(seedVideoId);
    }

    for (final match in RegExp(
      r'/(?:shorts|embed)/([A-Za-z0-9_-]{6,})',
    ).allMatches(html)) {
      add(match.group(1)!);
    }
    for (final match in RegExp(
      r'(?:"videoId"|\\x22videoId\\x22)\s*(?::|\\x3a)\s*(?:"|\\x22)([A-Za-z0-9_-]{6,})',
    ).allMatches(html)) {
      add(match.group(1)!);
    }

    for (final json in [
      parseInitialDataFromPage(html),
      parseInitialPlayerFromPage(html),
      parseCommandFromPage(html),
      parseInitialReelWatchSequenceFromPage(html),
    ]) {
      _walk(json, (value) {
        final id = _asString(value['videoId']);
        if (id.isNotEmpty) {
          add(id);
        }
        final endpoint = value['reelWatchEndpoint'];
        if (endpoint is Map<String, dynamic>) {
          add(_asString(endpoint['videoId']));
        }
      });
    }

    return ids;
  }

  ShortsItem parseReelResponse(
    Map<String, dynamic> json,
    String fallbackVideoId,
  ) {
    final endpoint = _endpointFromContainer(json);
    final videoId = fallbackVideoId.isNotEmpty
        ? fallbackVideoId
        : endpoint?.videoId ?? '';
    final metadataItems = _metadataItems(json);
    final channel = _channel(metadataItems);
    final title = _title(metadataItems);
    final music = _music(metadataItems);
    final actions = _actionButtons(json);

    return ShortsItem(
      videoId: videoId,
      title: title,
      channelName: channel.name,
      channelHandle: channel.handle,
      avatarUrl: channel.avatarUrl,
      thumbnailUrl: endpoint?.thumbnailUrl.isNotEmpty == true
          ? endpoint!.thumbnailUrl
          : 'https://i.ytimg.com/vi/$videoId/frame0.jpg',
      musicTitle: music,
      likeText: actions.likeText,
      dislikeText: actions.dislikeText,
      commentText: actions.commentText,
      shareText: actions.shareText,
      pageUrl: 'https://m.youtube.com/shorts/$videoId',
      playerParams: endpoint?.playerParams ?? '',
      reelParams: endpoint?.params ?? '',
      clickTrackingParams:
          endpoint?.clickTrackingParams ??
          _stringAt(json, ['trackingParams']) ??
          '',
    );
  }

  String? parsePlayerTitle(Map<String, dynamic> json) {
    return _stringAt(json, ['videoDetails', 'title']);
  }

  ReelEndpoint? _endpointFromContainer(Map<String, dynamic> container) {
    final endpoint = container['reelWatchEndpoint'] is Map<String, dynamic>
        ? container['reelWatchEndpoint'] as Map<String, dynamic>
        : container;
    final videoId = _asString(endpoint['videoId']);
    final playerParams = _asString(endpoint['playerParams']);
    final params = _asString(endpoint['params']);
    final clickTrackingParams = _asString(container['clickTrackingParams']);
    final thumbnail = _thumbnail(endpoint['thumbnail']);
    if (videoId.isEmpty && playerParams.isEmpty && params.isEmpty) {
      return null;
    }
    return ReelEndpoint(
      videoId: videoId,
      playerParams: playerParams,
      params: params,
      clickTrackingParams: clickTrackingParams,
      thumbnailUrl: thumbnail,
    );
  }

  List<Map<String, dynamic>> _metadataItems(Map<String, dynamic> json) {
    final playerOverlay =
        json['overlay']?['reelPlayerOverlayRenderer']?['playerOverlay']?['reelPlayerOverlayViewModel'];
    final items =
        playerOverlay?['metapanel']?['reelMetapanelViewModel']?['metadataItems'];
    if (items is List) {
      return items.whereType<Map<String, dynamic>>().toList();
    }
    final collected = <Map<String, dynamic>>[];
    _walk(json, (value) {
      final item = value['reelMetapanelViewModel']?['metadataItems'];
      if (item is List) {
        collected.addAll(item.whereType<Map<String, dynamic>>());
      }
    });
    return collected;
  }

  _ChannelInfo _channel(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final channel = item['reelChannelBarViewModel'];
      if (channel is Map<String, dynamic>) {
        final name = _asString(channel['channelName']?['content']);
        return _ChannelInfo(
          name: name,
          handle: name.startsWith('@') ? name : '',
          avatarUrl: _firstSourceUrl(
            channel['decoratedAvatarViewModel']?['decoratedAvatarViewModel']?['avatar']?['avatarViewModel']?['image']?['sources'],
          ),
        );
      }
    }
    return const _ChannelInfo(name: '', handle: '', avatarUrl: '');
  }

  String _title(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final title = item['shortsVideoTitleViewModel'];
      if (title is Map<String, dynamic>) {
        return _asString(title['text']?['content']);
      }
    }
    return '';
  }

  String _music(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final buttons = item['reelCarouselViewModel']?['buttonViewModels'];
      if (buttons is List) {
        for (final button in buttons.whereType<Map<String, dynamic>>()) {
          final title =
              button['buttonViewModel']?['titleFormatted']?['content'];
          final content = _asString(title);
          if (content.isNotEmpty) {
            return content;
          }
        }
      }
    }
    return '';
  }

  _ActionInfo _actionButtons(Map<String, dynamic> json) {
    var like = '';
    var dislike = '不喜欢';
    var comment = '';
    var share = '分享';

    _walk(json, (value) {
      final button = value['buttonViewModel'];
      if (button is! Map<String, dynamic>) {
        return;
      }
      final icon = _asString(button['iconName']);
      final title = _asString(button['title']);
      if (title.isEmpty) {
        return;
      }
      switch (icon) {
        case 'SHORTS_LIKE':
          like = like.isEmpty ? title : like;
        case 'SHORTS_DISLIKE':
          dislike = title;
        case 'SHORTS_COMMENT':
          comment = title;
        case 'SHORTS_SHARE':
          share = title;
      }
    });

    return _ActionInfo(
      likeText: like,
      dislikeText: dislike,
      commentText: comment,
      shareText: share,
    );
  }

  String _thumbnail(dynamic thumbnail) {
    final thumbnails = thumbnail is Map<String, dynamic>
        ? thumbnail['thumbnails']
        : null;
    if (thumbnails is List && thumbnails.isNotEmpty) {
      final first = thumbnails.first;
      if (first is Map<String, dynamic>) {
        return _asString(first['url']);
      }
    }
    return '';
  }

  String _firstSourceUrl(dynamic sources) {
    if (sources is List && sources.isNotEmpty) {
      final first = sources.first;
      if (first is Map<String, dynamic>) {
        return _asString(first['url']);
      }
    }
    return '';
  }

  Map<String, dynamic>? _findObjectWithKey(
    Map<String, dynamic> root,
    String key,
  ) {
    Map<String, dynamic>? found;
    _walk(root, (value) {
      if (found == null && value.containsKey(key)) {
        found = value;
      }
    });
    return found;
  }

  void _walk(dynamic value, void Function(Map<String, dynamic>) visit) {
    if (value is Map<String, dynamic>) {
      visit(value);
      for (final child in value.values) {
        _walk(child, visit);
      }
    } else if (value is List) {
      for (final child in value) {
        _walk(child, visit);
      }
    }
  }

  Map<String, dynamic> _extractJsonAssignment(String html, String name) {
    final starts = _assignmentValueStarts(html, name);
    for (final valueStart in starts) {
      final code = html.codeUnitAt(valueStart);
      final parsed = code == 123
          ? _readJsonObject(html, valueStart)
          : _readJsonStringObject(html, valueStart);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    return const {};
  }

  Iterable<int> _assignmentValueStarts(String html, String name) sync* {
    final patterns = [
      RegExp('(?:var\\s+)?${RegExp.escape(name)}\\s*=\\s*([\\{"\'])'),
      RegExp(
        'window\\s*\\[\\s*["\\\']${RegExp.escape(name)}["\\\']\\s*\\]\\s*=\\s*([\\{"\'])',
      ),
      RegExp('window\\.${RegExp.escape(name)}\\s*=\\s*([\\{"\'])'),
      RegExp(
        'ytcfg\\.set\\s*\\(\\s*\\{\\s*["\\\']${RegExp.escape(name)}["\\\']\\s*:\\s*([\\{"\'])',
      ),
    ];
    for (final pattern in patterns) {
      for (final match in pattern.allMatches(html)) {
        yield match.start + match.group(0)!.length - 1;
      }
    }
  }

  Map<String, dynamic> _readJsonStringObject(String html, int quoteStart) {
    final quote = html.codeUnitAt(quoteStart);
    if (quote != 34 && quote != 39) {
      return const {};
    }
    var escaping = false;
    for (var i = quoteStart + 1; i < html.length; i++) {
      final code = html.codeUnitAt(i);
      if (escaping) {
        escaping = false;
        continue;
      }
      if (code == 92) {
        escaping = true;
        continue;
      }
      if (code == quote) {
        try {
          final decoded = _decodeJavaScriptString(
            html.substring(quoteStart + 1, i),
          );
          return jsonDecodeMap(decoded);
        } on FormatException {
          return const {};
        }
      }
    }
    return const {};
  }

  String _decodeJavaScriptString(String raw) {
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final code = raw.codeUnitAt(i);
      if (code != 92 || i == raw.length - 1) {
        buffer.writeCharCode(code);
        continue;
      }
      final next = raw.codeUnitAt(++i);
      switch (next) {
        case 34:
        case 39:
        case 47:
        case 92:
          buffer.writeCharCode(next);
        case 98:
          buffer.write('\b');
        case 102:
          buffer.write('\f');
        case 110:
          buffer.write('\n');
        case 114:
          buffer.write('\r');
        case 116:
          buffer.write('\t');
        case 118:
          buffer.write('\u000b');
        case 120:
          if (i + 2 >= raw.length) {
            throw const FormatException('Invalid JS hex escape');
          }
          buffer.writeCharCode(
            int.parse(raw.substring(i + 1, i + 3), radix: 16),
          );
          i += 2;
        case 117:
          if (i + 4 >= raw.length) {
            throw const FormatException('Invalid JS unicode escape');
          }
          buffer.writeCharCode(
            int.parse(raw.substring(i + 1, i + 5), radix: 16),
          );
          i += 4;
        default:
          buffer.writeCharCode(next);
      }
    }
    return buffer.toString();
  }

  Map<String, dynamic> _readJsonObject(String html, int start) {
    var depth = 0;
    var inString = false;
    var escaping = false;
    for (var i = start; i < html.length; i++) {
      final code = html.codeUnitAt(i);
      if (inString) {
        if (escaping) {
          escaping = false;
        } else if (code == 92) {
          escaping = true;
        } else if (code == 34) {
          inString = false;
        }
        continue;
      }
      if (code == 34) {
        inString = true;
      } else if (code == 123) {
        depth++;
      } else if (code == 125) {
        depth--;
        if (depth == 0) {
          final raw = html.substring(start, i + 1);
          try {
            return jsonDecodeMap(raw);
          } on FormatException {
            return const {};
          }
        }
      }
    }
    return const {};
  }

  String? _stringAt(Map<String, dynamic> json, List<String> path) {
    dynamic current = json;
    for (final part in path) {
      if (current is! Map<String, dynamic>) {
        return null;
      }
      current = current[part];
    }
    final value = _asString(current);
    return value.isEmpty ? null : value;
  }
}

Map<String, dynamic> jsonDecodeMap(String raw) {
  final decoded = const JsonDecoder().convert(raw);
  if (decoded is Map<String, dynamic>) {
    return decoded;
  }
  return const {};
}

String _asString(dynamic value) => value is String ? value : '';

bool _isVideoId(String value) => RegExp(r'^[A-Za-z0-9_-]{6,}$').hasMatch(value);

class _ChannelInfo {
  const _ChannelInfo({
    required this.name,
    required this.handle,
    required this.avatarUrl,
  });

  final String name;
  final String handle;
  final String avatarUrl;
}

class _ActionInfo {
  const _ActionInfo({
    required this.likeText,
    required this.dislikeText,
    required this.commentText,
    required this.shareText,
  });

  final String likeText;
  final String dislikeText;
  final String commentText;
  final String shareText;
}
