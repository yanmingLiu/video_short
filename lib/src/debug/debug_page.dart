import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/app_config.dart';
import '../feed/feed_controller.dart';

class DebugPage extends ConsumerStatefulWidget {
  const DebugPage({super.key});

  @override
  ConsumerState<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends ConsumerState<DebugPage> {
  late final TextEditingController _seed;
  late final TextEditingController _clientVersion;
  late final TextEditingController _visitor;
  late final TextEditingController _cookie;
  late final TextEditingController _locale;
  late final TextEditingController _region;
  late final TextEditingController _proxy;
  var _gzip = true;
  var _initialized = false;

  @override
  void initState() {
    super.initState();
    _seed = TextEditingController();
    _clientVersion = TextEditingController();
    _visitor = TextEditingController();
    _cookie = TextEditingController();
    _locale = TextEditingController();
    _region = TextEditingController();
    _proxy = TextEditingController();
  }

  @override
  void dispose() {
    _seed.dispose();
    _clientVersion.dispose();
    _visitor.dispose();
    _cookie.dispose();
    _locale.dispose();
    _region.dispose();
    _proxy.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('调试配置'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: config.when(
        data: (value) {
          _sync(value);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Field(
                controller: _seed,
                label: 'Seed Shorts URL 或 videoId',
                hint: AppConfig.defaultSeedUrl,
              ),
              _Field(
                controller: _clientVersion,
                label: 'x-youtube-client-version',
                hint: AppConfig.defaultClientVersion,
              ),
              _Field(
                controller: _visitor,
                label: 'x-goog-visitor-id / visitorData',
                maxLines: 4,
              ),
              _Field(controller: _cookie, label: 'Cookie', maxLines: 5),
              Row(
                children: [
                  Expanded(
                    child: _Field(controller: _locale, label: 'hl'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(controller: _region, label: 'gl'),
                  ),
                ],
              ),
              _Field(
                controller: _proxy,
                label: '代理 host:port',
                hint: '127.0.0.1:7890',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('gzip 请求体'),
                value: _gzip,
                onChanged: (value) => setState(() => _gzip = value),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('保存并重新加载'),
              ),
              const SizedBox(height: 12),
              Text(
                'Cookie 和 visitor 只保存在本机 secure storage，不会写入仓库。',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        },
        error: (error, stackTrace) => Center(child: Text('$error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _sync(AppConfig config) {
    if (_initialized) {
      return;
    }
    _seed.text = config.seedUrl;
    _clientVersion.text = config.clientVersion;
    _visitor.text = config.visitorData;
    _cookie.text = config.cookie;
    _locale.text = config.locale;
    _region.text = config.region;
    _proxy.text = config.proxyUrl;
    _gzip = config.useGzipBody;
    _initialized = true;
  }

  Future<void> _save() async {
    final next = AppConfig(
      seedUrl: _seed.text.trim().isEmpty
          ? AppConfig.defaultSeedUrl
          : _seed.text.trim(),
      clientVersion: _clientVersion.text.trim().isEmpty
          ? AppConfig.defaultClientVersion
          : _clientVersion.text.trim(),
      visitorData: _visitor.text.trim(),
      cookie: _cookie.text.trim(),
      locale: _locale.text.trim().isEmpty ? 'zh-CN' : _locale.text.trim(),
      region: _region.text.trim().isEmpty ? 'JP' : _region.text.trim(),
      proxyUrl: _proxy.text.trim(),
      useGzipBody: _gzip,
    );
    await ref.read(appConfigProvider.notifier).save(next);
    ref.invalidate(feedProvider);
    if (mounted) {
      context.go('/');
    }
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
