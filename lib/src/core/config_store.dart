import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final configStoreProvider = Provider<ConfigStore>((ref) {
  return ConfigStore(ref.watch(secureStorageProvider));
});

final appConfigProvider = AsyncNotifierProvider<AppConfigController, AppConfig>(
  AppConfigController.new,
);

class AppConfigController extends AsyncNotifier<AppConfig> {
  @override
  Future<AppConfig> build() {
    return ref.watch(configStoreProvider).load();
  }

  Future<void> save(AppConfig config) async {
    state = const AsyncLoading();
    await ref.watch(configStoreProvider).save(config);
    state = AsyncData(config);
  }
}

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
