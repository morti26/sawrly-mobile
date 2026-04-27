import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/media_service.dart';
import '../../models/banner_ad.dart';
import '../home/widgets/home_header.dart';
import '../home/widgets/banner_announcement.dart';
import '../search/global_search_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  BannerAd? _activeBanner;
  List<dynamic> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final mediaService = context.read<MediaService>();
      final banner = await mediaService.fetchActiveBanner();
      final categories = await mediaService.fetchCategories();

      if (mounted) {
        setState(() {
          _activeBanner = banner;
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading categories screen data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _normalizeUrl(String url) {
    if (url.startsWith('/')) return 'https://ph.sitely24.com$url';
    if (url.startsWith('http://10.0.2.2:3000')) {
      return url.replaceFirst(
          'http://10.0.2.2:3000', 'https://ph.sitely24.com');
    }
    if (url.startsWith('http://localhost:3000')) {
      return url.replaceFirst(
          'http://localhost:3000', 'https://ph.sitely24.com');
    }
    if (url.startsWith('http://ph.sitely24.com')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161921),
      body: SafeArea(
        child: Column(
          children: [
            const HomeHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // Slider
                      if (_activeBanner != null)
                        BannerAnnouncement(banner: _activeBanner!)
                      else
                        const BannerAnnouncement(), // Fallback empty banner

                      const SizedBox(height: 24),

                      // Title
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            'المتجر',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Categories Grid
                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_categories.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'لا توجد عناصر في المتجر حاليا',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.1,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: _categories.length,
                            itemBuilder: (context, index) {
                              final cat = _categories[index];
                              // Skip inactive if they somehow slipped through
                              if (cat['is_active'] == false ||
                                  cat['is_active'] == 0) {
                                return const SizedBox.shrink();
                              }

                              final imageUrl =
                                  _normalizeUrl(cat['image_url'] ?? '');
                              final title = cat['title'] ?? 'بدون عنوان';

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => GlobalSearchScreen(
                                        initialQuery: title,
                                        initialTabIndex: 1,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Image
                                        Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            color: Colors.grey.shade300,
                                            child: const Icon(Icons.category,
                                                color: Colors.grey),
                                          ),
                                        ),
                                        // Gradient overly
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black
                                                    .withValues(alpha: 0.7),
                                              ],
                                              stops: const [0.4, 1.0],
                                            ),
                                          ),
                                        ),
                                        // Title
                                        Positioned(
                                          bottom: 12,
                                          left: 8,
                                          right: 8,
                                          child: Text(
                                            title,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 80), // Bottom padding
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
