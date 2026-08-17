import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fotgraf_mobile/models/offer.dart';
import 'package:video_player/video_player.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/media_service.dart';
import '../../../core/theme/app_theme_service.dart';
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
    final theme = context.watch<AppThemeService>();
    final premium = PremiumDesignTokens.from(theme.config);
    final isInCart = context
        .select<CartService, bool>((cart) => cart.contains(widget.offer.id));
    final currentUser = context.watch<AuthService>().currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final resolvedCardWidth =
        widget.cardWidth ?? (screenWidth * 0.40).clamp(130.0, 170.0).toDouble();
    final resolvedImageHeight = widget.imageHeight ??
        (resolvedCardWidth * 0.52).clamp(68.0, 90.0).toDouble();
    final description = widget.offer.displayDescription;
    final mediaUrl = _normalizeUrl(widget.offer.primaryMediaUrl);
    if (mediaUrl.isEmpty) {
      debugPrint(
          "DEBUG OfferCard [${widget.offer.id}/${widget.offer.title}] → primaryMediaUrl EMPTY! widget.offer.imageUrl='${widget.offer.imageUrl}', mediaItems.len=${widget.offer.mediaItems.length}");
    }
    final showVideoStats = widget.showEngagementStats && _isVideoUrl(mediaUrl);
    final canSave = currentUser != null &&
        currentUser.id.trim() != widget.offer.creatorId.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(premium.radiusMedium),
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
            gradient: premium.cardGradient,
            borderRadius: BorderRadius.circular(premium.radiusMedium),
            boxShadow: premium.cardShadow,
            border: Border.all(
              color: isInCart ? theme.colors.success : premium.borderSubtle,
              width: isInCart ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(premium.radiusMedium - 1),
                    ),
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
                          color: Theme.of(context).colorScheme.error,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '-${widget.offer.discountPercent}%',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onError,
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
                  padding: const EdgeInsets.fromLTRB(11, 10, 11, 8),
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
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: premium.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (widget.offer.creatorName.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              widget.offer.creatorName,
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: premium.textMuted,
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
                              style: TextStyle(
                                fontSize: 10.5,
                                height: 1.35,
                                color: premium.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                      // Price (pushed to the bottom of the card)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    '${widget.offer.price.toStringAsFixed(0)} IQD',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: premium.priceColor,
                                    ),
                                  ),
                                ),
                                if (widget.offer.hasDiscount &&
                                    widget.offer.originalPrice != null) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.offer.originalPrice!
                                        .toStringAsFixed(0),
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: premium.textMuted,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (canSave)
                            Material(
                              color: premium.surfaceElevated
                                  .withValues(alpha: .55),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: premium.borderHighlight,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: _isSaving ? null : _toggleSaved,
                                child: SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: Center(
                                    child: _isSaving
                                        ? SizedBox(
                                            width: 15,
                                            height: 15,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: premium.textPrimary,
                                            ),
                                          )
                                        : Icon(
                                            _isSaved
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            size: 20,
                                            color: _isSaved
                                                ? premium.accentPrimary
                                                : premium.textSecondary,
                                          ),
                                  ),
                                ),
                              ),
                            ),
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
    return normalizePublicMediaUrl(raw);
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
  VideoPlayerController? _videoController;
  Future<void>? _videoInitFuture;
  bool _videoReady = false;

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
    if (_isVideo && widget.mediaUrl.isNotEmpty) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    try {
      final uri = Uri.parse(widget.mediaUrl);
      _videoController = VideoPlayerController.networkUrl(uri)
        ..setLooping(true);
      _videoInitFuture = _videoController!.initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
        _videoController!.play();
        _videoController!.setVolume(0);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _OfferCardMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl) {
      _videoController?.dispose();
      _videoController = null;
      _videoInitFuture = null;
      _videoReady = false;
      if (_isVideo && widget.mediaUrl.isNotEmpty) {
        _initVideo();
      }
    }
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
      return SizedBox(
        height: widget.height,
        width: widget.width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_videoReady &&
                _videoController != null &&
                _videoController!.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else
              FutureBuilder(
                future: _videoInitFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting ||
                      !_videoReady) {
                    return _buildFallback(context, video: true);
                  }
                  return _buildFallback(context, video: true);
                },
              ),
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Color(0xCCFFFFFF),
                size: 34,
                shadows: [
                  BoxShadow(
                      color: Colors.black38, blurRadius: 6, spreadRadius: 1),
                ],
              ),
            ),
          ],
        ),
      );
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
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
            "❌ OfferCard IMAGE LOAD ERROR → URL='${widget.mediaUrl}' ERROR=$error");
        return _buildFallback(context);
      },
    );
  }
}
