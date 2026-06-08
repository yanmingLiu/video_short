import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../youtube/shorts_item.dart';
import 'shorts_playback_pool.dart';

class ShortsPlayerPage extends StatefulWidget {
  const ShortsPlayerPage({
    super.key,
    required this.item,
    required this.playback,
    required this.isActive,
  });

  final ShortsItem item;
  final ShortsPlaybackEntry playback;
  final bool isActive;

  @override
  State<ShortsPlayerPage> createState() => _ShortsPlayerPageState();
}

class _ShortsPlayerPageState extends State<ShortsPlayerPage> {
  @override
  void initState() {
    super.initState();
    widget.playback.addListener(_handlePlaybackChanged);
    if (widget.isActive) {
      widget.playback.activate();
    } else {
      widget.playback.prepare();
    }
  }

  @override
  void didUpdateWidget(covariant ShortsPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playback != oldWidget.playback) {
      oldWidget.playback.removeListener(_handlePlaybackChanged);
      oldWidget.playback.deactivate();
      widget.playback.addListener(_handlePlaybackChanged);
      if (widget.isActive) {
        widget.playback.activate();
      } else {
        widget.playback.prepare();
      }
      return;
    }
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        widget.playback.activate();
      } else {
        widget.playback.deactivate();
      }
    }
  }

  @override
  void dispose() {
    widget.playback.removeListener(_handlePlaybackChanged);
    if (widget.isActive) {
      widget.playback.deactivate();
    }
    super.dispose();
  }

  void _handlePlaybackChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.playback.controller;
    final isReady = controller?.value.isInitialized == true;
    final isPlaying = controller?.value.isPlaying == true;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.playback.togglePlayback,
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
                  child: widget.playback.error == null && !isReady
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
          if (widget.playback.error != null)
            Positioned(
              left: 16,
              right: 96,
              bottom: 132,
              child: _InlineError(message: widget.playback.error!),
            ),
          _MetaPanel(item: widget.item),
          _ActionRail(item: widget.item),
          if (isReady)
            _PlaybackProgress(
              controller: controller!,
              onSeek: widget.playback.seekTo,
            ),
        ],
      ),
    );
  }
}

class _PlaybackProgress extends StatefulWidget {
  const _PlaybackProgress({required this.controller, required this.onSeek});

  final VideoPlayerController controller;
  final Future<void> Function(Duration position) onSeek;

  @override
  State<_PlaybackProgress> createState() => _PlaybackProgressState();
}

class _PlaybackProgressState extends State<_PlaybackProgress> {
  var _isScrubbing = false;
  Duration? _scrubPosition;

  VideoPlayerController get _controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller,
      builder: (context, value, child) {
        final showBar = _isScrubbing || !value.isPlaying;
        if (!value.isInitialized || value.duration <= Duration.zero) {
          return const SizedBox.shrink();
        }
        final position = _scrubPosition ?? value.position;
        final progress = _progressFor(position, value.duration);
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                _isScrubbing ? 28 : 30,
                0,
                _isScrubbing ? 28 : 30,
                _isScrubbing ? 12 : 3,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 120),
                    child: _isScrubbing
                        ? Padding(
                            key: const ValueKey('time'),
                            padding: const EdgeInsets.only(bottom: 118),
                            child: _ProgressTimeLabel(
                              position: position,
                              duration: value.duration,
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('empty-time')),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragStart: (details) {
                          _updateScrub(details.localPosition.dx, width);
                        },
                        onHorizontalDragUpdate: (details) {
                          _updateScrub(details.localPosition.dx, width);
                        },
                        onHorizontalDragEnd: (_) => _commitScrub(),
                        onHorizontalDragCancel: _commitScrub,
                        onTapDown: (details) {
                          _updateScrub(details.localPosition.dx, width);
                        },
                        onTapUp: (_) => _commitScrub(),
                        onTapCancel: _commitScrub,
                        child: SizedBox(
                          height: _isScrubbing ? 28 : 14,
                          child: Center(
                            child: AnimatedOpacity(
                              opacity: showBar ? 1 : 0,
                              duration: const Duration(milliseconds: 120),
                              child: _RoundedProgressBar(
                                progress: progress,
                                height: _isScrubbing ? 14 : 4,
                                thumbRadius: _isScrubbing ? 10 : 0,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _updateScrub(double localX, double width) {
    if (width <= 0) {
      return;
    }
    final value = _controller.value;
    final fraction = (localX / width).clamp(0.0, 1.0);
    final position = value.duration * fraction;
    setState(() {
      _isScrubbing = true;
      _scrubPosition = position;
    });
  }

  Future<void> _commitScrub() async {
    final position = _scrubPosition;
    if (position != null) {
      await widget.onSeek(position);
    }
    if (mounted) {
      setState(() {
        _isScrubbing = false;
        _scrubPosition = null;
      });
    }
  }

  double _progressFor(Duration position, Duration duration) {
    if (duration <= Duration.zero) {
      return 0;
    }
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}

class _RoundedProgressBar extends StatelessWidget {
  const _RoundedProgressBar({
    required this.progress,
    required this.height,
    required this.thumbRadius,
  });

  final double progress;
  final double height;
  final double thumbRadius;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final playedWidth = trackWidth * progress;
        return SizedBox(
          height: thumbRadius > 0 ? thumbRadius * 2 : height,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: playedWidth,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              if (thumbRadius > 0)
                Positioned(
                  left: (playedWidth - thumbRadius).clamp(
                    0.0,
                    (trackWidth - thumbRadius * 2).clamp(0.0, double.infinity),
                  ),
                  child: Container(
                    width: thumbRadius * 2,
                    height: thumbRadius * 2,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressTimeLabel extends StatelessWidget {
  const _ProgressTimeLabel({required this.position, required this.duration});

  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: _formatDuration(position)),
          const TextSpan(text: ' / '),
          TextSpan(
            text: _formatDuration(duration),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.64)),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
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
