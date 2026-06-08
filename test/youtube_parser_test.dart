import 'package:flutter_test/flutter_test.dart';
import 'package:video_short/src/youtube/youtube_parser.dart';

void main() {
  test('parses reel item watch overlay metadata', () {
    final parser = YoutubeParser();
    final item = parser.parseReelResponse(_reelResponseFixture, 'e0H8Ol7q1VA');

    expect(item.videoId, 'e0H8Ol7q1VA');
    expect(item.title, 'Yamal Finally Danced With The Cat');
    expect(item.channelName, '@Mew16Football');
    expect(item.musicTitle, 'Original audio');
    expect(item.likeText, '4.1万');
    expect(item.commentText, '71');
    expect(item.shareText, '分享');
  });

  test('parses reel endpoints from nested player response', () {
    final parser = YoutubeParser();
    final endpoints = parser.parseReelEndpoints(_playerResponseFixture);

    expect(endpoints, hasLength(1));
    expect(endpoints.single.videoId, 'e0H8Ol7q1VA');
    expect(endpoints.single.playerParams, 'playerParams');
    expect(endpoints.single.params, 'reelParams');
    expect(endpoints.single.clickTrackingParams, 'tracking');
  });

  test('parses reel watch sequence entries and continuation', () {
    final parser = YoutubeParser();
    final page = parser.parseReelSequencePage(_sequenceResponseFixture);

    expect(page.endpoints, hasLength(2));
    expect(page.endpoints.first.videoId, 'firstShort');
    expect(page.endpoints.first.playerParams, 'firstPlayerParams');
    expect(page.endpoints.first.params, 'firstParams');
    expect(page.endpoints.first.clickTrackingParams, 'firstTracking');
    expect(page.continuationToken, 'nextToken');
    expect(page.clickTrackingParams, 'nextTracking');
  });

  test('parses escaped initial reel watch sequence from page', () {
    final parser = YoutubeParser();
    final page = parser.parseInitialReelWatchSequencePage(r'''
      <script>
        var ytInitialReelWatchSequenceResponse = '\x7b\x22entries\x22:\x5b\x7b\x22command\x22:\x7b\x22clickTrackingParams\x22:\x22firstTracking\x22,\x22commandMetadata\x22:\x7b\x22webCommandMetadata\x22:\x7b\x22url\x22:\x22\/shorts\/firstShort\x22\x7d\x7d,\x22reelWatchEndpoint\x22:\x7b\x22videoId\x22:\x22firstShort\x22,\x22playerParams\x22:\x22firstPlayerParams\x22,\x22params\x22:\x22firstParams\x22,\x22thumbnail\x22:\x7b\x22thumbnails\x22:\x5b\x7b\x22url\x22:\x22https:\/\/i.ytimg.com\/vi\/firstShort\/frame0.jpg\x22\x7d\x5d\x7d\x7d\x7d\x7d\x5d,\x22continuationEndpoint\x22:\x7b\x22clickTrackingParams\x22:\x22nextTracking\x22,\x22continuationCommand\x22:\x7b\x22token\x22:\x22nextToken\x22\x7d\x7d\x7d';
        window["ytInitialReelWatchSequenceResponse"]=JSON.parse(ytInitialReelWatchSequenceResponse);
      </script>
    ''');

    expect(page.endpoints, hasLength(1));
    expect(page.endpoints.single.videoId, 'firstShort');
    expect(page.endpoints.single.thumbnailUrl, contains('firstShort'));
    expect(page.continuationToken, 'nextToken');
    expect(page.clickTrackingParams, 'nextTracking');
  });

  test('parses current command endpoint from page', () {
    final parser = YoutubeParser();
    final item = parser.parseInitialPage('''
      <script>
        window['ytCommand'] = {
          "clickTrackingParams": "currentTracking",
          "reelWatchEndpoint": {
            "videoId": "Clqq0pQr3zw",
            "playerParams": "currentPlayerParams",
            "params": "currentParams",
            "thumbnail": {
              "thumbnails": [
                {"url": "https://i.ytimg.com/vi/Clqq0pQr3zw/frame0.jpg"}
              ]
            }
          }
        };
      </script>
    ''', 'fallback');

    expect(item.videoId, 'Clqq0pQr3zw');
    expect(item.playerParams, 'currentPlayerParams');
    expect(item.reelParams, 'currentParams');
    expect(item.clickTrackingParams, 'currentTracking');
  });

  test(
    'keeps requested video id when reel response includes next endpoint',
    () {
      final parser = YoutubeParser();
      final item = parser.parseReelResponse(
        _reelResponseWithNextEndpointFixture,
        'currentVideo',
      );
      final endpoints = parser.parseReelEndpoints(
        _reelResponseWithNextEndpointFixture,
      );

      expect(item.videoId, 'currentVideo');
      expect(item.title, 'Current title');
      expect(
        item.thumbnailUrl,
        'https://i.ytimg.com/vi/currentVideo/frame0.jpg',
      );
      expect(endpoints.single.videoId, 'nextVideo');
    },
  );

  test('skips non-json script blocks before initial data', () {
    final parser = YoutubeParser();
    final item = parser.parseInitialPage('''
      <script>{window.ytcsi.tick('pdr', null, '');}</script>
      <script>
        var ytInitialData = {
          "overlay": {
            "reelPlayerOverlayRenderer": {
              "playerOverlay": {
                "reelPlayerOverlayViewModel": {
                  "metapanel": {
                    "reelMetapanelViewModel": {
                      "metadataItems": [
                        {"shortsVideoTitleViewModel":{"text":{"content":"Real title"}}}
                      ]
                    }
                  }
                }
              }
            }
          }
        };
        window["ytInitialPlayerResponse"] = {
          "videoDetails": {"videoId":"jB0MET1oRLo","title":"Player title"}
        };
      </script>
      ''', 'fallback');

    expect(item.videoId, 'jB0MET1oRLo');
    expect(item.title, 'Real title');
  });

  test('parses escaped string initial data assignments', () {
    final parser = YoutubeParser();
    final item = parser.parseInitialPage(r'''
      <script>
        var ytInitialData = '\x7b\x22replacementEndpoint\x22:\x7b\x22reelWatchEndpoint\x22:\x7b\x22videoId\x22:\x22jB0MET1oRLo\x22,\x22playerParams\x22:\x22playerParams\x22,\x22params\x22:\x22reelParams\x22\x7d\x7d,\x22overlay\x22:\x7b\x22reelPlayerOverlayRenderer\x22:\x7b\x22playerOverlay\x22:\x7b\x22reelPlayerOverlayViewModel\x22:\x7b\x22metapanel\x22:\x7b\x22reelMetapanelViewModel\x22:\x7b\x22metadataItems\x22:\x5b\x7b\x22shortsVideoTitleViewModel\x22:\x7b\x22text\x22:\x7b\x22content\x22:\x22Escaped title\x22\x7d\x7d\x7d\x5d\x7d\x7d\x7d\x7d\x7d\x7d\x7d';
        var ytInitialPlayerResponse = '\x7b\x22videoDetails\x22:\x7b\x22videoId\x22:\x22jB0MET1oRLo\x22,\x22title\x22:\x22Player title\x22\x7d\x7d';
      </script>
      ''', 'fallback');

    expect(item.videoId, 'jB0MET1oRLo');
    expect(item.title, 'Escaped title');
    expect(item.playerParams, isEmpty);
    expect(item.reelParams, isEmpty);
  });
}

const _reelResponseFixture = {
  'overlay': {
    'reelPlayerOverlayRenderer': {
      'playerOverlay': {
        'reelPlayerOverlayViewModel': {
          'metapanel': {
            'reelMetapanelViewModel': {
              'metadataItems': [
                {
                  'reelChannelBarViewModel': {
                    'channelName': {'content': '@Mew16Football'},
                    'decoratedAvatarViewModel': {
                      'decoratedAvatarViewModel': {
                        'avatar': {
                          'avatarViewModel': {
                            'image': {
                              'sources': [
                                {'url': 'https://example.com/avatar.jpg'},
                              ],
                            },
                          },
                        },
                      },
                    },
                  },
                },
                {
                  'shortsVideoTitleViewModel': {
                    'text': {'content': 'Yamal Finally Danced With The Cat'},
                  },
                },
                {
                  'reelCarouselViewModel': {
                    'buttonViewModels': [
                      {
                        'buttonViewModel': {
                          'titleFormatted': {'content': 'Original audio'},
                        },
                      },
                    ],
                  },
                },
              ],
            },
          },
          'actionBar': {
            'reelActionBarViewModel': {
              'buttonViewModels': [
                {
                  'likeButtonViewModel': {
                    'toggleButtonViewModel': {
                      'toggleButtonViewModel': {
                        'defaultButtonViewModel': {
                          'buttonViewModel': {
                            'iconName': 'SHORTS_LIKE',
                            'title': '4.1万',
                          },
                        },
                      },
                    },
                  },
                },
                {
                  'buttonViewModel': {
                    'iconName': 'SHORTS_COMMENT',
                    'title': '71',
                  },
                },
                {
                  'buttonViewModel': {
                    'iconName': 'SHORTS_SHARE',
                    'title': '分享',
                  },
                },
              ],
            },
          },
        },
      },
    },
  },
};

const _playerResponseFixture = {
  'next': {
    'reelWatchEndpoint': {
      'videoId': 'e0H8Ol7q1VA',
      'playerParams': 'playerParams',
      'params': 'reelParams',
      'thumbnail': {
        'thumbnails': [
          {'url': 'https://example.com/frame.jpg'},
        ],
      },
    },
    'clickTrackingParams': 'tracking',
  },
};

const _reelResponseWithNextEndpointFixture = {
  'overlay': {
    'reelPlayerOverlayRenderer': {
      'playerOverlay': {
        'reelPlayerOverlayViewModel': {
          'metapanel': {
            'reelMetapanelViewModel': {
              'metadataItems': [
                {
                  'shortsVideoTitleViewModel': {
                    'text': {'content': 'Current title'},
                  },
                },
              ],
            },
          },
        },
      },
    },
  },
  'frameworkUpdates': {
    'next': {
      'reelWatchEndpoint': {
        'videoId': 'nextVideo',
        'playerParams': 'nextPlayerParams',
        'params': 'nextParams',
      },
      'clickTrackingParams': 'nextTracking',
    },
  },
};

const _sequenceResponseFixture = {
  'entries': [
    {
      'command': {
        'clickTrackingParams': 'firstTracking',
        'reelWatchEndpoint': {
          'videoId': 'firstShort',
          'playerParams': 'firstPlayerParams',
          'params': 'firstParams',
        },
      },
    },
    {
      'command': {
        'clickTrackingParams': 'secondTracking',
        'reelWatchEndpoint': {
          'videoId': 'secondShort',
          'playerParams': 'secondPlayerParams',
          'params': 'secondParams',
        },
      },
    },
  ],
  'continuationEndpoint': {
    'clickTrackingParams': 'nextTracking',
    'continuationCommand': {'token': 'nextToken'},
  },
};
