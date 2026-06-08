import 'package:flutter_test/flutter_test.dart';
import 'package:video_short/src/core/app_config.dart';

void main() {
  test('extracts shorts video ids from supported inputs', () {
    expect(
      extractVideoId('https://m.youtube.com/shorts/KzKwgNiG3bk'),
      'KzKwgNiG3bk',
    );
    expect(
      extractVideoId('https://www.youtube.com/shorts/Clqq0pQr3zw'),
      'Clqq0pQr3zw',
    );
    expect(
      extractVideoId('https://www.youtube.com/shorts/W9KpTV6xK1g'),
      'W9KpTV6xK1g',
    );
    expect(
      extractVideoId('https://www.youtube.com/shorts/u71T-gOi4v4'),
      'u71T-gOi4v4',
    );
    expect(
      extractVideoId('https://www.youtube.com/watch?v=jB0MET1oRLo'),
      'jB0MET1oRLo',
    );
    expect(extractVideoId('e0H8Ol7q1VA'), 'e0H8Ol7q1VA');
  });
}
