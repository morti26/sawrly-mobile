class BannerSlide {
  final String url;
  final String type; // 'image' or 'video'
  final String? title;
  final String? linkUrl;

  BannerSlide(
      {required this.url, required this.type, this.title, this.linkUrl});

  factory BannerSlide.fromJson(Map<String, dynamic> json) {
    return BannerSlide(
      url: json['url']?.toString() ?? '',
      type: json['type']?.toString() ?? 'image',
      title: json['title']?.toString(),
      linkUrl: json['link_url']?.toString(),
    );
  }

  bool get isVideo => type == 'video';
}

class BannerAd {
  final int id;
  final String imageUrl; // kept for backwards compat
  final String? linkUrl;
  final String title;
  final List<BannerSlide> slides;

  BannerAd({
    required this.id,
    required this.imageUrl,
    this.linkUrl,
    required this.title,
    required this.slides,
  });

  factory BannerAd.fromJson(Map<String, dynamic> json) {
    List<BannerSlide> slides = [];
    if (json['slides'] != null && json['slides'] is List) {
      slides = (json['slides'] as List)
          .whereType<Map>()
          .map((s) => BannerSlide.fromJson(Map<String, dynamic>.from(s)))
          .where((slide) => slide.url.isNotEmpty)
          .toList();
    }
    // Fallback: if no slides, wrap image_url
    if (slides.isEmpty && json['image_url'] != null) {
      slides = [
        BannerSlide(url: json['image_url'].toString(), type: 'image'),
      ];
    }

    return BannerAd(
      id: _parseInt(json['id']),
      imageUrl: json['image_url']?.toString() ?? '',
      linkUrl: json['link_url']?.toString(),
      title: json['title']?.toString() ?? '',
      slides: slides,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
