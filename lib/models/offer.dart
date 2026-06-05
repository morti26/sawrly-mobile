class OfferMediaItem {
  final String url;
  final String type;

  const OfferMediaItem({required this.url, required this.type});

  bool get isVideo => type == 'video';

  factory OfferMediaItem.fromJson(dynamic json) {
    if (json is Map) {
      final url = json['url']?.toString() ?? '';
      final type = json['type']?.toString() ?? '';
      return OfferMediaItem(url: url, type: type);
    }
    return const OfferMediaItem(url: '', type: '');
  }
}

class Offer {
  final String id;
  final String title;
  final String description;
  final double price; // Current price in IQD (after discount if any)
  final String imageUrl;
  final List<OfferMediaItem> mediaItems;
  final bool isPopular;
  final bool hasDiscount;
  final int discountPercent; // 0-100
  final double? originalPrice; // Original price before discount
  final int likeCount;
  final int orderCount;

  Offer({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.mediaItems = const [],
    this.isPopular = false,
    this.hasDiscount = false,
    this.discountPercent = 0,
    this.originalPrice,
    this.likeCount = 0,
    this.orderCount = 0,
  });

  String get primaryMediaUrl {
    if (mediaItems.isNotEmpty) {
      final firstImage = mediaItems.firstWhere(
        (item) => !item.isVideo && item.url.trim().isNotEmpty,
        orElse: () => mediaItems.first,
      );
      if (firstImage.url.trim().isNotEmpty) return firstImage.url;
    }
    return imageUrl;
  }

  String get displayDescription {
    if (description.trim().isEmpty) return '';

    final cleanedLines = description
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) =>
            line.isNotEmpty &&
            !line.startsWith('Type:') &&
            !line.startsWith('Discount:'))
        .toList();

    return cleanedLines.join(' ').trim();
  }

  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalized = value.trim().replaceAll(',', '.');
      return double.tryParse(normalized) ?? 0.0;
    }
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static int _parseLegacyDiscount(String description) {
    final match = RegExp(r'Discount:\s*(\d{1,3})%').firstMatch(description);
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
  }

  factory Offer.fromJson(Map<String, dynamic> json) {
    final rawDescription = json['description'] ?? '';
    final dbDiscount = _parseInt(json['discount_percent']);
    final discount =
        dbDiscount > 0 ? dbDiscount : _parseLegacyDiscount(rawDescription);
    final originalRaw = json['original_price_iqd'];
    final originalPrice =
        originalRaw == null ? null : _parseDouble(originalRaw);

    final parsedMediaItems = <OfferMediaItem>[];
    final rawMediaItems = json['media_items'];
    if (rawMediaItems is List) {
      for (final item in rawMediaItems) {
        final parsed = OfferMediaItem.fromJson(item);
        if (parsed.url.trim().isNotEmpty) {
          parsedMediaItems.add(parsed);
        }
      }
    }

    final legacyImageUrl = (json['image_url'] ?? '').toString();
    String effectiveImageUrl = legacyImageUrl;
    if (parsedMediaItems.isNotEmpty) {
      final firstImage = parsedMediaItems.firstWhere(
        (item) => !item.isVideo && item.url.trim().isNotEmpty,
        orElse: () => parsedMediaItems.first,
      );
      if (firstImage.url.trim().isNotEmpty) {
        effectiveImageUrl = firstImage.url;
      }
    }

    return Offer(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: rawDescription,
      price: _parseDouble(json['price_iqd']),
      imageUrl: effectiveImageUrl,
      mediaItems: parsedMediaItems,
      discountPercent: discount,
      originalPrice: originalPrice,
      hasDiscount: discount > 0,
      likeCount: _parseInt(json['like_count']),
      orderCount: _parseInt(json['order_count']),
    );
  }
}
