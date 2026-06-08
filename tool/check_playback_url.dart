import 'dart:convert';
import 'dart:io';

import 'package:video_short/src/core/app_config.dart';
import 'package:video_short/src/youtube/youtube_playback_resolver.dart';

Future<void> main(List<String> args) async {
  final id = extractVideoId(args.isEmpty ? AppConfig.defaultSeedUrl : args[0]);
  if (id == null) {
    stderr.writeln('缺少 Shorts videoId');
    exitCode = 64;
    return;
  }
  final resolver = YoutubePlaybackResolver();
  try {
    final url = await resolver.resolveMuxedUrl(id);
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'videoId': id,
        'host': url.host,
        'path': url.path,
        'hasSignature':
            url.queryParameters.containsKey('sig') ||
            url.queryParameters.containsKey('signature') ||
            url.queryParameters.containsKey('lsig'),
      }),
    );
  } finally {
    resolver.close();
  }
}
