import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app_config.dart';

class ConfigStore {
  ConfigStore(this._storage);

  static const _keys = [
    'seedUrl',
    'clientVersion',
    'visitorData',
    'cookie',
    'locale',
    'region',
    'proxyUrl',
    'useGzipBody',
  ];

  final FlutterSecureStorage _storage;

  Future<AppConfig> load() async {
    final values = <String, String?>{};
    for (final key in _keys) {
      values[key] = await _storage.read(key: key);
    }
    return AppConfig.fromStorage(values);
  }

  Future<void> save(AppConfig config) async {
    for (final entry in config.toStorage().entries) {
      await _storage.write(key: entry.key, value: entry.value);
    }
  }
}
