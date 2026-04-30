import 'dart:io';
import 'package:fotgraf_mobile/features/home/see_all_screen.dart'; // Import SeeAllScreen
import 'package:flutter/material.dart';
import 'widgets/home_header.dart';
import 'widgets/creator_status_row.dart';
import 'widgets/banner_announcement.dart';
import 'widgets/offer_section_view.dart';
import 'package:provider/provider.dart';
import 'package:fotgraf_mobile/models/creator_status.dart';
import 'package:fotgraf_mobile/models/offer.dart';
import 'package:fotgraf_mobile/models/banner_ad.dart';
import 'package:dio/dio.dart';
import '../../core/services/status_service.dart';
import '../../core/services/media_service.dart';
import '../../core/auth/auth_service.dart';
import 'widgets/status_viewer.dart';
import 'package:image_picker/image_picker.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Offer> _allOffers = [];
  List<Offer> _popularOffers = [];
  List<Offer> _discountOffers = [];
  bool _isLoadingOffers = true;
  BannerAd? _activeBanner;
  int _lastStoryDbgCount = -1;
  static const String _tooLargeUploadMessage =
      'حجم الملف كبير جداً. يرجى اختيار ملف أصغر.';

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

  String _sanitizePublishErrorText(String text, {required String fallback}) {
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

  String _extractPublishError(Object error, {required String fallback}) {
    if (error is DioException) {
      if (error.response?.statusCode == 413) {
        return _tooLargeUploadMessage;
      }

      final data = error.response?.data;
      if (data is Map) {
        final err = data['error']?.toString();
        final frozenUntil = data['frozenUntil']?.toString();
        final isFrozen =
            (frozenUntil != null && frozenUntil.trim().isNotEmpty) ||
                ((err ?? '').contains('تجميد'));
        if (isFrozen) {
          return _buildFrozenMessage(frozenUntil);
        }
        if (err != null && err.trim().isNotEmpty) {
          return _sanitizePublishErrorText(err, fallback: fallback);
        }
      } else if (data is String && data.trim().isNotEmpty) {
        return _sanitizePublishErrorText(data, fallback: fallback);
      }

      final message = error.message;
      if (message != null && message.trim().isNotEmpty) {
        return _sanitizePublishErrorText(message, fallback: fallback);
      }

      return fallback;
    }

    var text = error.toString();
    if (text.startsWith('Exception: ')) {
      text = text.substring('Exception: '.length);
    }
    return _sanitizePublishErrorText(text, fallback: fallback);
  }

  @override
  void initState() {
    super.initState();
    // Fetch statuses and offers
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<StatusService>().fetchStatuses();
      _fetchBanner();
      _fetchOffers();
      _fetchPopularOffers();
      _fetchDiscountOffers();
    });
  }

  Future<void> _fetchPopularOffers() async {
    final rawData =
        await context.read<MediaService>().fetchPopularOffers(limit: 6);
    if (!mounted) {
      return;
    }
    setState(() {
      _popularOffers = rawData
          .map((e) {
            try {
              final offer = Offer.fromJson(e);
              String img = offer.imageUrl.trim();
              if (img.startsWith('/')) {
                img = 'https://sawrly.com$img';
              } else if (img.startsWith('http://sawrly.com')) {
                img = img.replaceFirst('http://', 'https://');
              } else if (img.startsWith('http://ph.sitely24.com')) {
                img = img.replaceFirst(
                    'http://ph.sitely24.com', 'https://sawrly.com');
              } else if (img.isEmpty) {
                img = 'https://via.placeholder.com/300';
              }
              return Offer(
                id: offer.id,
                title: offer.title,
                description: offer.description,
                price: offer.price,
                imageUrl: img,
                isPopular: true,
                hasDiscount: offer.hasDiscount,
                discountPercent: offer.discountPercent,
                originalPrice: offer.originalPrice,
                likeCount: offer.likeCount,
                orderCount: offer.orderCount,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<Offer>()
          .toList();
    });
  }

  Future<void> _fetchDiscountOffers() async {
    final rawData =
        await context.read<MediaService>().fetchDiscountOffers(limit: 6);
    if (!mounted) {
      return;
    }
    setState(() {
      _discountOffers = rawData
          .map((e) {
            try {
              final offer = Offer.fromJson(e);
              String img = offer.imageUrl.trim();
              if (img.startsWith('/')) {
                img = 'https://sawrly.com$img';
              } else if (img.startsWith('http://sawrly.com')) {
                img = img.replaceFirst('http://', 'https://');
              } else if (img.startsWith('http://ph.sitely24.com')) {
                img = img.replaceFirst(
                    'http://ph.sitely24.com', 'https://sawrly.com');
              } else if (img.isEmpty) {
                img = 'https://via.placeholder.com/300';
              }
              return Offer(
                id: offer.id,
                title: offer.title,
                description: offer.description,
                price: offer.price,
                imageUrl: img,
                hasDiscount: offer.hasDiscount,
                discountPercent: offer.discountPercent,
                originalPrice: offer.originalPrice,
                likeCount: offer.likeCount,
                orderCount: offer.orderCount,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<Offer>()
          .toList();
    });
  }

  Future<void> _fetchBanner() async {
    final banner = await context.read<MediaService>().fetchActiveBanner();
    if (mounted) setState(() => _activeBanner = banner);
  }

  Future<void> _fetchOffers() async {
    try {
      debugPrint("Starting _fetchOffers...");
      final rawData = await context
          .read<MediaService>()
          .fetchNonDiscountOffers(); // Only non-discount offers
      debugPrint("Raw offers data received: ${rawData.length} items");

      if (!mounted) {
        return;
      }

      setState(() {
        _allOffers = rawData
            .map((e) {
              try {
                final offer = Offer.fromJson(e);
                // Normalize media URL for real mobile devices
                String img = offer.imageUrl.trim();
                if (img.startsWith("/")) {
                  img = "https://sawrly.com$img";
                } else if (img.startsWith("http://10.0.2.2:3000")) {
                  img = img.replaceFirst(
                      "http://10.0.2.2:3000", "https://sawrly.com");
                } else if (img.startsWith("http://localhost:3000")) {
                  img = img.replaceFirst(
                      "http://localhost:3000", "https://sawrly.com");
                } else if (img.startsWith("http://ph.sitely24.com")) {
                  img = img.replaceFirst(
                      "http://ph.sitely24.com", "https://sawrly.com");
                } else if (img.startsWith("http://sawrly.com")) {
                  img = img.replaceFirst("http://", "https://");
                } else if (img.isEmpty) {
                  img = "https://via.placeholder.com/300";
                }
                return Offer(
                  id: offer.id,
                  title: offer.title,
                  description: offer.description,
                  price: offer.price,
                  imageUrl: img,
                  isPopular: offer.isPopular,
                  hasDiscount: offer.hasDiscount,
                  discountPercent: offer.discountPercent,
                  originalPrice: offer.originalPrice,
                  likeCount: offer.likeCount,
                  orderCount: offer.orderCount,
                );
              } catch (parseError) {
                debugPrint("Error parsing offer: $parseError");
                debugPrint("Problematic data: $e");
                return Offer(
                    id: "error",
                    title: "Error",
                    description: "Parse Error",
                    price: 0,
                    imageUrl: "",
                    isPopular: false);
              }
            })
            .where((o) => o.id != "error")
            .toList();

        debugPrint("Final processed offers: ${_allOffers.length}");
        _isLoadingOffers = false;
      });
    } catch (e) {
      debugPrint("CRITICAL ERROR loading offers: $e");
      if (mounted) {
        setState(() => _isLoadingOffers = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _pickStoryMedia() async {
    final mediaService = context.read<MediaService>();

    final selection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              "إضافة قصة جديدة",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSelectionItem(
                  context,
                  icon: Icons.camera_alt_rounded,
                  label: "التقاط صورة",
                  color: Colors.blue,
                  onTap: () => Navigator.pop(context, "camera_photo"),
                ),
                _buildSelectionItem(
                  context,
                  icon: Icons.photo_library_rounded,
                  label: "معرض الصور",
                  color: Colors.blue,
                  onTap: () => Navigator.pop(context, "gallery_photo"),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSelectionItem(
                  context,
                  icon: Icons.videocam_rounded,
                  label: "تسجيل فيديو",
                  color: Colors.red,
                  onTap: () => Navigator.pop(context, "camera_video"),
                ),
                _buildSelectionItem(
                  context,
                  icon: Icons.video_library_rounded,
                  label: "معرض الفيديو",
                  color: Colors.red,
                  onTap: () => Navigator.pop(context, "gallery_video"),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (selection == null) return null;

    File? file;
    String mediaType = "image";
    if (selection == "camera_photo") {
      file = await mediaService.pickImage(source: ImageSource.camera);
      mediaType = "image";
    } else if (selection == "gallery_photo") {
      file = await mediaService.pickImage(source: ImageSource.gallery);
      mediaType = "image";
    } else if (selection == "camera_video") {
      file = await mediaService.pickVideo(source: ImageSource.camera);
      mediaType = "video";
    } else if (selection == "gallery_video") {
      file = await mediaService.pickVideo(source: ImageSource.gallery);
      mediaType = "video";
    }

    if (file == null) return null;
    return {'file': file, 'mediaType': mediaType};
  }

  Future<void> _createStory() async {
    final authService = context.read<AuthService>();
    if (!authService.isCreator) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("نشر القصص متاح للمبدعين فقط")),
        );
      }
      return;
    }

    final mediaService = context.read<MediaService>();
    final statusService = context.read<StatusService>();
    final picked = await _pickStoryMedia();
    if (picked == null || !mounted) return;

    final File file = picked['file'] as File;
    final String mediaType = picked['mediaType'] as String;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("جاري تحميل القصة...")),
    );

    final url = await mediaService.uploadFile(file);
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mediaService.lastUploadError ?? "فشل التحميل"),
          ),
        );
      }
      return;
    }

    try {
      await statusService.postStatus(url, mediaType, "");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم إضافة القصة!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _extractPublishError(
                e,
                fallback: "فشل نشر القصة",
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _editStory(CreatorStatus story) async {
    final mediaService = context.read<MediaService>();
    final statusService = context.read<StatusService>();
    final picked = await _pickStoryMedia();
    if (picked == null || !mounted) return;

    final File file = picked['file'] as File;
    final String mediaType = picked['mediaType'] as String;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("جاري تحديث القصة...")),
    );

    final url = await mediaService.uploadFile(file);
    if (url == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mediaService.lastUploadError ?? "فشل التحميل"),
          ),
        );
      }
      return;
    }

    try {
      await statusService.updateStatus(
        id: story.id,
        mediaUrl: url,
        mediaType: mediaType,
        caption: "",
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم تحديث القصة")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _extractPublishError(
                e,
                fallback: "فشل تحديث القصة",
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteStory(CreatorStatus story) async {
    final statusService = context.read<StatusService>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("حذف القصة"),
        content: const Text("هل تريد حذف القصة الحالية؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await statusService.deleteStatus(story.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تم حذف القصة")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ: $e")),
        );
      }
    }
  }

  Future<void> _openMyStoryActions(CreatorStatus story) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text("عرض القصة"),
              onTap: () => Navigator.pop(context, 'view'),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("تعديل القصة"),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title:
                  const Text("حذف القصة", style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;

    if (action == 'view') {
      final allMyStatuses = context
          .read<StatusService>()
          .statusList
          .where((s) => s.creatorId.trim() == story.creatorId.trim())
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      showDialog(
        context: context,
        builder: (_) => StatusViewer(
          statuses: allMyStatuses.isNotEmpty ? allMyStatuses : [story],
        ),
      );
      return;
    }
    if (action == 'edit') {
      await _editStory(story);
      return;
    }
    if (action == 'delete') {
      await _deleteStory(story);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch Services
    final statusService = context.watch<StatusService>();
    final authService = context.watch<AuthService>();
    final isCreator = authService.isCreator;

    // Mock Offers removed - using _allOffers
    // final offers = [ ... ];

    final currentUser = authService.currentUser;
    final currentUserImage =
        currentUser?.avatarUrl == null || currentUser!.avatarUrl!.trim().isEmpty
            ? "https://picsum.photos/seed/avatar/200/200"
            : (currentUser.avatarUrl!.startsWith('/')
                ? "https://sawrly.com${currentUser.avatarUrl}"
                : currentUser.avatarUrl!);
    CreatorStatus? myStatus;
    final Map<String, Offer> discountOfferMap = <String, Offer>{};
    for (final offer in _discountOffers) {
      if (offer.hasDiscount) {
        discountOfferMap.putIfAbsent(offer.id, () => offer);
      }
    }
    for (final offer in _popularOffers) {
      if (offer.hasDiscount) {
        discountOfferMap.putIfAbsent(offer.id, () => offer);
      }
    }
    for (final offer in _allOffers) {
      if (offer.hasDiscount) {
        discountOfferMap.putIfAbsent(offer.id, () => offer);
      }
    }
    final effectiveDiscountOffers = discountOfferMap.values.toList();

    // Find my status if I am a creator
    String myStatusMatch = '';
    if (isCreator &&
        currentUser != null &&
        statusService.statusList.isNotEmpty) {
      final myId = currentUser.id.trim();
      for (final s in statusService.statusList) {
        if (s.creatorId.trim() == myId) {
          myStatus = s;
          myStatusMatch = 'id';
          break;
        }
      }
      if (myStatus == null) {
        final myName = currentUser.name.trim().toLowerCase();
        if (myName.isNotEmpty) {
          for (final s in statusService.statusList) {
            if (s.creatorName.trim().toLowerCase() == myName) {
              myStatus = s;
              myStatusMatch = 'name';
              break;
            }
          }
        }
      }
    }
    if (_lastStoryDbgCount != statusService.statusList.length) {
      _lastStoryDbgCount = statusService.statusList.length;
      debugPrint(
        'STORYDBG home build isCreator=$isCreator userId=${currentUser?.id ?? ''} userName=${currentUser?.name ?? ''} statuses=${statusService.statusList.length} myStatus=${myStatus?.id ?? ''} match=$myStatusMatch',
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const HomeHeader(),
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF9B59F5),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x8C7A3EED),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Color(0x339B59F5),
                        blurRadius: 32,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: SizedBox(height: 2),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await context.read<StatusService>().fetchStatuses();
                  await _fetchBanner();
                  await _fetchOffers();
                  await _fetchPopularOffers();
                  await _fetchDiscountOffers();
                },
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      if (statusService.isLoading &&
                          statusService.statusList.isEmpty)
                        const SizedBox(
                            height: 100,
                            child: Center(child: CircularProgressIndicator()))
                      else
                        CreatorStatusRow(
                          statusList: statusService.statusList,
                          showAddButton: isCreator,
                          userImage: currentUserImage,
                          myUserName: currentUser?.name,
                          myStatus: myStatus,
                          onAddPressed: isCreator ? _createStory : null,
                          onMyStoryLongPress: myStatus == null
                              ? null
                              : () => _openMyStoryActions(myStatus!),
                          onStatusPressed: (statuses) {
                            debugPrint(
                              'STORYDBG open viewer statuses=${statuses.length} first=${statuses.isNotEmpty ? statuses.first.id : ''} last=${statuses.isNotEmpty ? statuses.last.id : ''} creatorId=${statuses.isNotEmpty ? statuses.first.creatorId : ''}',
                            );
                            showDialog(
                              context: context,
                              builder: (_) => StatusViewer(
                                statuses: statuses,
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),
                      if (_activeBanner != null)
                        BannerAnnouncement(banner: _activeBanner!)
                      else
                        const BannerAnnouncement(),
                      const SizedBox(height: 24),
                      if (_isLoadingOffers)
                        const Center(
                            child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator()))
                      else
                      // All Offers
                      if (!_isLoadingOffers)
                        OfferSectionView(
                          title: 'عروض مقترحة',
                          offers: _allOffers,
                          showDiscountBadge: false,
                          onSeeAll: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SeeAllScreen(
                                  title: 'عروض مقترحة',
                                  offers: _allOffers,
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),

                      // Top Popular
                      if (!_isLoadingOffers && _popularOffers.isNotEmpty)
                        OfferSectionView(
                          title: 'الاكثر طلباً',
                          offers: _popularOffers,
                          showDiscountBadge: false,
                          onSeeAll: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SeeAllScreen(
                                  title: 'الاكثر طلباً',
                                  offers: _popularOffers,
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),
                      // Discounts
                      if (!_isLoadingOffers &&
                          effectiveDiscountOffers.isNotEmpty)
                        OfferSectionView(
                          title: 'الخصومات',
                          offers: effectiveDiscountOffers,
                          showDiscountBadge: true,
                          onSeeAll: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SeeAllScreen(
                                  title: 'الخصومات',
                                  offers: effectiveDiscountOffers,
                                ),
                              ),
                            );
                          },
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

  Widget _buildSelectionItem(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
