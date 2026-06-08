# AGENTS.md

## 回复约定

- 和用户沟通时使用中文。
- 结论要直接，涉及排障时说明触发流程、调用路径和关键分支。

## 项目定位

`video_short` 是一个 Flutter/Dart 的 YouTube Shorts mweb 实验项目，用移动 Web 请求链路拉取 Shorts 元数据、播放地址和后续推荐队列，并在 App 内以竖滑 feed 播放。

核心链路不要重造临时爬虫，优先复用并扩展现有模块：

- `lib/src/youtube/youtube_mweb_api.dart`：模拟 m.youtube.com / youtubei 请求。
- `lib/src/youtube/youtube_parser.dart`：解析页面内嵌 JSON、reel endpoint、metadata、sequence continuation。
- `lib/src/youtube/shorts_repository.dart`：编排初始加载、endpoint 加载、sequence continuation 和去重。
- `lib/src/feed/feed_controller.dart`：Riverpod feed 状态、分页缓冲和错误状态。
- `lib/src/feed/shorts_playback_pool.dart`：短视频播放预加载、复用和释放。
- `lib/src/feed/shorts_feed_page.dart`、`lib/src/feed/shorts_player_page.dart`：竖滑 feed 和播放 UI。
- `lib/src/debug/debug_page.dart`：本机调试配置入口。
- `bin/crawl_shorts.dart`：命令行验证 Shorts 抓取链路。
- `test/youtube_parser_test.dart`：解析器行为测试。

## 架构约束

- App 入口保持 `ProviderScope -> ShortsApp -> MaterialApp.router` 的结构。
- 路由集中在 `lib/src/app.dart`，当前包含 `/` feed 和 `/debug` 配置页。
- 配置模型在 `AppConfig`，持久化在 `ConfigStore`；cookie、visitorData、代理等敏感调试信息只保存在本机 secure storage，不写入仓库。
- YouTube mweb 流程依赖 `youtubei/v1/player`、`youtubei/v1/reel/reel_item_watch`、`youtubei/v1/reel/reel_watch_sequence`。如果 YouTube 请求形状变化，先对齐真实抓包里的 `x-youtube-client-version`、`videoId`、`playerRequest.params`、顶层 `params`、`sequenceParams`、`clickTrackingParams`，再改代码。
- 下一批 Shorts 的关键字段是 `sequenceParams` 或 continuation token；当前 item 的关键字段是 `videoId`、`playerParams`、`params`、`clickTrackingParams`。
- 解析新增字段时，优先在 `YoutubeParser` 加 focused test，再让 repository 或 UI 消费解析结果。
- feed 预加载和播放生命周期要走 `ShortsPlaybackPool`，避免在页面组件里散落创建和释放 `VideoPlayerController`。

## 开发流程

- 搜索文件和文本优先用 `rg`。
- 改 Dart 代码后运行：

```sh
dart format <changed dart files>
flutter analyze
flutter test
```

- 改 YouTube 抓取链路后额外用 CLI 验证：

```sh
dart run bin/crawl_shorts.dart https://m.youtube.com/shorts/nCVJ2OMUb0Q 5
```

- YouTube 请求头、client version、接口响应具有时效性；提交前要说明当前验证依据。
- 不要提交本机调试配置、cookie、visitorData、抓包原文或生成产物。
- 工作树里可能有用户未提交改动；提交时只 stage 本次任务相关文件。

## 文档维护

- README 面向正常开发者，说明项目用途、架构、配置、运行、测试和注意事项。
- AGENTS 面向 Codex/自动化协作，记录仓库约束和排障优先级。
