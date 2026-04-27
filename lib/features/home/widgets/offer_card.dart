import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fotgraf_mobile/models/offer.dart';
import 'package:video_player/video_player.dart';
import '../../../core/services/cart_service.dart';
import '../offer_details_screen.dart';

class OfferCard extends StatelessWidget {
  final Offer offer;
  final double? cardWidth;
  final double? imageHeight;
  final bool showEngagementStats;
  final bool showDiscountBadge;

  const OfferCard({
    super.key,
    required this.offer,
    this.cardWidth,
    this.imageHeight,
    this.showEngagementStats = false,
    this.showDiscountBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    // Watch cart for changes to update UI state
    final cart = context.watch<CartService>();
    final isInCart = cart.contains(offer.id);
    final screenWidth = MediaQuery.of(context).size.width;
    final resolvedCardWidth =
        cardWidth ?? (screenWidth * 0.40).clamp(130.0, 170.0).toDouble();
    final resolvedImageHeight =
        imageHeight ?? (resolvedCardWidth * 0.52).clamp(68.0, 90.0).toDouble();
    final description = offer.displayDescription;
    final showVideoStats =
        showEngagementStats && _isVideoUrl(_normalizeUrl(offer.imageUrl));

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OfferDetailsScreen(offer: offer)),
        );
      },
      child: Container(
        width: resolvedCardWidth,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
          border: isInCart
              ? Border.all(color: Colors.green, width: 2)
              : null, // Visual feedback
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  child: _OfferCardMedia(
                    mediaUrl: _normalizeUrl(offer.imageUrl),
                    height: resolvedImageHeight,
                  ),
                ),
                if (showDiscountBadge && offer.hasDiscount)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-${offer.discountPercent}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (showVideoStats)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMetricBadge(
                          icon: Icons.favorite_rounded,
                          value: offer.likeCount,
                          iconColor: const Color(0xFFFF5C8A),
                        ),
                        const SizedBox(width: 4),
                        _buildMetricBadge(
                          icon: Icons.shopping_bag_rounded,
                          value: offer.orderCount,
                          iconColor: const Color(0xFFFFA726),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(7, 5, 7, 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          offer.title,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 9.5,
                              height: 1.25,
                              color: Colors.white70,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    // Price (pushed to the bottom of the card)
                    Row(
                      children: [
                        Text(
                          '${offer.price.toStringAsFixed(0)} IQD',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Color(0xFFFFA726)),
                        ),
                        if (offer.hasDiscount &&
                            offer.originalPrice != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            offer.originalPrice!.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _normalizeUrl(String raw) {
    if (raw.trim().isEmpty) return '';
    String url = raw.trim();
    if (url.startsWith('/')) {
      url = 'https://ph.sitely24.com$url';
    } else if (url.startsWith('http://10.0.2.2:') ||
        url.startsWith('http://localhost:')) {
      url = url.replaceFirst(RegExp(r'http://(10\.0\.2\.2|localhost):\d+'),
          'https://ph.sitely24.com');
    } else if (url.startsWith('http://ph.sitely24.com')) {
      url = url.replaceFirst('http://', 'https://');
    } else if (!url.startsWith('http')) {
      url = 'https://ph.sitely24.com/$url';
    }

    // Check if the URL needs encoding (e.g. contains unescaped spaces)
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
    const videoExt = ['.mp4', '.mov', '.webm', '.mkv', '.m3u8', '.m4v'];
    return videoExt
        .any((ext) => lower.contains('$ext?') || lower.endsWith(ext));
  }

  Widget _buildMetricBadge({
    required IconData icon,
    required int value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xAA10131A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 11),
          const SizedBox(width: 3),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCardMedia extends StatefulWidget {
  final String mediaUrl;
  final double height;

  const _OfferCardMedia({
    required this.mediaUrl,
    required this.height,
  });

  @override
  State<_OfferCardMedia> createState() => _OfferCardMediaState();
}

class _OfferCardMediaState extends State<_OfferCardMedia> {
  VideoPlayerController? _controller;
  Future<void>? _videoFuture;

  bool get _isVideo {
    final lower = widget.mediaUrl.toLowerCase();
    if (lower.isEmpty) return false;
    if (lower.contains('/videos/')) return true;
    const videoExt = ['.mp4', '.mov', '.webm', '.mkv', '.m3u8', '.m4v'];
    return videoExt
        .any((ext) => lower.contains('$ext?') || lower.endsWith(ext));
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl))
        ..setVolume(0);
      _videoFuture = _controller!.initialize().then((_) async {
        if (!mounted) return;
        await _controller!.seekTo(Duration.zero);
        await _controller!.pause();
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _buildFallback(BuildContext context, {bool video = false}) {
    return Container(
      height: widget.height,
      width: double.infinity,
      color: const Color(0x80222530),
      child: Center(
        child: video
            ? Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.videocam_rounded,
                      color: Colors.grey.shade500, size: 24),
                  const Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white, size: 28),
                ],
              )
            : Icon(Icons.camera_alt_outlined,
                color: Colors.grey.shade600, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mediaUrl.isEmpty) {
      return _buildFallback(context);
    }

    if (_isVideo) {
      return SizedBox(
        height: widget.height,
        width: double.infinity,
        child: FutureBuilder<void>(
          future: _videoFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done ||
                _controller == null ||
                !_controller!.value.isInitialized) {
              return _buildFallback(context, video: true);
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0x88000000),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 12),
                        SizedBox(width: 2),
                        Text(
                          'فيديو',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return Image.network(
      widget.mediaUrl,
      height: widget.height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildFallback(context),
    );
  }
}
