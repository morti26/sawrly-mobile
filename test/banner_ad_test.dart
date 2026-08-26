import 'package:flutter_test/flutter_test.dart';
import 'package:fotgraf_mobile/models/banner_ad.dart';

void main() {
  test('parses banner ids returned as strings by the API', () {
    final banner = BannerAd.fromJson({
      'id': '42',
      'image_url': 'https://example.com/banner.jpg',
      'title': 'Banner',
    });

    expect(banner.id, 42);
    expect(banner.slides, hasLength(1));
    expect(banner.slides.single.url, 'https://example.com/banner.jpg');
  });

  test('ignores malformed slides without crashing the home screen', () {
    final banner = BannerAd.fromJson({
      'id': 7.0,
      'slides': [
        null,
        'invalid',
        {'url': 'https://example.com/valid.jpg', 'type': 'image'},
      ],
    });

    expect(banner.id, 7);
    expect(banner.slides, hasLength(1));
  });
}
