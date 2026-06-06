import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fotgraf_mobile/models/offer.dart';
import 'package:video_player/video_player.dart';
import '../../core/services/cart_service.dart';
import '../navigation/main_navigation.dart';

class OfferDetailsScreen extends StatefulWidget {
  final Offer offer;

  const OfferDetailsScreen({super.key, required this.offer});

  @override
  State<OfferDetailsScreen> createState() => _OfferDetailsScreenState();
}

class _OfferDetailsScreenState extends State<OfferDetailsScreen> {
  static const Color _bg = Color(0xFF161921);
  static const Color _accentPink = Color(0xFFFF4DA6);
  static const Color _accentPurple = Color(0xFF7A3EED);

  VideoPlayerController? _videoController;
  Future<void>? _videoInitFuture;
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
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: Colors.white,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      backgroundColor: _bg,
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
                                colors: [_accentPink, _accentPurple],
                              )
                            : null,
                        color: index == _activeIndex
                            ? null
                            : Colors.white.withValues(alpha: 0.18),
                        boxShadow: index == _activeIndex
                            ? [
                                BoxShadow(
                                  color: _accentPink.withValues(alpha: 0.28),
                                  blurRadius: 14,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: _accentPurple.withValues(alpha: 0.22),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ]
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
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.offer.displayDescription.isEmpty
                        ? 'لا يوجد وصف متاح.'
                        : widget.offer.displayDescription,
                    style: const TextStyle(fontSize: 15, height: 1.6),
                  ),
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
                          colors: [_accentPink, _accentPurple],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _accentPink.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: _accentPurple.withValues(alpha: 0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 14),
                          ),
                        ],
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
