class AppConfig {
  const AppConfig({
    required this.seedUrl,
    required this.clientVersion,
    required this.visitorData,
    required this.cookie,
    required this.locale,
    required this.region,
    required this.proxyUrl,
    required this.useGzipBody,
  });

  static const defaultSeedUrl = 'https://m.youtube.com/shorts/nCVJ2OMUb0Q';
  static const defaultClientVersion = '2.20260603.01.00';
  static const defaultUserAgent =
      'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) '
      'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/148.0.0.0 '
      'Mobile Safari/537.36';

  final String seedUrl;
  final String clientVersion;
  final String visitorData;
  final String cookie;
  final String locale;
  final String region;
  final String proxyUrl;
  final bool useGzipBody;

  String get seedVideoId => extractVideoId(seedUrl) ?? 'nCVJ2OMUb0Q';
  bool get hasVisitor => visitorData.trim().isNotEmpty;
  bool get hasCookie => cookie.trim().isNotEmpty;

  AppConfig copyWith({
    String? seedUrl,
    String? clientVersion,
    String? visitorData,
    String? cookie,
    String? locale,
    String? region,
    String? proxyUrl,
    bool? useGzipBody,
  }) {
    return AppConfig(
      seedUrl: seedUrl ?? this.seedUrl,
      clientVersion: clientVersion ?? this.clientVersion,
      visitorData: visitorData ?? this.visitorData,
      cookie: cookie ?? this.cookie,
      locale: locale ?? this.locale,
      region: region ?? this.region,
      proxyUrl: proxyUrl ?? this.proxyUrl,
      useGzipBody: useGzipBody ?? this.useGzipBody,
    );
  }

  Map<String, String> toStorage() {
    return {
      'seedUrl': seedUrl,
      'clientVersion': clientVersion,
      'visitorData': visitorData,
      'cookie': cookie,
      'locale': locale,
      'region': region,
      'proxyUrl': proxyUrl,
      'useGzipBody': useGzipBody ? 'true' : 'false',
    };
  }

  static AppConfig fromStorage(Map<String, String?> values) {
    return AppConfig(
      seedUrl: _valueOr(values['seedUrl'], defaultSeedUrl),
      clientVersion: _valueOr(values['clientVersion'], defaultClientVersion),
      visitorData: values['visitorData'] ?? '',
      cookie: values['cookie'] ?? '',
      locale: _valueOr(values['locale'], 'zh-CN'),
      region: _valueOr(values['region'], 'JP'),
      proxyUrl: values['proxyUrl'] ?? '',
      useGzipBody: values['useGzipBody'] != 'false',
    );
  }

  static AppConfig defaults() => fromStorage(const {});
}

String _valueOr(String? value, String fallback) {
  if (value == null || value.trim().isEmpty) {
    return fallback;
  }
  return value.trim();
}

String? extractVideoId(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(trimmed);
  if (uri != null) {
    final shortsIndex = uri.pathSegments.indexOf('shorts');
    if (shortsIndex >= 0 && uri.pathSegments.length > shortsIndex + 1) {
      return uri.pathSegments[shortsIndex + 1];
    }
    final watchId = uri.queryParameters['v'];
    if (watchId != null && watchId.isNotEmpty) {
      return watchId;
    }
  }
  final bareId = RegExp(r'^[A-Za-z0-9_-]{6,}$');
  if (bareId.hasMatch(trimmed)) {
    return trimmed;
  }
  return null;
}
