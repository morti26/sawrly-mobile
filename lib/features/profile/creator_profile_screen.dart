import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../models/offer.dart';
import '../../models/user.dart';
import '../../core/auth/auth_service.dart';
import '../../core/design/design_tokens.dart';
import '../../core/services/media_service.dart';
import '../../core/widgets/report_dialog.dart';
import '../home/offer_details_screen.dart';
import 'edit_profile_screen.dart';
import 'create_offer_screen.dart';

class CreatorProfileScreen extends StatefulWidget {
  final User? user;

  const CreatorProfileScreen({super.key, this.user});

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoadingProfile = false;
  int _mediaReloadTick = 0;
  User? _fullProfile;
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    // Default length 4 for creators (Offers, Photo, Video, Event)
    // We will update this in build based on role, but TabController needs length.
    // For simplicity, we'll listen to the user in build and re-initialize if needed,
    // or better, just default to 4 and hide/show content.
    // Actually, checking role in initState is truncated if user loads later.
    // But verify: user is passed in constructor or provider.
    // Let's assume passed user or auth user is available.
    // We'll initialize with 0 and re-init in didChangeDependencies or build if we want dynamic.
    // Simpler: Just allow 2 tabs for clients.
    _tabController = TabController(length: 4, vsync: this);

    _loadFullProfile();
  }

  Future<void> _loadFullProfile() async {
    final user = widget.user ?? context.read<AuthService>().currentUser;
    if (user == null) return;

    setState(() => _isLoadingProfile = true);
    final fullProfile =
        await context.read<AuthService>().fetchUserProfile(user.id);
    if (fullProfile != null && mounted) {
      setState(() {
        _fullProfile = fullProfile;
        _followersCount = fullProfile.followersCount;
        _followingCount = fullProfile.followingCount;
        _isFollowing = fullProfile.isFollowing;
        _isLoadingProfile = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _toggleFollow(String targetUserId) async {
    final result = await context.read<AuthService>().toggleFollow(targetUserId);
    if (result != null && mounted) {
      setState(() {
        _isFollowing = result['is_following'];
        _followersCount = result['followers_count'];
        _followingCount = result['following_count'];
      });
    }
  }

  void _showProfileReportDialog(User user) {
    showReportDialog(
      context: context,
      title: 'الإبلاغ عن الحساب',
      onSubmit: (reason, details) {
        return context.read<MediaService>().reportContent(
              targetType: 'profile',
              targetId: user.id,
              reason: reason,
              details: details,
            );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = context.read<AuthService>();
    final user = widget.user ?? authService.currentUser;
    // Client has 2 tabs, Creator 4
    final length = (user?.role == UserRole.client) ? 2 : 4;
    if (_tabController.length != length) {
      _tabController.dispose();
      // creator has 4 tabs, client has 2
      final newLength = (user?.role == UserRole.client) ? 2 : 4;
      _tabController = TabController(length: newLength, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleUpload() {
    // ... (Existing upload logic) ...
    final screenContext = context;
    final messenger = ScaffoldMessenger.of(screenContext);

    showModalBottomSheet(
      context: screenContext,
      isScrollControlled: true,
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewPadding.bottom;
        return SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("رفع محتوى",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.local_offer, color: Colors.green),
                  title: const Text("إنشاء عرض"),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      screenContext,
                      MaterialPageRoute(
                          builder: (context) => const CreateOfferScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.blue),
                  title: const Text("رفع صورة"),
                  onTap: () async {
                    Navigator.pop(context);
                    final mediaService = screenContext.read<MediaService>();
                    final file = await mediaService.pickImage();
                    if (file != null) {
                      // Show caption dialog
                      String caption = "";
                      if (!screenContext.mounted) return;
                      await showDialog(
                          context: screenContext,
                          builder: (context) => AlertDialog(
                                title: const Text("إضافة وصف"),
                                content: TextField(
                                  decoration: const InputDecoration(
                                      hintText: "أدخل الوصف..."),
                                  onChanged: (val) => caption = val,
                                ),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("موافق"))
                                ],
                              ));

                      final success =
                          await mediaService.uploadPhoto(file, caption);
                      if (success && mounted) {
                        setState(() {
                          _mediaReloadTick++;
                        });
                        _tabController.animateTo(1);
                        messenger
                          ..clearSnackBars()
                          ..showSnackBar(
                              const SnackBar(content: Text("تم رفع الصورة!")));
                      } else if (mounted) {
                        messenger
                          ..clearSnackBars()
                          ..showSnackBar(SnackBar(
                              content: Text(mediaService.lastUploadError ??
                                  "فشل رفع الصورة")));
                      }
                    } else if (mounted) {
                      messenger
                        ..clearSnackBars()
                        ..showSnackBar(const SnackBar(
                            content: Text("لم يتم اختيار صورة")));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.red),
                  title: const Text("رفع فيديو"),
                  onTap: () async {
                    Navigator.pop(context);
                    final mediaService = screenContext.read<MediaService>();
                    final file = await mediaService.pickVideo();
                    if (file != null) {
                      String caption = "";
                      if (!screenContext.mounted) return;
                      await showDialog(
                          context: screenContext,
                          builder: (context) => AlertDialog(
                                title: const Text("إضافة وصف"),
                                content: TextField(
                                  decoration: const InputDecoration(
                                      hintText: "أدخل الوصف..."),
                                  onChanged: (val) => caption = val,
                                ),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("موافق"))
                                ],
                              ));

                      final success =
                          await mediaService.uploadVideo(file, caption);
                      if (success && mounted) {
                        setState(() {
                          _mediaReloadTick++;
                        });
                        _tabController.animateTo(2);
                        messenger
                          ..clearSnackBars()
                          ..showSnackBar(
                              const SnackBar(content: Text("تم رفع الفيديو!")));
                      } else if (mounted) {
                        messenger
                          ..clearSnackBars()
                          ..showSnackBar(SnackBar(
                              content: Text(mediaService.lastUploadError ??
                                  "فشل رفع الفيديو")));
                      }
                    } else if (mounted) {
                      messenger
                        ..clearSnackBars()
                        ..showSnackBar(const SnackBar(
                            content: Text("لم يتم اختيار فيديو")));
                    }
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.calendar_month, color: Colors.purple),
                  title: const Text("إضافة إلى الجدول"),
                  onTap: () async {
                    Navigator.pop(context);
                    await _openCalendarScreen();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCalendarScreen() async {
    final user = widget.user ?? context.read<AuthService>().currentUser;
    if (user == null) return;

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreatorCalendarScreen(userId: user.id),
      ),
    );

    if (!mounted) return;
    setState(() {
      _mediaReloadTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentUser = authService.currentUser;
    final effectiveUser = widget.user ?? currentUser;

    if (effectiveUser == null) return const SizedBox();

    final bool isLoggedIn = authService.isAuthenticated && currentUser != null;
    final bool isOwner = isLoggedIn &&
        (effectiveUser.id.toString() == currentUser.id.toString());

    // Use the reactive currentUser from the provider if viewing own profile,
    // otherwise use the fetched full profile or passed widget.user
    final User displayUser =
        isOwner ? currentUser : (_fullProfile ?? effectiveUser);
    final bool isCreator = displayUser.role == UserRole.creator;

    // Show upload button ONLY if Owner AND Creator
    final bool showUpload = isOwner && isCreator;

    // Determine Tabs based on role
    final List<Widget> tabs;
    final List<Widget> tabViews;

    if (isCreator) {
      tabs = const [
        Tab(text: "عروضي"),
        Tab(text: "صور"),
        Tab(text: "فيديوهات"),
        Tab(text: "الجدول"),
      ];
      tabViews = [
        ProfileMediaGrid(
            userId: displayUser.id,
            type: "Offer",
            isOwner: isOwner,
            refreshToken: _mediaReloadTick),
        ProfileMediaGrid(
            userId: displayUser.id,
            type: "Photo",
            isOwner: isOwner,
            refreshToken: _mediaReloadTick),
        ProfileMediaGrid(
            userId: displayUser.id,
            type: "Video",
            isOwner: isOwner,
            refreshToken: _mediaReloadTick),
        ProfileMediaGrid(
            userId: displayUser.id,
            type: "Event",
            isOwner: isOwner,
            refreshToken: _mediaReloadTick),
      ];
    } else {
      // Client View
      tabs = const [
        Tab(text: "مشترياتي"),
        Tab(text: "محفوظات"),
      ];
      tabViews = [
        ProfileMediaGrid(
            userId: displayUser.id,
            type: "Purchased",
            isOwner: isOwner,
            refreshToken: _mediaReloadTick),
        ProfileMediaGrid(
            userId: displayUser.id,
            type: "Saved",
            isOwner: isOwner,
            refreshToken: _mediaReloadTick),
      ];
    }

    final coverImage = displayUser.coverImageUrl != null
        ? _normalizePublicMediaUrl(displayUser.coverImageUrl!)
        : "https://picsum.photos/seed/cover/800/400";

    final profileImage = displayUser.avatarUrl != null
        ? _normalizePublicMediaUrl(displayUser.avatarUrl!)
        : "https://picsum.photos/seed/avatar/200/200";

    final bio = displayUser.bio ??
        (isCreator
            ? "مصور ومخرج سينمائي مقيم في بغداد. متخصص في حفلات الزفاف والإعلانات التجارية."
            : "عاشق للتصوير الفوتوغرافي.");
    final serviceAreaParts = [
      if ((displayUser.city ?? '').trim().isNotEmpty) displayUser.city!.trim(),
      if ((displayUser.country ?? '').trim().isNotEmpty)
        displayUser.country!.trim(),
    ];
    final serviceAreaLabel = serviceAreaParts.join(" - ");

    // Hide stats for client if desired, or keep them if they can follow others
    // For now, allow clients to follow/be followed (social feature)
    return Scaffold(
      backgroundColor: const Color(0xFF161921),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280.0,
              floating: false,
              pinned: true,
              actions: [
                // Follow Button for Clients to follow Creators (or anyone)
                if (!isOwner && isLoggedIn)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          right: 8.0, top: 8.0, bottom: 8.0),
                      child: ElevatedButton(
                        onPressed: () => _toggleFollow(displayUser.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isFollowing ? Colors.grey[200] : Colors.blue,
                          foregroundColor:
                              _isFollowing ? Colors.black : Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: Text(_isFollowing ? "إلغاء المتابعة" : "متابعة",
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                if (!isOwner && isLoggedIn)
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.flag_outlined, color: Colors.white),
                      onPressed: () => _showProfileReportDialog(displayUser),
                    ),
                  ),
                // Settings/Edit Profile - Show for everyone if it's their profile
                if (isOwner)
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  EditProfileScreen(user: displayUser)),
                        );
                      },
                    ),
                  )
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                        onTap: isOwner
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          EditProfileScreen(user: displayUser)),
                                );
                              }
                            : null,
                        child: Image.network(coverImage, fit: BoxFit.cover)),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7)
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: isOwner
                                ? () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) =>
                                              EditProfileScreen(
                                                  user: displayUser)),
                                    );
                                  }
                                : null,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundImage: NetworkImage(profileImage),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      displayUser.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_genderIcon(displayUser.gender) != null)
                                      Icon(
                                        _genderIcon(displayUser.gender),
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                    if (_genderIcon(displayUser.gender) != null)
                                      const SizedBox(width: 6),
                                    if (displayUser.role == UserRole.creator)
                                      const Icon(Icons.verified,
                                          color: Colors.blue, size: 20),
                                  ],
                                ),
                                Text(
                                  "@${displayUser.email.split('@')[0]}",
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                if (serviceAreaLabel.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildProfileMetaChip(
                                        icon: Icons.location_on_outlined,
                                        label: serviceAreaLabel,
                                      ),
                                      if ((displayUser.gender ?? '')
                                          .trim()
                                          .isNotEmpty)
                                        _buildProfileMetaChip(
                                          icon: _genderIcon(displayUser.gender) ??
                                              Icons.wc_rounded,
                                          label: _genderLabel(displayUser.gender),
                                        ),
                                    ],
                                  ),
                                ] else if ((displayUser.gender ?? '')
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildProfileMetaChip(
                                    icon: _genderIcon(displayUser.gender) ??
                                        Icons.wc_rounded,
                                    label: _genderLabel(displayUser.gender),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCreator) ...[
                      if (_isLoadingProfile)
                        const Center(child: CircularProgressIndicator())
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem(
                                "متابعون", _followersCount.toString()),
                            _buildStatItem("متابع", _followingCount.toString()),
                          ],
                        ),
                      const SizedBox(height: 20),
                    ],
                    const Text("نبذة تعريفية",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(bio,
                        style:
                            const TextStyle(color: Colors.grey, height: 1.4)),
                    if (serviceAreaLabel.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Text(
                        "نطاق الخدمة",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 18, color: Colors.white70),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              serviceAreaLabel,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                controller: _tabController,
                showUpload: showUpload,
                onUpload: _handleUpload,
                tabs: tabs, // Pass tabs to delegate
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: tabViews,
        ),
      ),
    );
  }

  String _normalizePublicMediaUrl(String raw) {
    if (raw.trim().isEmpty) return '';
    String url = raw.trim();
    if (url.startsWith('/')) {
      url = 'https://sawrly.com$url';
    } else if (url.startsWith('http://10.0.2.2:') ||
        url.startsWith('http://localhost:')) {
      url = url.replaceFirst(
        RegExp(r'http://(10\.0\.2\.2|localhost):\d+'),
        'https://sawrly.com',
      );
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

  IconData? _genderIcon(String? gender) {
    final normalized = gender?.trim().toLowerCase();
    if (normalized == 'male') return Icons.male_rounded;
    if (normalized == 'female') return Icons.female_rounded;
    return null;
  }

  String _genderLabel(String? gender) {
    final normalized = gender?.trim().toLowerCase();
    if (normalized == 'male') return 'ذكر';
    if (normalized == 'female') return 'أنثى';
    return gender?.trim().isNotEmpty == true ? gender!.trim() : '';
  }

  Widget _buildProfileMetaChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white70),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value,
      {IconData? icon, Color? iconColor, bool tappable = false}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: tappable ? Colors.blue[700] : null,
                )),
            if (icon != null) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: iconColor),
            ]
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            if (tappable)
              const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.blue),
          ],
        ),
      ],
    );
  }
}

class CreatorCalendarScreen extends StatefulWidget {
  final String userId;

  const CreatorCalendarScreen({super.key, required this.userId});

  @override
  State<CreatorCalendarScreen> createState() => _CreatorCalendarScreenState();
}

class _CreatorCalendarScreenState extends State<CreatorCalendarScreen> {
  late Future<List<dynamic>> _loadFuture;
  late DateTime _visibleWeekStart;
  DateTime? _selectedDay;
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _visibleWeekStart = _startOfWeek(_selectedDay!);
    _loadFuture = _loadData();
  }

  Future<List<dynamic>> _loadData() {
    return context.read<MediaService>().fetchEvents(widget.userId);
  }

  DateTime _dayOnly(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  DateTime _startOfWeek(DateTime value) {
    final normalized = _dayOnly(value);
    return normalized.subtract(Duration(days: normalized.weekday - DateTime.monday));
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  int _isoWeekNumber(DateTime date) {
    final normalized = _dayOnly(date);
    final thursday = normalized.add(Duration(days: 4 - normalized.weekday));
    final firstDayOfYear = DateTime.utc(thursday.year, 1, 1);
    final firstThursday = firstDayOfYear.add(
      Duration(days: (DateTime.thursday - firstDayOfYear.weekday + 7) % 7),
    );
    return 1 + (thursday.difference(firstThursday).inDays ~/ 7);
  }

  Map<DateTime, List<Map<String, dynamic>>> _groupEventsByDay(List<dynamic> items) {
    final grouped = <DateTime, List<Map<String, dynamic>>>{};
    for (final raw in items) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final parsed = _parseEventDate(item['date_time']);
      if (parsed == null) continue;
      final key = _dayOnly(parsed);
      grouped.putIfAbsent(key, () => []).add(item);
    }

    for (final entry in grouped.entries) {
      entry.value.sort((a, b) {
        final first = _parseEventDate(a['date_time']);
        final second = _parseEventDate(b['date_time']);
        if (first == null || second == null) return 0;
        return first.compareTo(second);
      });
    }
    return grouped;
  }

  DateTime? _parseEventDate(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  String _monthLabel(DateTime month) {
    const labels = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${labels[month.month - 1]} ${month.year}';
  }

  String _weekRangeLabel(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final startDay = weekStart.day.toString().padLeft(2, '0');
    final endDay = weekEnd.day.toString().padLeft(2, '0');
    final startMonth = _monthLabel(DateTime(weekStart.year, weekStart.month));
    final endMonth = _monthLabel(DateTime(weekEnd.year, weekEnd.month));

    if (weekStart.month == weekEnd.month && weekStart.year == weekEnd.year) {
      return '$startDay - $endDay $startMonth';
    }
    return '$startDay $startMonth - $endDay $endMonth';
  }

  String _weekdayShortLabel(int weekday) {
    const labels = ['اث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'];
    return labels[weekday - 1];
  }

  String _fullDateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  String _eventTimeLabel(dynamic raw) {
    final parsed = _parseEventDate(raw);
    if (parsed == null) return '';
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _normalizeMediaUrl(String raw) {
    if (raw.trim().isEmpty) return '';
    String url = raw.trim();
    if (url.startsWith('/')) {
      url = 'https://sawrly.com$url';
    } else if (url.startsWith('http://10.0.2.2:') ||
        url.startsWith('http://localhost:')) {
      url = url.replaceFirst(
        RegExp(r'http://(10\.0\.2\.2|localhost):\d+'),
        'https://sawrly.com',
      );
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
    const videoExt = ['.mp4', '.mov', '.webm', '.mkv', '.m3u8'];
    return videoExt.any((ext) => lower.contains('$ext?') || lower.endsWith(ext));
  }

  String _calendarStatusLabel(dynamic raw) {
    final status = raw?.toString().toLowerCase();
    if (status == 'busy') return 'مشغول';
    if (status == 'booked') return 'محجوز';
    return 'فعالية';
  }

  IconData _calendarStatusIcon(dynamic raw) {
    final status = raw?.toString().toLowerCase();
    if (status == 'busy') return Icons.block_rounded;
    if (status == 'booked') return Icons.event_busy_rounded;
    return Icons.event_available_rounded;
  }

  Color _calendarStatusColor(dynamic raw) {
    final status = raw?.toString().toLowerCase();
    if (status == 'busy') return AppColors.warning;
    if (status == 'booked') return AppColors.accentPink;
    return AppColors.primaryLight;
  }

  Color _calendarStatusBackground(dynamic raw) {
    final status = raw?.toString().toLowerCase();
    if (status == 'busy') return AppColors.warningBg;
    if (status == 'booked') return AppColors.errorBg;
    return AppColors.infoBg;
  }

  Widget _buildCalendarStatusChip({
    required String label,
    required IconData icon,
    required String status,
    required String currentStatus,
    required VoidCallback onTap,
  }) {
    final isSelected = status == currentStatus;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: isSelected ? const LinearGradient(colors: AppColors.accentGradient) : null,
          color: isSelected ? null : AppColors.surfaceLight,
          boxShadow: isSelected ? AppShadows.glowAccent : null,
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : AppColors.border.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  String _calendarStatusTitle(String status) {
    if (status == 'busy') return 'مشغول';
    return 'محجوز';
  }

  String _formatDateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day/$month/$year';
  }

  Color _calendarStatusCardColor(String status) {
    if (status == 'busy') return AppColors.warningBg;
    return AppColors.errorBg;
  }

  Color _calendarStatusBorderColor(String status) {
    if (status == 'busy') return AppColors.warning.withValues(alpha: 0.45);
    return AppColors.accentPink.withValues(alpha: 0.45);
  }

  List<Map<String, dynamic>> _eventsForDay(
    DateTime day,
    Map<DateTime, List<Map<String, dynamic>>> grouped,
  ) {
    return grouped[_dayOnly(day)] ?? const [];
  }

  Widget _buildEventPreviewThumb(Map<String, dynamic> item, {double size = 18}) {
    final previewUrl = _normalizeMediaUrl(item['cover_image_url']?.toString() ?? '');
    final isVideo = _isVideoUrl(previewUrl);
    if (previewUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _calendarStatusBackground(item['calendar_status']),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          _calendarStatusIcon(item['calendar_status']),
          size: size * 0.65,
          color: _calendarStatusColor(item['calendar_status']),
        ),
      );
    }

    if (isVideo) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: AppColors.darkGradient),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.play_circle_fill_rounded,
          color: Colors.white,
          size: 14,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        previewUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: AppColors.surfaceLight,
          child: const Icon(Icons.image, color: Colors.white70, size: 12),
        ),
      ),
    );
  }

  Widget _buildCalendarDayCell({
    required DateTime day,
    required bool isSelected,
    required bool isToday,
    required List<Map<String, dynamic>> events,
    required VoidCallback onTap,
  }) {
    final primaryEvent = events.isNotEmpty ? events.first : null;
    final statusColor = primaryEvent == null
        ? Colors.transparent
        : _calendarStatusColor(primaryEvent['calendar_status']);
    final hasEvent = primaryEvent != null;

    return Expanded(
      child: AspectRatio(
        aspectRatio: 0.86,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.surfaceLight : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.accentPink.withValues(alpha: 0.85)
                        : hasEvent
                            ? statusColor.withValues(alpha: 0.45)
                            : AppColors.borderLight,
                    width: isSelected ? 1.4 : 1,
                  ),
                  boxShadow: isSelected ? AppShadows.glowAccent : null,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: isToday
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: AppColors.accentGradient,
                                ),
                                boxShadow: AppShadows.glowAccent,
                              )
                            : null,
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: hasEvent
                              ? statusColor
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDayPanel(List<Map<String, dynamic>> events) {
    final selectedDay = _selectedDay ?? _dayOnly(DateTime.now());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'تفاصيل اليوم',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fullDateLabel(selectedDay),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showCreateEventDialog(initialDate: selectedDay),
                icon: const Icon(Icons.add),
                label: const Text('إضافة'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (events.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Text(
                'لا توجد عناصر في هذا اليوم',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            ...events.map(
              (item) {
                final previewUrl =
                    _normalizeMediaUrl(item['cover_image_url']?.toString() ?? '');
                final isVideo = _isVideoUrl(previewUrl);
                final statusColor = _calendarStatusColor(item['calendar_status']);
                final statusBg = _calendarStatusBackground(item['calendar_status']);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEventPreviewThumb(item, size: 54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBg,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _calendarStatusLabel(item['calendar_status']),
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Text(
                                  _eventTimeLabel(item['date_time']),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (isVideo)
                                  const Icon(
                                    Icons.videocam_rounded,
                                    size: 16,
                                    color: Colors.white70,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['title']?.toString().trim().isNotEmpty == true
                                  ? item['title'].toString().trim()
                                  : _calendarStatusLabel(item['calendar_status']),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if ((item['location']?.toString().trim().isNotEmpty ??
                                false)) ...[
                              const SizedBox(height: 6),
                              Text(
                                item['location'].toString().trim(),
                                style: const TextStyle(
                                  color: AppColors.primaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if ((item['notes']?.toString().trim().isNotEmpty ??
                                false)) ...[
                              const SizedBox(height: 6),
                              Text(
                                item['notes'].toString().trim(),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showCreateEventDialog({DateTime? initialDate}) async {
    final locationController = TextEditingController();
    final notesController = TextEditingController();
    DateTime selectedDate = initialDate ?? DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 12, minute: 0);
    String selectedStatus = 'booked';
    File? selectedMedia;
    bool selectedMediaIsVideo = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text("إضافة إلى الجدول"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "الحالة",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildCalendarStatusChip(
                            label: "محجوز",
                            icon: Icons.event_busy,
                            status: 'booked',
                            currentStatus: selectedStatus,
                            onTap: () => setDialogState(() => selectedStatus = 'booked'),
                          ),
                          _buildCalendarStatusChip(
                            label: "مشغول",
                            icon: Icons.block,
                            status: 'busy',
                            currentStatus: selectedStatus,
                            onTap: () => setDialogState(() => selectedStatus = 'busy'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: dialogContext,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 1)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (pickedDate == null) return;
                          setDialogState(() {
                            selectedDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              selectedDate.hour,
                              selectedDate.minute,
                            );
                          });
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_formatDateLabel(selectedDate)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final pickedTime = await showTimePicker(
                            context: dialogContext,
                            initialTime: selectedTime,
                          );
                          if (pickedTime == null) return;
                          setDialogState(() => selectedTime = pickedTime);
                        },
                        icon: const Icon(Icons.access_time),
                        label: Text(selectedTime.format(dialogContext)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final mediaService = context.read<MediaService>();
                    final selection = await showModalBottomSheet<String>(
                      context: dialogContext,
                      builder: (sheetContext) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.image, color: Colors.blue),
                              title: const Text("رفع صورة"),
                              onTap: () => Navigator.pop(sheetContext, "image"),
                            ),
                            ListTile(
                              leading: const Icon(Icons.videocam, color: Colors.red),
                              title: const Text("رفع فيديو"),
                              onTap: () => Navigator.pop(sheetContext, "video"),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (selection == null) return;
                    final file = selection == "video"
                        ? await mediaService.pickVideo()
                        : await mediaService.pickImage();
                    if (file == null) return;
                    setDialogState(() {
                      selectedMedia = file;
                      selectedMediaIsVideo = selection == "video";
                    });
                  },
                  icon: Icon(
                    selectedMediaIsVideo ? Icons.videocam : Icons.perm_media_rounded,
                  ),
                  label: Text(
                    selectedMedia == null
                        ? "إضافة صورة أو فيديو للحدث"
                        : selectedMedia!.path.split(Platform.pathSeparator).last,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: "الموقع (اختياري)"),
                ),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: "ملاحظات (اختياري)"),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _calendarStatusCardColor(selectedStatus),
                    border: Border.all(
                      color: _calendarStatusBorderColor(selectedStatus),
                    ),
                  ),
                  child: Text(
                    selectedStatus == 'booked'
                        ? "سيظهر هذا اليوم للعميل كـ محجوز"
                        : "سيظهر هذا اليوم للعميل كـ مشغول",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("إلغاء"),
            ),
            TextButton(
              onPressed: () async {
                final scheduledAt = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                showDialog(
                  context: dialogContext,
                  barrierDismissible: false,
                  builder: (_) => const Center(child: CircularProgressIndicator()),
                );

                final error = await context.read<MediaService>().createEvent(
                      _calendarStatusTitle(selectedStatus),
                      scheduledAt.toIso8601String(),
                      locationController.text.trim(),
                      selectedMedia,
                      calendarStatus: selectedStatus,
                      notes: notesController.text.trim(),
                    );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                }

                if (!mounted || !dialogContext.mounted) return;

                if (error == null) {
                  Navigator.pop(dialogContext);
                  setState(() {
                    _didChange = true;
                    _selectedDay = _dayOnly(selectedDate);
                    _visibleWeekStart = _startOfWeek(selectedDate);
                    _loadFuture = _loadData();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("تم تحديث الجدول!")),
                  );
                } else {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(error)));
                }
              },
              child: const Text("إنشاء"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _didChange);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          foregroundColor: Colors.white,
          title: const Text('الجدول'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context, _didChange),
          ),
          actions: [
            IconButton(
              onPressed: () => _showCreateEventDialog(initialDate: _selectedDay),
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
        body: FutureBuilder<List<dynamic>>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.white70),
                ),
              );
            }

            final items = snapshot.data ?? [];
            final grouped = _groupEventsByDay(items);
            final selectedDay = _selectedDay ?? _dayOnly(DateTime.now());
            final selectedDayEvents = _eventsForDay(selectedDay, grouped);
            final today = _dayOnly(DateTime.now());
            final weekDays = List.generate(
              7,
              (index) => _visibleWeekStart.add(Duration(days: index)),
            );
            final weekNumber = _isoWeekNumber(_visibleWeekStart);

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              final newWeek =
                                  _visibleWeekStart.subtract(const Duration(days: 7));
                              setState(() {
                                _visibleWeekStart = newWeek;
                                _selectedDay = newWeek;
                              });
                            },
                            icon: const Icon(Icons.chevron_left, color: Colors.white),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'الأسبوع $weekNumber',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _weekRangeLabel(_visibleWeekStart),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final newWeek =
                                  _visibleWeekStart.add(const Duration(days: 7));
                              setState(() {
                                _visibleWeekStart = newWeek;
                                _selectedDay = newWeek;
                              });
                            },
                            icon: const Icon(Icons.chevron_right, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 34,
                            alignment: Alignment.center,
                            child: Text(
                              '$weekNumber',
                              style: const TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          for (final day in weekDays)
                            Expanded(
                              child: Center(
                                child: Text(
                                  _weekdayShortLabel(day.weekday),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(width: 34),
                          for (final day in weekDays)
                            _buildCalendarDayCell(
                              day: day,
                              isSelected: _sameDay(day, selectedDay),
                              isToday: _sameDay(day, today),
                              events: _eventsForDay(day, grouped),
                              onTap: () {
                                setState(() {
                                  _selectedDay = _dayOnly(day);
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildSelectedDayPanel(selectedDayEvents),
              ],
            );
          },
        ),
      ),
    );
  }
}

class ProfileMediaGrid extends StatefulWidget {
  final String userId;
  final String type;
  final bool isOwner;
  final int refreshToken;

  const ProfileMediaGrid({
    super.key,
    required this.userId,
    required this.type,
    this.isOwner = false,
    this.refreshToken = 0,
  });

  @override
  State<ProfileMediaGrid> createState() => _ProfileMediaGridState();
}

class _ProfileMediaGridState extends State<ProfileMediaGrid> {
  late Future<List<dynamic>> _loadFuture;

  bool _looksLikeHtmlError(String value) {
    final normalized = value.trimLeft().toLowerCase();
    return normalized.startsWith('<!doctype html') ||
        normalized.startsWith('<html') ||
        (normalized.contains('<html') && normalized.contains('</html>'));
  }

  bool _isEntityTooLarge(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('request entity too large') ||
        normalized.contains('payload too large') ||
        RegExp(r'\b413\b').hasMatch(normalized);
  }

  String _friendlySnapshotError(Object error) {
    final text = error.toString();
    if (_looksLikeHtmlError(text) || _isEntityTooLarge(text)) {
      return "حجم الملف كبير جداً. يرجى اختيار ملف أصغر.";
    }
    return "حدث خطأ أثناء تحميل المحتوى";
  }

  Widget _buildVideoTile() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF181A24),
            Color(0xFF11131C),
            Color(0xFF07080D),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -18,
            child: Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x24FF5252),
              ),
            ),
          ),
          Positioned(
            bottom: -24,
            left: -16,
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x0DFFFFFF),
              ),
            ),
          ),
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white, size: 52),
                SizedBox(height: 10),
                Text(
                  "فيديو",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x59000000),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x1AFFFFFF)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    "HD",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _normalizeMediaUrl(String raw) {
    if (raw.trim().isEmpty) return '';
    String url = raw.trim();
    if (url.startsWith('/')) {
      url = 'https://sawrly.com$url';
    } else if (url.startsWith('http://10.0.2.2:') ||
        url.startsWith('http://localhost:')) {
      url = url.replaceFirst(
        RegExp(r'http://(10\.0\.2\.2|localhost):\d+'),
        'https://sawrly.com',
      );
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

  bool _isVideoUrl(String raw) {
    if (raw.trim().isEmpty) return false;
    final lower = raw.toLowerCase();
    if (lower.contains('/videos/')) return true;
    const videoExt = ['.mp4', '.mov', '.webm', '.mkv', '.m3u8'];
    return videoExt
        .any((ext) => lower.contains('$ext?') || lower.endsWith(ext));
  }

  void _openMediaPreview({
    required String mediaUrl,
    required String title,
    required bool isVideo,
  }) {
    if (mediaUrl.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ProfileMediaPreviewScreen(
          mediaUrl: mediaUrl,
          title: title,
          isVideo: isVideo,
        ),
      ),
    );
  }

  DateTime? _parseEventDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  String _formatEventDate(dynamic raw) {
    final parsed = _parseEventDate(raw);
    if (parsed == null) return '';
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day/$month/$year - $hour:$minute';
  }

  String _calendarStatusLabel(dynamic raw) {
    final status = raw?.toString().toLowerCase();
    if (status == 'busy') return 'مشغول';
    if (status == 'booked') return 'محجوز';
    return 'فعالية';
  }

  IconData _calendarStatusIcon(dynamic raw) {
    final status = raw?.toString().toLowerCase();
    if (status == 'busy') return Icons.block;
    if (status == 'booked') return Icons.event_busy;
    return Icons.event;
  }

  Color _calendarStatusColor(dynamic raw) {
    final status = raw?.toString().toLowerCase();
    if (status == 'busy') return AppColors.warning;
    if (status == 'booked') return AppColors.accentPink;
    return AppColors.primaryLight;
  }

  Color _calendarStatusBackground(dynamic raw) {
    final status = raw?.toString().toLowerCase();
    if (status == 'busy') return AppColors.warningBg;
    if (status == 'booked') return AppColors.errorBg;
    return AppColors.infoBg;
  }

  Widget _buildEventGridCard(dynamic rawItem) {
    final item = Map<String, dynamic>.from(rawItem as Map);
    final title = (item['title']?.toString().trim().isNotEmpty ?? false)
        ? item['title'].toString().trim()
        : _calendarStatusLabel(item['calendar_status']);
    final formattedDate = _formatEventDate(item['date_time']);
    final location = item['location']?.toString().trim() ?? '';
    final notes = item['notes']?.toString().trim() ?? '';
    final previewUrl =
        _normalizeMediaUrl(item['cover_image_url']?.toString() ?? '');
    final hasPreview = previewUrl.isNotEmpty;
    final isVideo = _isVideoUrl(previewUrl);
    final badgeColor = _calendarStatusColor(item['calendar_status']);
    final badgeBackground = _calendarStatusBackground(item['calendar_status']);

    return Card(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: hasPreview
            ? () => _openMediaPreview(
                  mediaUrl: previewUrl,
                  title: title,
                  isVideo: isVideo,
                )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 118,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.darkGradient,
                ),
              ),
              child: Stack(
                children: [
                  if (hasPreview)
                    Positioned.fill(
                      child: isVideo
                          ? _buildVideoTile()
                          : Image.network(
                              previewUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(),
                            ),
                    )
                  else
                    Center(
                      child: Icon(
                        _calendarStatusIcon(item['calendar_status']),
                        color: badgeColor,
                        size: 42,
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBackground,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _calendarStatusIcon(item['calendar_status']),
                            size: 13,
                            color: badgeColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _calendarStatusLabel(item['calendar_status']),
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (formattedDate.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (location.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              location,
                              style: const TextStyle(
                                color: AppColors.primaryLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (notes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              notes,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.isOwner)
                      IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                          color: Colors.white70,
                        ),
                        onPressed: () => _showItemOptions(context, item),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadData();
  }

  @override
  void didUpdateWidget(covariant ProfileMediaGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken ||
        oldWidget.userId != widget.userId ||
        oldWidget.type != widget.type) {
      setState(() {
        _loadFuture = _loadData();
      });
    }
  }

  Future<List<dynamic>> _loadData() {
    final mediaService = context.read<MediaService>();
    if (widget.type == "Offer") {
      return mediaService.fetchOffers(widget.userId);
    } else if (widget.type == "Saved") {
      return mediaService.fetchSavedOffers();
    } else if (widget.type == "Photo") {
      return mediaService.fetchPhotos(widget.userId);
    } else if (widget.type == "Video") {
      return mediaService.fetchVideos(widget.userId);
    } else if (widget.type == "Event") {
      return mediaService.fetchEvents(widget.userId);
    } else {
      return Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text(_friendlySnapshotError(snapshot.error!)));
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                  widget.type == "Purchased"
                      ? Icons.shopping_bag_outlined
                      : widget.type == "Saved"
                          ? Icons.bookmark_border
                          : Icons.perm_media_outlined,
                  size: 48,
                  color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                  widget.type == "Purchased"
                      ? "You haven't purchased anything yet"
                      : widget.type == "Saved"
                          ? "No saved items"
                          : "No ${widget.type} items yet",
                  style: TextStyle(color: Colors.grey[600])),
            ],
          ));
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: widget.type == "Offer"
                ? 0.95
                : widget.type == "Event"
                    ? 0.86
                    : 0.75,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (widget.type == "Event") {
              return _buildEventGridCard(item);
            }
            // Normalize data fields
            String imageUrl = "";
            String previewUrl = "";
            String title = "";
            String subtitle = "";
            bool isPreviewVideo = false;
            bool isGridVideo = false;

            bool showVideoBadge = false;

            if (widget.type == "Offer") {
              final offer = Offer.fromJson(
                Map<String, dynamic>.from(item as Map),
              );

              title = offer.title.isEmpty ? "No Title" : offer.title;
              subtitle = "${offer.price.toStringAsFixed(0)} IQD";

              final normalizedMedia = offer.mediaItems
                  .map(
                    (m) => OfferMediaItem(
                      url: _normalizeMediaUrl(m.url),
                      type: m.type,
                    ),
                  )
                  .toList();

              showVideoBadge = normalizedMedia.any((m) => m.isVideo);
              final firstImage = normalizedMedia.firstWhere(
                (m) => !m.isVideo && m.url.trim().isNotEmpty,
                orElse: () => const OfferMediaItem(url: '', type: ''),
              );

              if (firstImage.url.trim().isNotEmpty) {
                imageUrl = firstImage.url;
              } else {
                final fallback = _normalizeMediaUrl(offer.imageUrl);
                if (_isVideoUrl(fallback)) {
                  previewUrl = fallback;
                  isPreviewVideo = true;
                  isGridVideo = true;
                } else {
                  imageUrl = fallback.isEmpty
                      ? "https://via.placeholder.com/300"
                      : fallback;
                }
              }
            } else if (widget.type == "Photo" || widget.type == "Video") {
              // ... existing logic ...
              String path = item['url'] ?? "";
              previewUrl = _normalizeMediaUrl(path);
              if (widget.type == "Video") {
                isPreviewVideo = true;
                isGridVideo = true;
              } else {
                imageUrl = previewUrl;
              }
              title = item['caption'] ??
                  (widget.type == "Video" ? "Video" : "Photo");
            }

            final canPreview = previewUrl.isNotEmpty &&
                (widget.type == "Photo" || widget.type == "Video");

            return Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (widget.type == "Offer") {
                            final offer = Offer.fromJson(
                              Map<String, dynamic>.from(item as Map),
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OfferDetailsScreen(offer: offer),
                              ),
                            );
                            return;
                          }
                          if (canPreview) {
                            _openMediaPreview(
                              mediaUrl: previewUrl,
                              title: title,
                              isVideo: isPreviewVideo,
                            );
                          }
                        },
                        child: isGridVideo
                            ? _buildVideoTile()
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    errorBuilder: (ctx, err, stack) =>
                                        const Center(child: Icon(Icons.error)),
                                  ),
                                  if (showVideoBadge)
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0x59000000),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                              color: const Color(0x1AFFFFFF)),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.videocam_rounded,
                                                color: Colors.white, size: 12),
                                            SizedBox(width: 4),
                                            Text(
                                              "HD",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subtitle.isNotEmpty)
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                      color: Colors.green, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        if (widget.isOwner &&
                            (widget.type == "Offer" ||
                                widget.type == "Photo" ||
                                widget.type == "Video" ||
                                widget.type == "Event"))
                          IconButton(
                            icon: const Icon(Icons.more_vert, size: 20),
                            onPressed: () => _showItemOptions(context, item),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else if (!widget.isOwner &&
                            (widget.type == "Photo" || widget.type == "Video"))
                          IconButton(
                            icon: const Icon(Icons.flag_outlined,
                                size: 20, color: Colors.redAccent),
                            onPressed: () => _showReportDialog(item),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else if (!widget.isOwner && widget.type == "Offer")
                          IconButton(
                            icon: const Icon(Icons.flag_outlined,
                                size: 20, color: Colors.redAccent),
                            onPressed: () => _showOfferReportDialog(item),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showItemOptions(BuildContext context, dynamic item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161921),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text("تعديل",
                    style: TextStyle(fontWeight: FontWeight.bold)), // Edit
                onTap: () {
                  Navigator.pop(context);
                  _handleEdit(item);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text("حذف",
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold)), // Delete
                onTap: () {
                  Navigator.pop(context);
                  _handleDelete(item);
                },
              ),
              const SizedBox(height: 10), // Extra space at bottom
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog(dynamic item) {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login first")),
      );
      return;
    }

    final mediaId = (item['id'] ?? '').toString();
    if (mediaId.isEmpty || mediaId.startsWith('mock-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This media cannot be reported")),
      );
      return;
    }

    showReportDialog(
      context: context,
      title: 'الإبلاغ عن الوسائط',
      onSubmit: (reason, details) {
        return context.read<MediaService>().reportMedia(
              mediaId: mediaId,
              reason: reason,
              details: details,
            );
      },
    );
  }

  void _showOfferReportDialog(dynamic item) {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login first")),
      );
      return;
    }

    final offerId = (item['id'] ?? '').toString();
    if (offerId.isEmpty || offerId.startsWith('mock-')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("This offer cannot be reported")),
      );
      return;
    }

    showReportDialog(
      context: context,
      title: 'الإبلاغ عن العرض',
      onSubmit: (reason, details) {
        return context.read<MediaService>().reportContent(
              targetType: 'offer',
              targetId: offerId,
              reason: reason,
              details: details,
            );
      },
    );
  }

  void _handleEdit(dynamic item) async {
    if (widget.type == "Offer") {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CreateOfferScreen(initialItem: item),
        ),
      );

      if (result == true) {
        setState(() {
          _loadFuture = _loadData();
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ميزة التعديل ستتوفر قريباً")),
      );
    }
  }

  void _handleDelete(dynamic item) async {
    final mediaService = context.read<MediaService>();
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف", textAlign: TextAlign.right),
        content: const Text("هل أنت متأكد أنك تريد حذف هذا العنصر نهائياً؟",
            textAlign: TextAlign.right),
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

    if (confirm == true) {
      String? error;

      final id = item['id'].toString();
      if (widget.type == "Offer") {
        error = await _deleteOfferWithResult(mediaService, id);
      } else if (widget.type == "Event") {
        error = await _deleteEventWithResult(mediaService, id);
      } else if (widget.type == "Photo") {
        error = await _deletePhotoWithResult(mediaService, id);
      } else if (widget.type == "Video") {
        error = await _deleteVideoWithResult(mediaService, id);
      }

      if (!mounted) return;

      if (error == null) {
        setState(() {
          _loadFuture = _loadData();
        });
        messenger.showSnackBar(const SnackBar(content: Text("تم الحذف بنجاح")));
      } else {
        messenger.showSnackBar(SnackBar(
          content: Text("فشل الحذف: $error"),
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  // Helper methods to get actual error strings
  Future<String?> _deleteOfferWithResult(
      MediaService service, String id) async {
    try {
      final res = await service.deleteOffer(id);
      return res ? null : "Unauthorized or not found";
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> _deleteEventWithResult(
      MediaService service, String id) async {
    try {
      final res = await service.deleteEvent(id);
      return res ? null : "Unauthorized or not found";
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> _deletePhotoWithResult(
      MediaService service, String id) async {
    try {
      final res = await service.deletePhoto(id);
      return res ? null : "Unauthorized or not found";
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> _deleteVideoWithResult(
      MediaService service, String id) async {
    try {
      final res = await service.deleteVideo(id);
      return res ? null : "Unauthorized or not found";
    } catch (e) {
      return e.toString();
    }
  }
}

class _ProfileMediaPreviewScreen extends StatefulWidget {
  final String mediaUrl;
  final String title;
  final bool isVideo;

  const _ProfileMediaPreviewScreen({
    required this.mediaUrl,
    required this.title,
    required this.isVideo,
  });

  @override
  State<_ProfileMediaPreviewScreen> createState() =>
      _ProfileMediaPreviewScreenState();
}

class _ProfileMediaPreviewScreenState
    extends State<_ProfileMediaPreviewScreen> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl))
        ..setLooping(true);
      _initializeFuture = _controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller!.play();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  Widget _buildVideo() {
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            _controller == null ||
            !_controller!.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        return GestureDetector(
          onTap: _togglePlayback,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
              if (!_controller!.value.isPlaying)
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImage() {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4,
      child: Center(
        child: Image.network(
          widget.mediaUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const CircularProgressIndicator(color: Colors.white);
          },
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.broken_image_outlined,
            color: Colors.white,
            size: 56,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title.isEmpty
              ? (widget.isVideo ? 'فيديو' : 'صورة')
              : widget.title,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: widget.isVideo ? _buildVideo() : _buildImage(),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController controller;
  final bool showUpload;
  final VoidCallback? onUpload;
  final List<Widget> tabs; // Added tabs list

  _SliverAppBarDelegate(
      {required this.controller,
      this.showUpload = false,
      this.onUpload,
      required this.tabs});

  @override
  double get minExtent => 48.0 + 1; // Standard TabBar height + border
  @override
  double get maxExtent => 48.0 + 1;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Row(
            children: [
              if (showUpload)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                  child: IconButton(
                    icon: const Icon(Icons.add_circle,
                        color: Colors.blue, size: 28),
                    onPressed: onUpload,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                  ),
                ),
              Expanded(
                child: Align(
                  // Align TabBar to the left
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    controller: controller,
                    labelColor: const Color(0xFFBC83FF),
                    unselectedLabelColor: Colors.white70,
                    indicatorColor: const Color(0xFF9B59F5),
                    overlayColor: WidgetStateProperty.all(
                      const Color(0x1A7A3EED),
                    ),
                    physics: const BouncingScrollPhysics(),
                    isScrollable: true,
                    tabAlignment: TabAlignment.start, // Force start alignment
                    labelPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0), // Ensure padding
                    padding: EdgeInsets.zero, // Remove outer padding
                    tabs: tabs, // Use dynamic tabs
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return showUpload != oldDelegate.showUpload ||
        controller != oldDelegate.controller ||
        tabs != oldDelegate.tabs;
  }
}
