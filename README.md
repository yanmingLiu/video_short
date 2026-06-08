# video_short

`video_short` 是一个 Flutter 实验项目，用 m.youtube.com 的移动 Web 请求链路加载 YouTube Shorts 数据，并在 App 内实现类似 Shorts 的竖向滑动播放体验。

项目主要用于验证：

- 从 Shorts 页面内嵌数据启动抓取流程。
- 模拟 mweb `youtubei` 请求获取 Shorts 元数据和后续推荐队列。
- 解析 `reelWatchEndpoint`、`sequenceParams`、continuation 等关键字段。
- 在 Flutter 中预加载、播放、暂停和释放短视频流。

## 功能

- 竖向滑动 Shorts feed。
- 当前视频自动播放，邻近视频提前预加载。
- 支持播放/暂停、拖动进度条、分享视频链接。
- 支持分页加载后续 Shorts。
- 内置调试配置页，可配置 seed URL、client version、visitorData、cookie、地区、语言、代理和 gzip 请求体。
- 提供 CLI 抓取验证入口，方便在不启动 App 的情况下验证 YouTube 请求链路。

## 技术栈

- Flutter / Dart
- Riverpod：状态管理
- GoRouter：页面路由
- Dio：mweb/youtubei 请求
- video_player：视频播放
- youtube_explode_dart：播放地址解析辅助
- flutter_secure_storage：本机调试配置存储

## 项目结构

```text
lib/
  main.dart                         # Flutter 入口，挂载 ProviderScope
  src/
    app.dart                        # App、主题和路由
    core/
      app_config.dart               # YouTube mweb 请求配置
      config_store.dart             # 本机 secure storage 配置持久化
    debug/
      debug_page.dart               # 调试配置页面
    feed/
      feed_controller.dart          # feed 加载、缓冲和分页状态
      shorts_feed_page.dart         # 竖滑 feed 页面
      shorts_player_page.dart       # 单个 Shorts 播放页
      shorts_playback_pool.dart     # 播放器预加载和生命周期池
    youtube/
      shorts_item.dart              # Shorts 数据模型
      shorts_repository.dart        # YouTube 抓取流程编排
      youtube_mweb_api.dart         # m.youtube.com / youtubei 请求封装
      youtube_parser.dart           # 页面和接口响应解析
      youtube_playback_resolver.dart# 播放地址解析
      youtube_exception.dart        # YouTube 领域错误
bin/
  crawl_shorts.dart                 # CLI 抓取验证
test/
  youtube_parser_test.dart          # YouTube 解析器测试
  widget_test.dart                  # Flutter widget 测试
```

## 环境要求

- Flutter SDK，需满足 `pubspec.yaml` 中的 Dart SDK 约束。
- iOS 或 Android 开发环境。
- 可访问 `m.youtube.com` 和相关 `youtubei` 接口的网络环境。

安装依赖：

```sh
flutter pub get
```

## 运行 App

```sh
flutter run
```

启动后默认使用 `AppConfig.defaultSeedUrl` 作为 seed Shorts。首次加载失败时可进入调试配置页调整请求参数。

常用调试项：

- `seedUrl`：起始 Shorts URL 或 videoId。
- `clientVersion`：`x-youtube-client-version`，需要和当前 mweb 抓包保持一致。
- `visitorData`：对应 `x-goog-visitor-id`。
- `cookie`：需要登录态或地区校验时使用。
- `locale` / `region`：对应 YouTube context 的 `hl` / `gl`。
- `proxyUrl`：本机代理，格式如 `127.0.0.1:7890`。
- `useGzipBody`：是否使用 gzip 压缩 POST 请求体。

调试配置通过 `flutter_secure_storage` 保存在本机，不会写入仓库。

## CLI 验证

用 CLI 可以直接验证抓取链路：

```sh
dart run bin/crawl_shorts.dart https://m.youtube.com/shorts/nCVJ2OMUb0Q 5
```

参数说明：

- 第一个参数：seed Shorts URL 或 videoId。
- 第二个参数：最多输出的 Shorts 数量，默认 `10`。

CLI 会输出 JSON，包含 seed、count 和抓取到的 Shorts 基本信息。

## 测试和质量检查

格式化改动过的 Dart 文件：

```sh
dart format lib test bin
```

静态检查：

```sh
flutter analyze
```

运行测试：

```sh
flutter test
```

## YouTube 抓取链路

当前实现以 mweb 请求为主，核心流程为：

1. 请求 `https://m.youtube.com/shorts/{videoId}` 获取页面 HTML。
2. 从页面中解析 `ytInitialData`、`ytInitialPlayerResponse`、`ytCommand`、`ytInitialReelWatchSequenceResponse`。
3. 从 `reelWatchEndpoint` 提取 `videoId`、`playerParams`、`params`、`clickTrackingParams`。
4. 调用 `youtubei/v1/player` 获取播放器信息。
5. 调用 `youtubei/v1/reel/reel_item_watch` 获取当前 Shorts 元数据和下一批 endpoint。
6. 当队列不足时调用 `youtubei/v1/reel/reel_watch_sequence` 继续加载推荐序列。

YouTube mweb 接口、请求头和 client version 可能随时间变化。如果抓取失败，优先用浏览器 DevTools 对齐当前真实请求中的 `x-youtube-client-version`、`playerRequest.params`、顶层 `params`、`sequenceParams` 和 `clickTrackingParams`。

## 注意事项

- 本项目仅用于技术验证和学习研究。
- 不要把 cookie、visitorData、抓包原文或其它个人敏感信息提交到仓库。
- YouTube 页面结构和接口参数不稳定，解析逻辑需要通过测试和真实请求持续校验。
- 大规模抓取可能违反目标站点规则或触发风控，请自行遵守相关服务条款和法律法规。
