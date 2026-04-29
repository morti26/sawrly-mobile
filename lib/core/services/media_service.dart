import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../network/api_client.dart';
import '../../models/banner_ad.dart';

class MediaService {
  final ApiClient _apiClient;
  final ImagePicker _picker = ImagePicker();
  String? _cachedHomeLogoUrl;
  DateTime? _cachedHomeLogoFetchedAt;
  String? _lastUploadError;
  static const String _tooLargeUploadMessage =
      'حجم الملف كبير جداً. يرجى اختيار ملف أصغر.';
  static const String _genericUploadFailureMessage = 'حدث خطأ أثناء رفع الملف.';

  MediaService(this._apiClient);

  String? get lastUploadError => _lastUploadError;

  String _buildFrozenMessage(String? frozenUntilRaw) {
    if (frozenUntilRaw == null || frozenUntilRaw.trim().isEmpty) {
      return "حسابك مجمد مؤقتاً. لا يمكنك نشر محتوى حالياً.";
    }

    final parsed = DateTime.tryParse(frozenUntilRaw)?.toLocal();
    if (parsed == null) {
      return "حسابك مجمد مؤقتاً. لا يمكنك نشر محتوى حالياً.";
    }

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    return "حسابك مجمد حتى $day/$month/$year. لا يمكنك نشر محتوى حالياً.";
  }

  bool _looksLikeHtml(String value) {
    final normalized = value.trimLeft().toLowerCase();
    return normalized.startsWith('<!doctype html') ||
        normalized.startsWith('<html') ||
        (normalized.contains('<html') && normalized.contains('</html>'));
  }

  bool _isRequestTooLargeText(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('request entity too large') ||
        normalized.contains('payload too large') ||
        RegExp(r'\b413\b').hasMatch(normalized);
  }

  String _sanitizeApiErrorText(String text, {required String fallback}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return fallback;

    if (_looksLikeHtml(trimmed)) {
      return _isRequestTooLargeText(trimmed)
          ? _tooLargeUploadMessage
          : fallback;
    }

    if (_isRequestTooLargeText(trimmed)) {
      return _tooLargeUploadMessage;
    }

    return trimmed;
  }

  String _extractApiError(DioException e, {String fallback = 'حدث خطأ'}) {
    if (e.response?.statusCode == 413) {
      return _tooLargeUploadMessage;
    }

    final data = e.response?.data;
    if (data is Map) {
      final errorText = data['error']?.toString();
      final frozenUntil = data['frozenUntil']?.toString();
      final isFrozen = (frozenUntil != null && frozenUntil.trim().isNotEmpty) ||
          ((errorText ?? '').contains('تجميد'));

      if (isFrozen) {
        return _buildFrozenMessage(frozenUntil);
      }

      if (errorText != null && errorText.trim().isNotEmpty) {
        return _sanitizeApiErrorText(errorText, fallback: fallback);
      }
    } else if (data is String && data.trim().isNotEmpty) {
      return _sanitizeApiErrorText(data, fallback: fallback);
    }

    final message = e.message;
    if (message != null && message.trim().isNotEmpty) {
      return _sanitizeApiErrorText(message, fallback: fallback);
    }

    return fallback;
  }

  String _normalizePublicUrl(String url) {
    if (url.startsWith('/')) return 'https://sawrly.com$url';
    if (url.startsWith('http://sawrly.com')) {
      return url.replaceFirst('http://', 'https://');
    }
    if (url.startsWith('http://ph.sitely24.com')) {
      return url.replaceFirst('http://ph.sitely24.com', 'https://sawrly.com');
    }
    return url;
  }

  Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) return File(image.path);
    return null;
  }

  Future<File?> pickVideo({ImageSource source = ImageSource.gallery}) async {
    final XFile? video = await _picker.pickVideo(source: source);
    if (video != null) return File(video.path);
    return null;
  }

  // Generic upload returning URL (for ephemeral use like Status)
  Future<String?> uploadFile(File file, {String subDir = 'status'}) async {
    _lastUploadError = null;
    try {
      String fileName = file.path.split(Platform.pathSeparator).last;
      String? mimeType = lookupMimeType(file.path);
      MediaType? mediaType =
          mimeType != null ? MediaType.parse(mimeType) : null;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: mediaType,
        ),
      });

      // Using the new generic /api/upload endpoint
      final res = await _apiClient.client.post(
        '/upload',
        queryParameters: {'subDir': subDir},
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = res.data;
        if (data is Map) {
          return data['url']?.toString();
        } else {
          debugPrint("Upload error: Response data is not a Map: $data");
        }
      }
      debugPrint("Upload returned status: ${res.statusCode}");
      return null;
    } on DioException catch (e) {
      _lastUploadError = _extractApiError(e, fallback: "فشل رفع الملف");
      debugPrint("File Upload Error: $_lastUploadError");
      return null;
    } catch (e) {
      _lastUploadError = _sanitizeApiErrorText(
        e.toString(),
        fallback: _genericUploadFailureMessage,
      );
      debugPrint("File Upload Error: $e");
      return null;
    }
  }

  // Legacy Generic upload (returns bool)
  Future<bool> _uploadMedia(String endpoint, File file, String caption,
      {Map<String, dynamic>? extraFields}) async {
    try {
      _lastUploadError = null;
      String fileName = file.path.split(Platform.pathSeparator).last;
      String? mimeType = lookupMimeType(file.path);
      MediaType? mediaType =
          mimeType != null ? MediaType.parse(mimeType) : null;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: fileName,
          contentType: mediaType,
        ),
        'caption': caption,
        ...?extraFields,
      });

      await _apiClient.client.post(endpoint, data: formData);
      return true;
    } on DioException catch (e) {
      _lastUploadError = _extractApiError(e, fallback: "فشل رفع الملف");
      debugPrint("Upload Error: $_lastUploadError");
      return false;
    } catch (e) {
      _lastUploadError = _sanitizeApiErrorText(
        e.toString(),
        fallback: _genericUploadFailureMessage,
      );
      debugPrint("Upload Error: $e");
      return false;
    }
  }

  Future<bool> uploadPhoto(File file, String caption) async {
    return _uploadMedia('/media/photo', file, caption);
  }

  Future<bool> uploadVideo(File file, String caption) async {
    return _uploadMedia('/media/video', file, caption);
  }

  Future<String?> createEvent(
      String title, String dateTime, String location, File? coverImage) async {
    _lastUploadError = null;
    try {
      String? coverImageUrl;
      if (coverImage != null) {
        coverImageUrl = await uploadFile(coverImage);
        if (coverImageUrl == null) {
          return _lastUploadError ?? 'فشل رفع الوسائط';
        }
      }

      await _apiClient.client.post('/events', data: {
        'title': title,
        'dateTime': dateTime,
        'location': location,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      });
      return null;
    } on DioException catch (e) {
      return _extractApiError(e, fallback: "فشل إنشاء الفعالية");
    } catch (e) {
      debugPrint("Event Creation Error: $e");
      return e.toString();
    }
  }

  // Offer creation (Client required logic for this specifically)
  Future<String?> createOffer(
    String title,
    String description,
    double price,
    List<File> images,
    File? video, {
    int? discountPercent,
    double? originalPrice,
  }) async {
    _lastUploadError = null;

    if (images.length > 3) {
      return "يمكنك رفع 3 صور كحد أقصى";
    }
    final mediaItems = <Map<String, dynamic>>[];

    for (final image in images) {
      final url = await uploadFile(image, subDir: 'offers');
      if (url == null) return _lastUploadError ?? "فشل رفع الوسائط";
      mediaItems.add({'url': url, 'type': 'image'});
    }
    if (video != null) {
      final url = await uploadFile(video, subDir: 'offers');
      if (url == null) return _lastUploadError ?? "فشل رفع الوسائط";
      mediaItems.add({'url': url, 'type': 'video'});
    }

    final imageUrl = mediaItems
        .firstWhere((e) => e['type'] == 'image', orElse: () => {})['url']
        ?.toString();

    try {
      await _apiClient.client.post('/offers', data: {
        'title': title,
        'description': description,
        'priceIqd': price > 0 ? price : 0.0,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (mediaItems.isNotEmpty) 'mediaItems': mediaItems,
        if (discountPercent != null) 'discountPercent': discountPercent,
        if (originalPrice != null) 'originalPriceIqd': originalPrice,
      });
      return null; // Success
    } on DioException catch (e) {
      return _extractApiError(e, fallback: "فشل إنشاء العرض");
    } catch (e) {
      return "Offer creation error: $e";
    }
  }

  // --- FETCH METHODS ---

  Future<String?> fetchHomeLogoUrl({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedHomeLogoFetchedAt != null &&
        now.difference(_cachedHomeLogoFetchedAt!) <
            const Duration(seconds: 30)) {
      return _cachedHomeLogoUrl;
    }

    try {
      final res = await _apiClient.client.get('/config/public');
      String? logoUrl;
      if (res.data is Map) {
        final map = res.data as Map;
        final rawLogo = map['homeLogoUrl'];
        if (rawLogo is String && rawLogo.trim().isNotEmpty) {
          logoUrl = _normalizePublicUrl(rawLogo.trim());
        }
      }
      _cachedHomeLogoUrl = logoUrl;
      _cachedHomeLogoFetchedAt = now;
      return _cachedHomeLogoUrl;
    } catch (e) {
      debugPrint("Fetch Home Logo Error: $e");
      return _cachedHomeLogoUrl;
    }
  }

  Future<List<dynamic>> fetchCategories() async {
    try {
      final res = await _apiClient.client.get('/categories');
      return res.data as List<dynamic>;
    } catch (e) {
      debugPrint("Fetch Categories Error: $e");
      return [];
    }
  }

  Future<BannerAd?> fetchActiveBanner() async {
    try {
      final res = await _apiClient.client.get('/banners');
      if (res.data != null && res.data != "") {
        return BannerAd.fromJson(res.data);
      }
      return null;
    } catch (e) {
      debugPrint("Fetch Banner Error: $e");
      return null;
    }
  }

  Future<List<dynamic>> fetchOffers([String? creatorId]) async {
    try {
      final query = creatorId != null ? {'creatorId': creatorId} : null;
      final res =
          await _apiClient.client.get('/offers', queryParameters: query);
      return res.data as List<dynamic>;
    } catch (e) {
      debugPrint("Fetch Offers Error in MediaService: $e");
      return [];
    }
  }

  Future<List<dynamic>> fetchPopularOffers({int limit = 6}) async {
    try {
      final res = await _apiClient.client.get('/offers', queryParameters: {
        'sort': 'popular',
        'limit': limit.toString(),
      });
      return res.data as List<dynamic>;
    } catch (e) {
      debugPrint("Fetch Popular Offers Error: $e");
      return [];
    }
  }

  Future<bool> toggleOfferLike(String offerId) async {
    try {
      final res = await _apiClient.client.post('/offers/$offerId/like');
      return res.data['liked'] as bool;
    } catch (e) {
      debugPrint("Toggle Offer Like Error: $e");
      return false;
    }
  }

  Future<List<dynamic>> fetchDiscountOffers({int limit = 6}) async {
    try {
      final res = await _apiClient.client.get('/offers', queryParameters: {
        'filter': 'discount',
        'limit': limit.toString(),
      });
      return res.data as List<dynamic>;
    } catch (e) {
      debugPrint("Fetch Discount Offers Error: $e");
      return [];
    }
  }

  Future<List<dynamic>> fetchNonDiscountOffers() async {
    try {
      final res = await _apiClient.client.get('/offers', queryParameters: {
        'filter': 'no_discount',
      });
      return res.data as List<dynamic>;
    } catch (e) {
      debugPrint("Fetch Non-Discount Offers Error: $e");
      return [];
    }
  }

  Future<List<dynamic>> fetchPhotos(String creatorId) async {
    try {
      final res = await _apiClient.client
          .get('/media/photo', queryParameters: {'creatorId': creatorId});
      return res.data as List<dynamic>;
    } catch (e) {
      debugPrint("Fetch Photos Error: $e");
      return [];
    }
  }

  Future<List<dynamic>> fetchVideos(String creatorId) async {
    try {
      final res = await _apiClient.client
          .get('/media/video', queryParameters: {'creatorId': creatorId});
      return res.data as List<dynamic>;
    } catch (e) {
      debugPrint("Fetch Videos Error: $e");
      return [];
    }
  }

  Future<List<dynamic>> fetchEvents(String creatorId) async {
    try {
      final res = await _apiClient.client
          .get('/events', queryParameters: {'creatorId': creatorId});
      return res.data as List<dynamic>;
    } catch (e) {
      debugPrint("Fetch Events Error: $e");
      return [];
    }
  }

  Future<void> reportMedia({
    required String mediaId,
    required String reason,
    String details = '',
  }) async {
    try {
      await _apiClient.client.post('/media/report', data: {
        'mediaId': mediaId,
        'reason': reason,
        'details': details,
      });
    } on DioException catch (e) {
      String message = 'Report failed';
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        message = data['error'].toString();
      } else if (data is String && data.trim().isNotEmpty) {
        message = data;
      } else if (e.message != null) {
        message = e.message!;
      }
      throw Exception(message);
    }
  }

  // --- DELETE METHODS (Using POST fallback for IIS) ---

  Future<bool> deleteOffer(String id) async {
    try {
      // Primary path: proper HTTP DELETE
      await _apiClient.client.delete('/offers', queryParameters: {'id': id});
      return true;
    } on DioException {
      // Fallback path for IIS method-handling edge cases
      try {
        await _apiClient.client.post(
          '/offers',
          queryParameters: {'id': id, '_method': 'DELETE'},
        );
        return true;
      } on DioException catch (e) {
        String? msg;
        if (e.response?.data is Map) {
          msg = e.response?.data['error']?.toString();
        } else if (e.response?.data is String) {
          final raw = (e.response?.data as String).trimLeft();
          if (raw.startsWith('<!DOCTYPE') || raw.startsWith('<html')) {
            msg = 'Server error while deleting offer';
          } else {
            msg = e.response?.data;
          }
        }
        msg ??= e.message;
        debugPrint("Delete Offer Error: $msg (Data: ${e.response?.data})");
        throw Exception("Offer Delete Error: $msg");
      }
    } catch (e) {
      throw Exception("Delete Offer failed: $e");
    }
  }

  Future<bool> deleteEvent(String id) async {
    try {
      await _apiClient.client.delete('/events', queryParameters: {'id': id});
      return true;
    } on DioException {
      try {
        await _apiClient.client.post('/events',
            queryParameters: {'id': id, '_method': 'DELETE'}, data: {'id': id});
        return true;
      } on DioException catch (e) {
        String? msg;
        if (e.response?.data is Map) {
          msg = e.response?.data['error']?.toString();
        } else if (e.response?.data is String) {
          msg = e.response?.data;
        }
        msg ??= e.message;
        debugPrint("Delete Event Error: $msg (Data: ${e.response?.data})");
        throw Exception("Event Delete Error: $msg");
      }
    } catch (e) {
      throw Exception("Delete Event failed: $e");
    }
  }

  Future<bool> deletePhoto(String id) async {
    try {
      await _apiClient.client
          .delete('/media/photo', queryParameters: {'id': id});
      return true;
    } on DioException {
      try {
        await _apiClient.client.post('/media/photo',
            queryParameters: {'id': id, '_method': 'DELETE'}, data: {'id': id});
        return true;
      } on DioException catch (e) {
        String? msg;
        if (e.response?.data is Map) {
          msg = e.response?.data['error']?.toString();
        } else if (e.response?.data is String) {
          msg = e.response?.data;
        }
        msg ??= e.message;
        debugPrint("Delete Photo Error: $msg (Data: ${e.response?.data})");
        throw Exception("Photo Delete Error: $msg");
      }
    } catch (e) {
      throw Exception("Delete Photo failed: $e");
    }
  }

  Future<bool> deleteVideo(String id) async {
    try {
      await _apiClient.client
          .delete('/media/video', queryParameters: {'id': id});
      return true;
    } on DioException {
      try {
        await _apiClient.client.post('/media/video',
            queryParameters: {'id': id, '_method': 'DELETE'}, data: {'id': id});
        return true;
      } on DioException catch (e) {
        String? msg;
        if (e.response?.data is Map) {
          msg = e.response?.data['error']?.toString();
        } else if (e.response?.data is String) {
          msg = e.response?.data;
        }
        msg ??= e.message;
        debugPrint("Delete Video Error: $msg (Data: ${e.response?.data})");
        throw Exception("Video Delete Error: $msg");
      }
    } catch (e) {
      throw Exception("Delete Video failed: $e");
    }
  }

  // --- UPDATE METHODS (Using POST fallback for IIS) ---

  Future<String?> updateOffer({
    required String id,
    String? title,
    String? description,
    double? price,
    List<File>? images,
    File? video,
    int? discountPercent,
    double? originalPrice,
  }) async {
    _lastUploadError = null;
    List<Map<String, dynamic>>? mediaItems;
    String? imageUrl;
    if (images != null || video != null) {
      if ((images?.length ?? 0) > 3) {
        return "يمكنك رفع 3 صور كحد أقصى";
      }
      mediaItems = <Map<String, dynamic>>[];
      for (final image in images ?? const <File>[]) {
        final url = await uploadFile(image, subDir: 'offers');
        if (url == null) return _lastUploadError ?? "فشل رفع الوسائط";
        mediaItems.add({'url': url, 'type': 'image'});
      }
      if (video != null) {
        final url = await uploadFile(video, subDir: 'offers');
        if (url == null) return _lastUploadError ?? "فشل رفع الوسائط";
        mediaItems.add({'url': url, 'type': 'video'});
      }
      imageUrl = mediaItems
          .firstWhere((e) => e['type'] == 'image', orElse: () => {})['url']
          ?.toString();
    }

    try {
      await _apiClient.client.patch('/offers', data: {
        'id': id,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (price != null) 'priceIqd': price,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (mediaItems != null) 'mediaItems': mediaItems,
        if (discountPercent != null) 'discountPercent': discountPercent,
        if (originalPrice != null) 'originalPriceIqd': originalPrice,
      });
      return null; // Success
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        return _extractApiError(e, fallback: "فشل تحديث العرض");
      }
      try {
        await _apiClient.client.post('/offers', queryParameters: {
          '_method': 'PATCH'
        }, data: {
          'id': id,
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (price != null) 'priceIqd': price,
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (mediaItems != null) 'mediaItems': mediaItems,
          if (discountPercent != null) 'discountPercent': discountPercent,
          if (originalPrice != null) 'originalPriceIqd': originalPrice,
        });
        return null;
      } on DioException catch (fallbackError) {
        final message =
            _extractApiError(fallbackError, fallback: "فشل تحديث العرض");
        debugPrint("Update Offer Error: $message");
        return message;
      } catch (fallbackError) {
        debugPrint("Update Offer Error: $fallbackError");
        return fallbackError.toString();
      }
    } catch (e) {
      debugPrint("Update Offer Error: $e");
      return e.toString();
    }
  }
}
