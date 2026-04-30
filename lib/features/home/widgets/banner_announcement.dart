import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../../../models/banner_ad.dart';

class BannerAnnouncement extends StatefulWidget {
  final BannerAd? banner;

  const BannerAnnouncement({super.key, this.banner});

  @override
  State<BannerAnnouncement> createState() => _BannerAnnouncementState();
}

class _BannerAnnouncementState extends State<BannerAnnouncement> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _autoScrollTimer;
  final Random _random = Random();
  List<BannerSlide> _slides = [];

  // Map of slide-index → VideoPlayerController (only for video slides)
  final Map<int, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _setRandomSlides(widget.banner);
    _initVideoControllers();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant BannerAnnouncement oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banner != widget.banner) {
      _disposeVideoControllers();
      _currentPage = 0;
      _setRandomSlides(widget.banner);
      _initVideoControllers();
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      // Restart auto-scroll with updated slides
      _autoScrollTimer?.cancel();
      _startAutoScroll();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    _disposeVideoControllers();
    super.dispose();
  }

  void _setRandomSlides(BannerAd? banner) {
    _slides = List<BannerSlide>.from(banner?.slides ?? []);
    if (_slides.length > 1) {
      _slides.shuffle(_random);
    }
  }

  void _disposeVideoControllers() {
    for (final c in _videoControllers.values) {
      c.dispose();
    }
    _videoControllers.clear();
  }

  void _initVideoControllers() {
    for (int i = 0; i < _slides.length; i++) {
      if (_slides[i].isVideo) {
        final url = _normalizeUrl(_slides[i].url);
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));
        _videoControllers[i] = controller;
        controller.initialize().then((_) {
          if (mounted) setState(() {});
          if (_currentPage == i) {
            controller.play();
            controller.setLooping(true);
          }
        });
      }
    }
  }

  void _startAutoScroll() {
    if (_slides.length <= 1) return;

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final nextPage = (_currentPage + 1) % _slides.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);

    // Pause all videos, play the current one
    _videoControllers.forEach((i, c) {
      if (i == index) {
        c.play();
        c.setLooping(true);
      } else {
        c.pause();
        c.seekTo(Duration.zero);
      }
    });
  }

  String _normalizeUrl(String url) {
    if (url.startsWith('/')) return 'https://sawrly.com$url';
    if (url.startsWith('http://10.0.2.2:3000')) {
      return url.replaceFirst('http://10.0.2.2:3000', 'https://sawrly.com');
    }
    if (url.startsWith('http://localhost:3000')) {
      return url.replaceFirst('http://localhost:3000', 'https://sawrly.com');
    }
    if (url.startsWith('http://sawrly.com')) {
      return url.replaceFirst('http://', 'https://');
    }
    if (url.startsWith('http://ph.sitely24.com')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  Future<void> _launchUrl() async {
    if (_slides.isEmpty || _currentPage >= _slides.length) return;
    final link = _slides[_currentPage].linkUrl;
    if (link == null || link.isEmpty) return;
    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bannerHeight = (screenWidth * 0.42).clamp(120.0, 170.0).toDouble();

    // Fallback: no banner data
    if (_slides.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          height: bannerHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            image: const DecorationImage(
              image: NetworkImage('https://picsum.photos/600/300?blur=2'),
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: _launchUrl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: double.infinity,
            height: bannerHeight,
            child: Stack(
              children: [
                // ── Slides ──
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    return _buildSlide(_slides[index], index, bannerHeight);
                  },
                ),

                // ── Dot indicators (only when >1 slide) ──
                if (_slides.length > 1)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final isActive = i == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: isActive ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFFBC83FF)
                                : Colors.white.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ),

                // ── Title overlay (per slide) ──
                if (_slides.isNotEmpty &&
                    _slides[_currentPage].title != null &&
                    _slides[_currentPage].title!.isNotEmpty)
                  Positioned(
                    bottom: _slides.length > 1 ? 22 : 10,
                    left: 10,
                    right: 10,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _slides[_currentPage].title!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlide(BannerSlide slide, int index, double height) {
    if (slide.isVideo) {
      final controller = _videoControllers[index];
      if (controller != null && controller.value.isInitialized) {
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        );
      }
      // Video loading spinner
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Image slide
    final url = _normalizeUrl(slide.url);
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: height,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade300,
        child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
      ),
    );
  }
}
