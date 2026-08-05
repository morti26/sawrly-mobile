import 'package:flutter/foundation.dart';

class OfferMediaItem {
  final String url;
  final String type;

  const OfferMediaItem({required this.url, required this.type});

  bool get isVideo => type == 'video';

  factory OfferMediaItem.fromJson(dynamic json) {
    if (json is Map) {
      final url = (json['url'] ?? json['Url'] ?? '').toString().trim();
      final type = (json['type'] ?? json['Type'] ?? '').toString().trim();
      return OfferMediaItem(url: url, type: type);
    }
    return const OfferMediaItem(url: '', type: '');
  }
}

class Offer {
  final String id;
  final String creatorId;
  final String creatorName;
  final String title;
  final String description;
  final double price;
  final double? partialPaymentAmount;
  final double? fullPaymentAmount;
  final String imageUrl;
  final List<OfferMediaItem> mediaItems;
  final bool isPopular;
  final bool hasDiscount;
  final int discountPercent;
  final double? originalPrice;
  final int likeCount;
  final int orderCount;
  final bool likedByMe;

  Offer({
    required this.id,
    this.creatorId = '',
    this.creatorName = '',
    required this.title,
    required this.description,
    required this.price,
    this.partialPaymentAmount,
    this.fullPaymentAmount,
    required this.imageUrl,
    this.mediaItems = const [],
    this.isPopular = false,
    this.hasDiscount = false,
    this.discountPercent = 0,
    this.originalPrice,
    this.likeCount = 0,
    this.orderCount = 0,
    this.likedByMe = false,
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

  double get effectiveFullPaymentAmount {
    final configured = fullPaymentAmount;
    if (configured != null && configured > 0) return configured;
    return price;
  }

  double get effectivePartialPaymentAmount {
    final configured = partialPaymentAmount;
    if (configured != null && configured > 0) return configured;
    return (effectiveFullPaymentAmount * 0.30).ceilToDouble();
  }

  double paymentAmountFor(String portion) {
    if (portion == 'partial') {
      return effectivePartialPaymentAmount;
    }
    return effectiveFullPaymentAmount;
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

  static T? _pick<T>(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      if (json.containsKey(key) && json[key] != null) {
        return json[key] as T;
      }
    }
    return null;
  }

  factory Offer.fromJson(Map<String, dynamic> json) {
    final rawDescription =
        (_pick<String>(json, const ['description', 'Description']) ?? '')
            .toString();

    final dbDiscount = _parseInt(_pick<dynamic>(
        json, const ['discount_percent', 'discountPercent', 'DiscountPercent']));
    final discount =
        dbDiscount > 0 ? dbDiscount : _parseLegacyDiscount(rawDescription);

    final originalRaw = _pick<dynamic>(json,
        const ['original_price_iqd', 'originalPriceIqd', 'OriginalPriceIqd']);
    final originalPrice =
        originalRaw == null ? null : _parseDouble(originalRaw);

    final parsedMediaItems = <OfferMediaItem>[];
    final rawMediaItems = _pick<dynamic>(
        json, const ['media_items', 'mediaItems', 'MediaItems']);
    if (rawMediaItems is List) {
      for (final item in rawMediaItems) {
        final parsed = OfferMediaItem.fromJson(item);
        if (parsed.url.trim().isNotEmpty) {
          parsedMediaItems.add(parsed);
        }
      }
    }

    final legacyImageUrl = (_pick<dynamic>(
            json, const ['image_url', 'imageUrl', 'ImageUrl']) ??
        '')
        .toString();
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

    final parsedId = (_pick<dynamic>(json, const ['id', 'Id']) ?? '').toString();
    if (kDebugMode) {
      debugPrint(
          "DEBUG Offer.fromJson [$parsedId] → legacyImageUrl='$legacyImageUrl' (from image_url/imageUrl), mediaItems.len=${parsedMediaItems.length}, effectiveImageUrl='$effectiveImageUrl'");
    }

    return Offer(
      id: parsedId,
      creatorId:
          (_pick<dynamic>(json, const ['creator_id', 'creatorId', 'CreatorId']) ??
                  '')
              .toString(),
      creatorName: (_pick<dynamic>(
                  json, const ['creator_name', 'creatorName', 'CreatorName']) ??
              '')
          .toString(),
      title: (_pick<String>(json, const ['title', 'Title']) ?? '').toString(),
      description: rawDescription,
      price: _parseDouble(_pick<dynamic>(
          json, const ['price_iqd', 'priceIqd', 'PriceIqd'])),
      partialPaymentAmount: _pick<dynamic>(json, const [
        'partial_payment_iqd',
        'partialPaymentIqd',
        'PartialPaymentIqd'
      ]) == null
          ? null
          : _parseDouble(_pick<dynamic>(json, const [
              'partial_payment_iqd',
              'partialPaymentIqd',
              'PartialPaymentIqd'
            ])),
      fullPaymentAmount: _pick<dynamic>(json, const [
        'full_payment_iqd',
        'fullPaymentIqd',
        'FullPaymentIqd'
      ]) == null
          ? null
          : _parseDouble(_pick<dynamic>(json, const [
              'full_payment_iqd',
              'fullPaymentIqd',
              'FullPaymentIqd'
            ])),
      imageUrl: effectiveImageUrl,
      mediaItems: parsedMediaItems,
      discountPercent: discount,
      originalPrice: originalPrice,
      hasDiscount: discount > 0,
      likeCount: _parseInt(_pick<dynamic>(
          json, const ['like_count', 'likeCount', 'LikeCount'])),
      orderCount: _parseInt(_pick<dynamic>(
          json, const ['order_count', 'orderCount', 'OrderCount'])),
      likedByMe: _pick<dynamic>(
                  json, const ['liked_by_me', 'likedByMe', 'LikedByMe']) ==
              true ||
          _pick<dynamic>(
                  json, const ['liked_by_me', 'likedByMe', 'LikedByMe'])
              .toString()
              .trim() ==
              'true',
    );
  }
}
