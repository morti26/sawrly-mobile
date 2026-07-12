import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fotgraf_mobile/models/offer.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/media_service.dart';
import '../offer_details_screen.dart';

class OfferCard extends StatefulWidget {
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
  State<OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<OfferCard> {
  late bool _isSaved;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.offer.likedByMe;
  }

  Future<void> _toggleSaved() async {
    final auth = context.read<AuthService>();
    final currentUser = auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجل الدخول أولاً')),
      );
      return;
    }
    if (currentUser.id.trim() == widget.offer.creatorId.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكنك حفظ عرضك الخاص')),
      );
      return;
    }
    if (_isSaving) return;

    setState(() => _isSaving = true);
    try {
      final liked =
          await context.read<MediaService>().toggleOfferLike(widget.offer.id);
      if (!mounted) return;
      setState(() {
        _isSaved = liked;
        _isSaving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحديث المحفوظات')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInCart =
        context.select<CartService, bool>((cart) => cart.contains(widget.offer.id));
    final currentUser = context.watch<AuthService>().currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final resolvedCardWidth =
        widget.cardWidth ?? (screenWidth * 0.40).clamp(130.0, 170.0).toDouble();
    final resolvedImageHeight =
        widget.imageHeight ??
            (resolvedCardWidth * 0.52).clamp(68.0, 90.0).toDouble();
    final description = widget.offer.displayDescription;
    final mediaUrl = _normalizeUrl(widget.offer.primaryMediaUrl);
    final showVideoStats =
        widget.showEngagementStats && _isVideoUrl(mediaUrl);
    final canSave = currentUser != null &&
        currentUser.id.trim() != widget.offer.creatorId.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => OfferDetailsScreen(offer: widget.offer)),
          );
        },
        child: Ink(
          width: resolvedCardWidth,
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
            border: isInCart ? Border.all(color: Colors.green, width: 2) : null,
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
                    mediaUrl: mediaUrl,
                    height: resolvedImageHeight,
                    width: resolvedCardWidth,
                  ),
                ),
                if (widget.showDiscountBadge && widget.offer.hasDiscount)
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
                        '-${widget.offer.discountPercent}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (canSave)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: const Color(0xAA10131A),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isSaving ? null : _toggleSaved,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _isSaved
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 18,
                                  color: _isSaved
                                      ? Colors.redAccent
                                      : Colors.white,
                                ),
                        ),
                      ),
                    ),
                  ),
                if (showVideoStats)
                  Positioned(
                    top: 6,
                    right: canSave ? 40 : 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMetricBadge(
                          icon: Icons.favorite_rounded,
                          value: widget.offer.likeCount,
                          iconColor: const Color(0xFFFF5C8A),
                        ),
                        const SizedBox(width: 4),
                        _buildMetricBadge(
                          icon: Icons.shopping_bag_rounded,
                          value: widget.offer.orderCount,
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
                          widget.offer.title,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.offer.creatorName.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            widget.offer.creatorName,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Colors.white60,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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
                          '${widget.offer.price.toStringAsFixed(0)} IQD',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Color(0xFFFFA726)),
                        ),
                        if (widget.offer.hasDiscount &&
                            widget.offer.originalPrice != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            widget.offer.originalPrice!.toStringAsFixed(0),
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
      ),
    );
  }

  String _normalizeUrl(String raw) {
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
    } else if (!url.startsWith('http')) {
      url = 'https://sawrly.com/$url';
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
  final double width;

  const _OfferCardMedia({
    required this.mediaUrl,
    required this.height,
    required this.width,
  });

  @override
  State<_OfferCardMedia> createState() => _OfferCardMediaState();
}

class _OfferCardMediaState extends State<_OfferCardMedia> {
  bool get _isVideo {
    final lower = widget.mediaUrl.toLowerCase();
    if (lower.isEmpty) return false;
    if (lower.contains('/videos/')) return true;
    const videoExt = ['.mp4', '.mov', '.webm', '.mkv', '.m3u8', '.m4v'];
    return videoExt
        .any((ext) => lower.contains('$ext?') || lower.endsWith(ext));
  }

  Widget _buildFallback(BuildContext context, {bool video = false}) {
    return Container(
      height: widget.height,
      width: widget.width,
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
      return _buildFallback(context, video: true);
    }

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (widget.width * dpr).round();
    final cacheHeight = (widget.height * dpr).round();

    return Image.network(
      widget.mediaUrl,
      height: widget.height,
      width: widget.width,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      errorBuilder: (context, error, stackTrace) => _buildFallback(context),
    );
  }
}
