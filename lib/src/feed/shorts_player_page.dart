import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../youtube/shorts_item.dart';
import '../youtube/youtube_playback_resolver.dart';

final _playbackResolver = YoutubePlaybackResolver();

class ShortsPlayerPage extends StatefulWidget {
  const ShortsPlayerPage({
    super.key,
    required this.item,
    required this.isActive,
  });

  final ShortsItem item;
  final bool isActive;

  @override
  State<ShortsPlayerPage> createState() => _ShortsPlayerPageState();
}

class _ShortsPlayerPageState extends State<ShortsPlayerPage> {
  VideoPlayerController? _controller;
  Future<void>? _loadFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _ensureLoaded();
    }
  }

  @override
  void didUpdateWidget(covariant ShortsPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.videoId != oldWidget.item.videoId) {
      _disposeController();
      _error = null;
      _loadFuture = null;
      if (widget.isActive) {
        _ensureLoaded();
      }
      return;
    }
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _ensureLoaded();
      } else {
        _controller?.pause();
      }
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
  }

  void _ensureLoaded() {
    _loadFuture ??= _loadVideo();
  }

  Future<void> _loadVideo() async {
    setState(() => _error = null);
    try {
      final url = await _playbackResolver.resolveMuxedUrl(widget.item.videoId);
      if (!mounted) {
        return;
      }
      final controller = VideoPlayerController.networkUrl(url);
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(1);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _disposeController();
      _controller = controller;
      setState(() {});
      if (widget.isActive) {
        await controller.play();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadFuture = null;
        _error = '视频流加载失败';
      });
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      _ensureLoaded();
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady = controller?.value.isInitialized == true;
    final isPlaying = controller?.value.isPlaying == true;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlayback,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _PosterImage(item: widget.item),
                if (isReady)
                  FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: controller!.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
              ],
            ),
          ),
          const _TopScrim(),
          if (!isReady || !isPlaying)
            Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 68,
                  height: 68,
                  child: _error == null && !isReady
                      ? const Padding(
                          padding: EdgeInsets.all(22),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 42,
                        ),
                ),
              ),
            ),
          if (_error != null)
            Positioned(
              left: 16,
              right: 96,
              bottom: 132,
              child: _InlineError(message: _error!),
            ),
          if (isReady) _PlaybackProgress(controller: controller!),
          _MetaPanel(item: widget.item),
          _ActionRail(item: widget.item),
        ],
      ),
    );
  }
}

class _PlaybackProgress extends StatelessWidget {
  const _PlaybackProgress({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: VideoProgressIndicator(
          controller,
          allowScrubbing: true,
          padding: EdgeInsets.zero,
          colors: VideoProgressColors(
            playedColor: Colors.white,
            bufferedColor: Colors.white.withValues(alpha: 0.34),
            backgroundColor: Colors.white.withValues(alpha: 0.18),
          ),
        ),
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  const _PosterImage({required this.item});

  final ShortsItem item;

  @override
  Widget build(BuildContext context) {
    final url = item.thumbnailUrl;
    if (url.isEmpty) {
      return _PosterFallback(videoId: item.videoId);
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }
        return _PosterFallback(videoId: item.videoId, loading: true);
      },
      errorBuilder: (context, error, stackTrace) {
        return _PosterFallback(videoId: item.videoId);
      },
    );
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback({required this.videoId, this.loading = false});

  final String videoId;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff181818), Color(0xff0b0b0b)],
        ),
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : Text(
                videoId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
      ),
    );
  }
}

class _TopScrim extends StatelessWidget {
  const _TopScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.18),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.78),
            ],
            stops: const [0, 0.44, 1],
          ),
        ),
      ),
    );
  }
}

class _MetaPanel extends StatelessWidget {
  const _MetaPanel({required this.item});

  final ShortsItem item;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 96, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.avatarUrl.isNotEmpty)
                    CircleAvatar(
                      radius: 15,
                      backgroundImage: NetworkImage(item.avatarUrl),
                    ),
                  if (item.avatarUrl.isNotEmpty) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      item.channelName.isEmpty ? '@youtube' : item.channelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 34,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      onPressed: () {},
                      child: const Text('订阅'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.title.isEmpty ? item.videoId : item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  height: 1.25,
                ),
              ),
              if (item.musicTitle.isNotEmpty) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () {},
                  icon: const Icon(Icons.music_note, size: 16),
                  label: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Text(
                      item.musicTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({required this.item});

  final ShortsItem item;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 10, top: 92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                icon: Icons.thumb_up_alt_outlined,
                label: item.likeText.isEmpty ? '赞' : item.likeText,
                onTap: () {},
              ),
              _ActionButton(
                icon: Icons.thumb_down_alt_outlined,
                label: item.dislikeText,
                onTap: () {},
              ),
              _ActionButton(
                icon: Icons.mode_comment_outlined,
                label: item.commentText.isEmpty ? '评论' : item.commentText,
                onTap: () {},
              ),
              _ActionButton(
                icon: Icons.share,
                label: item.shareText,
                onTap: () => SharePlus.instance.share(
                  ShareParams(uri: Uri.parse(item.pageUrl)),
                ),
              ),
              const SizedBox(height: 10),
              _ThumbnailDisc(url: item.thumbnailUrl),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 72,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailDisc extends StatelessWidget {
  const _ThumbnailDisc({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 42,
        height: 42,
        child: url.isEmpty
            ? const ColoredBox(color: Colors.white24)
            : Image.network(url, fit: BoxFit.cover),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}
