class BannerSlide {
  final String url;
  final String type; // 'image' or 'video'
  final String? title;
  final String? linkUrl;

  BannerSlide({required this.url, required this.type, this.title, this.linkUrl});

  factory BannerSlide.fromJson(Map<String, dynamic> json) {
    return BannerSlide(
      url: json['url'] as String,
      type: json['type'] as String? ?? 'image',
      title: json['title'] as String?,
      linkUrl: json['link_url'] as String?,
    );
  }

  bool get isVideo => type == 'video';
}

class BannerAd {
  final int id;
  final String imageUrl;    // kept for backwards compat
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
          .map((s) => BannerSlide.fromJson(s as Map<String, dynamic>))
          .toList();
    }
    // Fallback: if no slides, wrap image_url
    if (slides.isEmpty && json['image_url'] != null) {
      slides = [BannerSlide(url: json['image_url'] as String, type: 'image')];
    }

    return BannerAd(
      id: json['id'] as int,
      imageUrl: json['image_url'] as String? ?? '',
      linkUrl: json['link_url'] as String?,
      title: json['title'] as String? ?? '',
      slides: slides,
    );
  }
}
