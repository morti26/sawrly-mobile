import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fotgraf_mobile/models/offer.dart';
import 'package:video_player/video_player.dart';
import '../../core/design/design_tokens.dart';
import '../../core/services/media_service.dart';
import '../../core/services/cart_service.dart';
import '../navigation/main_navigation.dart';

class OfferDetailsScreen extends StatefulWidget {
  final Offer offer;

  const OfferDetailsScreen({super.key, required this.offer});

  @override
  State<OfferDetailsScreen> createState() => _OfferDetailsScreenState();
}

class _OfferDetailsScreenState extends State<OfferDetailsScreen> {
  VideoPlayerController? _videoController;
  Future<void>? _videoInitFuture;
  Future<List<dynamic>>? _availabilityFuture;
  late final List<OfferMediaItem> _mediaItems;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.offer.mediaItems.isNotEmpty) {
      _mediaItems = widget.offer.mediaItems;
    } else if (widget.offer.imageUrl.trim().isNotEmpty) {
      final url = widget.offer.imageUrl.trim();
      _mediaItems = [
        OfferMediaItem(url: url, type: _isVideoUrl(url) ? 'video' : 'image'),
      ];
    } else {
      _mediaItems = const [];
    }
    if (widget.offer.creatorId.trim().isNotEmpty) {
      _availabilityFuture =
          context.read<MediaService>().fetchEvents(widget.offer.creatorId);
    }
    _setActiveMedia(0);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _setActiveMedia(int index) {
    if (_mediaItems.isEmpty) {
      setState(() {
        _activeIndex = 0;
      });
      return;
    }

    final boundedIndex = index.clamp(0, _mediaItems.length - 1);
    final rawUrl = _mediaItems[boundedIndex].url;
    final url = _normalizeMediaUrl(rawUrl);
    final isVideo =
        _isVideoUrl(url) || _mediaItems[boundedIndex].type == 'video';

    _videoController?.dispose();
    _videoController = null;
    _videoInitFuture = null;

    setState(() {
      _activeIndex = boundedIndex;
    });

    if (isVideo && url.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
        ..setLooping(true);
      _videoInitFuture = _videoController!.initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.play();
        }
      });
    }
  }

  String _normalizeMediaUrl(String raw) {
    if (raw.trim().isEmpty) return '';
    String url = raw.trim();
    if (url.startsWith('/')) {
      url = 'https://sawrly.com$url';
    } else if (url.startsWith('http://10.0.2.2:') ||
        url.startsWith('http://localhost:')) {
      url = url.replaceFirst(
          RegExp(r'http://(10\.0\.2\.2|localhost):\d+'), 'https://sawrly.com');
    } else if (url.startsWith('http://sawrly.com')) {
      url = url.replaceFirst('http://', 'https://');
    }

    try {
      Uri.parse(url);
      return url;
    } catch (_) {
      return Uri.encodeFull(url);
    }
  }

  bool _isVideoUrl(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase();
    if (lower.contains('/videos/')) return true;
    final videoExt = ['.mp4', '.mov', '.webm', '.mkv', '.m3u8'];
    return videoExt
        .any((ext) => lower.contains('$ext?') || lower.endsWith(ext));
  }

  DateTime? _parseEventDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String? _statusForDay(DateTime day, List<dynamic> events) {
    bool hasBusy = false;
    for (final raw in events) {
      if (raw is! Map) continue;
      final eventDate = _parseEventDate(raw['date_time']);
      if (eventDate == null || !_isSameDay(eventDate, day)) continue;

      final status = raw['calendar_status']?.toString().toLowerCase();
      if (status == 'booked') return 'booked';
      if (status == 'busy') hasBusy = true;
    }
    return hasBusy ? 'busy' : null;
  }

  String _weekdayLabel(DateTime day) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[day.weekday - 1];
  }

  String _dateLabel(DateTime day) {
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '$date/$month';
  }

  String _availabilityLabel(String? status) {
    if (status == 'booked') return 'محجوز';
    if (status == 'busy') return 'مشغول';
    return 'متاح';
  }

  Color _availabilityColor(String? status) {
    if (status == 'booked') return AppColors.accentPink;
    if (status == 'busy') return AppColors.warning;
    return AppColors.success;
  }

  Color _availabilityBackground(String? status) {
    if (status == 'booked') return AppColors.errorBg;
    if (status == 'busy') return AppColors.warningBg;
    return AppColors.successBg;
  }

  Widget _buildAvailabilityCard(DateTime day, String? status) {
    final color = _availabilityColor(status);
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _weekdayLabel(day),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _dateLabel(day),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _availabilityBackground(status),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              _availabilityLabel(status),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    if (_availabilityFuture == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<dynamic>>(
      future: _availabilityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.borderLight,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final events = snapshot.data ?? const [];
        final start = DateTime.now();
        final days = List.generate(
          7,
          (index) => DateTime(start.year, start.month, start.day + index),
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'التوفر القادم',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'الأيام غير المحددة في الجدول تظهر كمتاحة للحجز.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < days.length; i++) ...[
                      _buildAvailabilityCard(
                        days[i],
                        _statusForDay(days[i], events),
                      ),
                      if (i != days.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaFor(int index) {
    if (_mediaItems.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, size: 48),
      );
    }

    final item = _mediaItems[index];
    final url = _normalizeMediaUrl(item.url);
    final isVideo = item.type == 'video' || _isVideoUrl(url);

    if (url.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, size: 48),
      );
    }

    if (isVideo) {
      if (index != _activeIndex) {
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          child:
              const Icon(Icons.videocam_rounded, color: Colors.white, size: 56),
        );
      }
      return FutureBuilder<void>(
        future: _videoInitFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              _videoController == null ||
              !_videoController!.value.isInitialized) {
            return Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.white),
            );
          }
          return FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          );
        },
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported, size: 48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final isInCart = cart.contains(widget.offer.id);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل العرض'),
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: _mediaItems.length <= 1
                  ? _buildMediaFor(_activeIndex)
                  : PageView.builder(
                      itemCount: _mediaItems.length,
                      onPageChanged: _setActiveMedia,
                      itemBuilder: (_, index) => _buildMediaFor(index),
                    ),
            ),
            if (_mediaItems.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _mediaItems.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: index == _activeIndex ? 18 : 7,
                      height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: index == _activeIndex
                            ? const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: AppColors.accentGradient,
                              )
                            : null,
                        color: index == _activeIndex
                            ? null
                            : Colors.white.withValues(alpha: 0.18),
                        boxShadow: index == _activeIndex
                            ? AppShadows.glowAccent
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.offer.title,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.offer.price.toStringAsFixed(0)} IQD',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.offer.displayDescription.isEmpty
                        ? 'لا يوجد وصف متاح.'
                        : widget.offer.displayDescription,
                    style: const TextStyle(fontSize: 15, height: 1.6),
                  ),
                  if (_availabilityFuture != null) ...[
                    const SizedBox(height: 20),
                    _buildAvailabilitySection(),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: AppColors.accentGradient,
                        ),
                        boxShadow: AppShadows.glowAccent,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            if (isInCart) {
                              cart.remove(widget.offer.id);
                            } else {
                              cart.add(widget.offer);
                            }

                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const MainNavigation(
                                  initialIndex: 3,
                                ),
                              ),
                              (route) => false,
                            );
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isInCart
                                    ? Icons.remove_shopping_cart
                                    : Icons.add_shopping_cart,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isInCart ? 'إزالة من الطلب' : 'إضافة إلى الطلب',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
