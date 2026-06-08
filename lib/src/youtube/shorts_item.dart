class ShortsItem {
  const ShortsItem({
    required this.videoId,
    required this.title,
    required this.channelName,
    required this.channelHandle,
    required this.avatarUrl,
    required this.thumbnailUrl,
    required this.musicTitle,
    required this.likeText,
    required this.dislikeText,
    required this.commentText,
    required this.shareText,
    required this.pageUrl,
    required this.playerParams,
    required this.reelParams,
    required this.clickTrackingParams,
  });

  final String videoId;
  final String title;
  final String channelName;
  final String channelHandle;
  final String avatarUrl;
  final String thumbnailUrl;
  final String musicTitle;
  final String likeText;
  final String dislikeText;
  final String commentText;
  final String shareText;
  final String pageUrl;
  final String playerParams;
  final String reelParams;
  final String clickTrackingParams;

  bool get canLoadReel => playerParams.isNotEmpty && reelParams.isNotEmpty;

  ShortsItem copyWith({
    String? videoId,
    String? title,
    String? channelName,
    String? channelHandle,
    String? avatarUrl,
    String? thumbnailUrl,
    String? musicTitle,
    String? likeText,
    String? dislikeText,
    String? commentText,
    String? shareText,
    String? pageUrl,
    String? playerParams,
    String? reelParams,
    String? clickTrackingParams,
  }) {
    return ShortsItem(
      videoId: videoId ?? this.videoId,
      title: title ?? this.title,
      channelName: channelName ?? this.channelName,
      channelHandle: channelHandle ?? this.channelHandle,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      musicTitle: musicTitle ?? this.musicTitle,
      likeText: likeText ?? this.likeText,
      dislikeText: dislikeText ?? this.dislikeText,
      commentText: commentText ?? this.commentText,
      shareText: shareText ?? this.shareText,
      pageUrl: pageUrl ?? this.pageUrl,
      playerParams: playerParams ?? this.playerParams,
      reelParams: reelParams ?? this.reelParams,
      clickTrackingParams: clickTrackingParams ?? this.clickTrackingParams,
    );
  }

  factory ShortsItem.seed(String videoId) {
    return ShortsItem(
      videoId: videoId,
      title: '',
      channelName: '',
      channelHandle: '',
      avatarUrl: '',
      thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/frame0.jpg',
      musicTitle: '',
      likeText: '',
      dislikeText: '不喜欢',
      commentText: '',
      shareText: '分享',
      pageUrl: 'https://m.youtube.com/shorts/$videoId',
      playerParams: '',
      reelParams: '',
      clickTrackingParams: '',
    );
  }
}

class ReelEndpoint {
  const ReelEndpoint({
    required this.videoId,
    required this.playerParams,
    required this.params,
    required this.clickTrackingParams,
    required this.thumbnailUrl,
  });

  final String videoId;
  final String playerParams;
  final String params;
  final String clickTrackingParams;
  final String thumbnailUrl;

  bool get isUsable =>
      videoId.isNotEmpty || playerParams.isNotEmpty || params.isNotEmpty;
  bool get canRequestReelItem =>
      videoId.isNotEmpty && playerParams.isNotEmpty && params.isNotEmpty;
}

class ReelSequencePage {
  const ReelSequencePage({
    required this.endpoints,
    required this.continuationToken,
    required this.clickTrackingParams,
  });

  final List<ReelEndpoint> endpoints;
  final String continuationToken;
  final String clickTrackingParams;

  bool get hasContinuation => continuationToken.isNotEmpty;
}
