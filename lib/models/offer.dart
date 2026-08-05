import 'package:flutter/foundation.dart';

String normalizePublicMediaUrl(String raw) {
  final String value = raw.toString().trim();
  if (value.isEmpty) return '';
  String url = value;

  // Steg 0: Ta bort "/api/" prefix för statiska media-filer (backend returnerar
  // /api/uploads/... men static files servas från /uploads/... utan /api)
  const kStaticFolders = ['uploads/', 'images/', 'media/', 'videos/'];
  if (url.startsWith('/api/')) {
    final rest = url.substring('/api/'.length); // ex: 'uploads/offers/...'
    for (final folder in kStaticFolders) {
      if (rest.startsWith(folder)) {
        url = '/$rest'; // '/uploads/offers/...'
        break;
      }
    }
  } else if (url.startsWith('api/')) {
    final rest = url.substring('api/'.length);
    for (final folder in kStaticFolders) {
      if (rest.startsWith(folder)) {
        url = rest; // 'uploads/offers/...' (hanteras av steg 1)
        break;
      }
    }
  }

  // Steg 1: Hantera alla kända prefix för relativa URL:er
  if (url.startsWith('/')) {
    url = 'https://sawrly.com$url';
  } else if (url.startsWith('uploads/') ||
      url.startsWith('images/') ||
      url.startsWith('media/') ||
      url.startsWith('videos/')) {
    url = 'https://sawrly.com/$url';
  } else if (url.startsWith('http://10.0.2.2:') ||
      url.startsWith('http://localhost:')) {
    url = url.replaceFirst(
        RegExp(r'http://(10\.0\.2\.2|localhost):\d+'), 'https://sawrly.com');
  } else if (url.startsWith('http://sawrly.com')) {
    url = url.replaceFirst('http://', 'https://');
  } else if (!url.startsWith('http')) {
    url = 'https://sawrly.com/$url';
  }

  // Steg 2: För alla fullständiga URL:er – hantera äldre legacy-domän och http-schema
  const legacyHost = 'ph.sitely24.com';
  final uri = Uri.tryParse(url);
  if (uri != null && uri.hasAuthority) {
    bool changed = false;
    String scheme = uri.scheme;
    String host = uri.host;
    int? port = uri.hasPort ? uri.port : null;
    String path = uri.path;

    // Ta bort /api/ prefix från path om det pekar på statiska folders (även för fullständiga URL:er)
    if (path.startsWith('/api/')) {
      final rest = path.substring('/api/'.length);
      for (final folder in kStaticFolders) {
        if (rest.startsWith(folder)) {
          path = '/$rest';
          changed = true;
          break;
        }
      }
    }

    // Ersätt äldre legacy-domän med sawrly.com
    if (host == legacyHost) {
      host = 'sawrly.com';
      changed = true;
    }

    // Alltid https om det är sawrly (eller legacy som precis bytts)
    if (scheme == 'http' && (host == 'sawrly.com')) {
      scheme = 'https';
      port = null;
      changed = true;
    }

    if (changed) {
      url = uri
          .replace(
            scheme: scheme,
            host: host,
            port: port,
            path: path,
          )
          .toString();
    }
  }

  // Steg 3: URL-encoding om Uri.parse skulle krascha pga specialtecken
  try {
    Uri.parse(url);
    return url;
  } catch (_) {
    try {
      return Uri.encodeFull(url);
    } catch (_) {
      return '';
    }
  }
}

class OfferMediaItem {
  final String rawUrl;
  final String type;
  final String url;

  const OfferMediaItem({
    required this.rawUrl,
    required this.type,
    required this.url,
  });

  bool get isVideo => type == 'video';

  factory OfferMediaItem.fromJson(dynamic json) {
    if (json is Map) {
      final rawUrl =
          (json['url'] ?? json['Url'] ?? json['image_url'] ?? json['mediaUrl'] ?? '')
              .toString()
              .trim();
      final type = (json['type'] ?? json['Type'] ?? 'image').toString().trim();
      final normalized = normalizePublicMediaUrl(rawUrl);
      return OfferMediaItem(
        rawUrl: rawUrl,
        type: type,
        url: normalized,
      );
    }
    return const OfferMediaItem(rawUrl: '', type: 'image', url: '');
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
    final normalizedLegacyImageUrl = normalizePublicMediaUrl(legacyImageUrl);
    String effectiveImageUrl = normalizedLegacyImageUrl;
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
          "DEBUG Offer.fromJson [$parsedId] → raw='$legacyImageUrl' → normalizedLegacy='$normalizedLegacyImageUrl' | mediaItems.len=${parsedMediaItems.length}");
      for (int i = 0; i < parsedMediaItems.length && i < 6; i++) {
        final m = parsedMediaItems[i];
        debugPrint("  ... media[$i] type=${m.type} raw='${m.rawUrl}' normalized='${m.url}'");
      }
      debugPrint("  ... effectiveImageUrl='$effectiveImageUrl'");
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
