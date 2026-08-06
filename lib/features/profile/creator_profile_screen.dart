import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../models/offer.dart';
import '../../models/user.dart';
import '../../core/auth/auth_service.dart';
import '../../core/design/design_tokens.dart';
import '../../core/theme/app_theme_service.dart';
import '../../core/theme/app_theme_config.dart';
import '../../core/services/media_service.dart';
import '../../core/widgets/report_dialog.dart';
import '../home/offer_details_screen.dart';
import 'edit_profile_screen.dart';
import 'create_offer_screen.dart';

// Used by runtime debug evidence logging below.
String? _debugLastNormalizedUrl;
String? _debugLastImageStatus;

class CreatorProfileScreen extends StatefulWidget {
  final User? user;
  final String? userId;

  const CreatorProfileScreen({super.key, this.user, this.userId});

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen>
    with TickerProviderStateMixin {
  static const int _maxFreeCreatorImages = 8;
  static const int _maxFreeCreatorVideos = 4;
  static const int _maxMonthlyCreatorImages = 16;
  static const int _maxMonthlyCreatorVideos = 8;
  static const int _maxFreeVideoDurationSeconds = 60;

  late TabController _tabController;
  late VoidCallback _tabListener;

  bool _isLoadingProfile = false;
  bool _isReloadingBadge = false;
  int _mediaReloadTick = 0;
  User? _fullProfile;
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isFollowing = false;
  int _badgeReloadTick = 0;
  String? _badgeReloadStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabListener = () { setState(() {}); };
    _tabController.addListener(_tabListener);

    _loadFullProfile();
  }

  Future<void> _loadFullProfile({bool bypassCache = false}) async {
    final String? targetId = widget.userId ?? widget.user?.id ?? context.read<AuthService>().currentUser?.id;
    if (targetId == null || targetId.trim().isEmpty) return;
    final user = widget.user ?? (targetId.isNotEmpty ? User(id: targetId, name: '', email: '', role: UserRole.creator) : null);
    if (user == null) return;

    setState(() => _isLoadingProfile = true);
    final fullProfile =
        await context.read<AuthService>().fetchUserProfile(targetId, bypassCache: bypassCache);
    // #region debug-point D:full-profile-loaded
    debugPrint(
      "[DEBUG] _loadFullProfile D: requestedUserId=${user.id} bypassCache=$bypassCache "
      "gotProfile=${fullProfile != null} "
      "isSuperadmin=${fullProfile?.isSuperadmin} "
      "badgeIconUrl=${fullProfile?.superadminBadgeIconUrl} "
      "badgeLabel=${fullProfile?.superadminBadgeLabel} "
      "email=${fullProfile?.email}",
    );
    // #endregion
    if (fullProfile != null && mounted) {
      setState(() {
        _fullProfile = fullProfile;
        _followersCount = fullProfile.followersCount;
        _followingCount = fullProfile.followingCount;
        _isFollowing = fullProfile.isFollowing;
        _isLoadingProfile = false;
        _badgeReloadTick += 1;
      });
    } else if (mounted) {
      setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _forceReloadSuperadminBadge() async {
    debugPrint("[DEBUG] _forceReloadSuperadminBadge D: requested");
    if (_isReloadingBadge) return;
    if (!mounted) return;
    setState(() {
      _isReloadingBadge = true;
      _badgeReloadStatus = 'fetching /auth/me...';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Laddar om superadmin-badge..."),
        duration: Duration(seconds: 2),
      ),
    );
    try {
      await context.read<AuthService>().fetchMe();
      if (!mounted) return;
      setState(() => _badgeReloadStatus = 'fetching /users/:id...');
      await _loadFullProfile(bypassCache: true);
      if (!mounted) return;
      setState(() {
        _badgeReloadTick += 1;
        _debugLastImageStatus = null;
        _badgeReloadStatus = 'forcing Image.network rebuild...';
      });
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      setState(() => _badgeReloadStatus = 'done (kolla debug-fältet)');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Superadmin-badge reload klar. badgeReloadTick=$_badgeReloadTick",
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint("[DEBUG] _forceReloadSuperadminBadge D error: $e");
      if (mounted) {
        setState(() => _badgeReloadStatus = 'error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Misslyckades med reload: $e"),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isReloadingBadge = false);
      }
    }
    debugPrint("[DEBUG] _forceReloadSuperadminBadge D: finished badgeReloadTick=$_badgeReloadTick");
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

  Future<void> _showSubscriptionRequiredDialog(
    BuildContext screenContext, {
    required String message,
  }) async {
    await showDialog<void>(
      context: screenContext,
      builder: (context) => AlertDialog(
        title: const Text("اشتراك مطلوب", textAlign: TextAlign.right),
        content: Text(message, textAlign: TextAlign.right),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("موافق"),
          ),
        ],
      ),
    );
  }

  String _normalizedPlan(String? planRaw) {
    return (planRaw ?? '').trim().toLowerCase();
  }

  bool _hasActiveSubscription(User user) {
    final plan = _normalizedPlan(user.subscriptionPlan);
    if (plan.isEmpty) return false;
    final expiresAtRaw = user.subscriptionExpiresAt;
    if (expiresAtRaw == null || expiresAtRaw.trim().isEmpty) return false;
    final expiresAt = DateTime.tryParse(expiresAtRaw);
    return expiresAt != null && expiresAt.isAfter(DateTime.now());
  }

  bool _hasUnlimitedMediaPlan(User user) {
    if (!_hasActiveSubscription(user)) return false;
    final plan = _normalizedPlan(user.subscriptionPlan);
    return plan == 'yearly' || plan == 'plus' || plan == 'monthly_plus';
  }

  bool _hasLimitedMonthlyPlan(User user) {
    return _hasActiveSubscription(user) && _normalizedPlan(user.subscriptionPlan) == 'monthly';
  }

  Future<int?> _readVideoDurationSeconds(File file) async {
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      return controller.value.duration.inSeconds;
    } catch (_) {
      return null;
    } finally {
      await controller.dispose();
    }
  }

  void _showUploadLoadingDialog(BuildContext screenContext, String message) {
    final theme = context.read<AppThemeService>();
    final colors = theme.colors;
    showDialog<void>(
      context: screenContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colors.background,
        content: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                message,
                textAlign: TextAlign.right,
                style: TextStyle(color: colors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = context.read<AuthService>();
    final user = widget.user ?? authService.currentUser;
    final length = (user?.role == UserRole.client) ? 2 : 4;
    if (_tabController.length != length) {
      _tabController.removeListener(_tabListener);
      _tabController.dispose();
      final newLength = (user?.role == UserRole.client) ? 2 : 4;
      _tabController = TabController(length: newLength, vsync: this);
      _tabController.addListener(_tabListener);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_tabListener);
    _tabController.dispose();
    super.dispose();
  }

  void _handleUpload() {
    final theme = context.read<AppThemeService>();
    final colors = theme.colors;
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
                  leading: Icon(Icons.local_offer, color: colors.success),
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
                  leading: Icon(Icons.image, color: colors.info),
                  title: const Text("رفع صورة"),
                  onTap: () async {
                    Navigator.pop(context);
                    final mediaService = screenContext.read<MediaService>();
                    final currentUser =
                        screenContext.read<AuthService>().currentUser;
                    if (currentUser == null) return;
                    final existingPhotos =
                        await mediaService.fetchPhotos(currentUser.id);
                    final hasUnlimitedPlan =
                        _hasUnlimitedMediaPlan(currentUser);
                    final hasLimitedMonthlyPlan =
                        _hasLimitedMonthlyPlan(currentUser);
                    final maxImages = hasLimitedMonthlyPlan
                        ? _maxMonthlyCreatorImages
                        : _maxFreeCreatorImages;
                    if (!hasUnlimitedPlan &&
                        existingPhotos.length >= maxImages) {
                      if (!screenContext.mounted) return;
                      await _showSubscriptionRequiredDialog(
                        screenContext,
                        message:
                            hasLimitedMonthlyPlan
                                ? "الخطة الشهرية المحدودة تسمح برفع $_maxMonthlyCreatorImages صورة كحد أقصى."
                                : "يمكنك رفع $_maxFreeCreatorImages صور فقط بدون اشتراك. الاشتراك الشهري المحدود يضيف 4 صور إضافية، أما Plus والسنوي فغير محدودين.",
                      );
                      return;
                    }
                    final file = await mediaService.pickImage();
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

                      if (!screenContext.mounted) return;
                      _showUploadLoadingDialog(
                        screenContext,
                        "جاري رفع الصورة...",
                      );
                      final success =
                          await mediaService.uploadPhoto(file, caption);
                      if (screenContext.mounted) {
                        Navigator.of(screenContext, rootNavigator: true).pop();
                      }
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
                  leading: Icon(Icons.videocam, color: colors.error),
                  title: const Text("رفع فيديو"),
                  onTap: () async {
                    Navigator.pop(context);
                    final mediaService = screenContext.read<MediaService>();
                    final currentUser =
                        screenContext.read<AuthService>().currentUser;
                    if (currentUser == null) return;
                    final existingVideos =
                        await mediaService.fetchVideos(currentUser.id);
                    final hasUnlimitedPlan =
                        _hasUnlimitedMediaPlan(currentUser);
                    final hasLimitedMonthlyPlan =
                        _hasLimitedMonthlyPlan(currentUser);
                    final maxVideos = hasLimitedMonthlyPlan
                        ? _maxMonthlyCreatorVideos
                        : _maxFreeCreatorVideos;
                    if (!hasUnlimitedPlan &&
                        existingVideos.length >= maxVideos) {
                      if (!screenContext.mounted) return;
                      await _showSubscriptionRequiredDialog(
                        screenContext,
                        message:
                            hasLimitedMonthlyPlan
                                ? "الخطة الشهرية المحدودة تسمح برفع $_maxMonthlyCreatorVideos فيديوهات كحد أقصى."
                                : "يمكنك رفع $_maxFreeCreatorVideos فيديوهات فقط بدون اشتراك. الاشتراك الشهري المحدود يضيف 4 فيديوهات إضافية، أما Plus والسنوي فغير محدودين.",
                      );
                      return;
                    }
                    final file = await mediaService.pickVideo();
                    if (file != null) {
                      final durationSeconds =
                          await _readVideoDurationSeconds(file);
                      if (!hasLimitedMonthlyPlan &&
                          !hasUnlimitedPlan &&
                          (durationSeconds ?? 0) >
                          _maxFreeVideoDurationSeconds) {
                        if (!screenContext.mounted) return;
                        await _showSubscriptionRequiredDialog(
                          screenContext,
                          message:
                              "مدة الفيديو يجب ألا تتجاوز دقيقة واحدة بدون اشتراك. الاشتراكات المدفوعة تسمح بفيديوهات أطول.",
                        );
                        return;
                      }
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

                      if (!screenContext.mounted) return;
                      _showUploadLoadingDialog(
                        screenContext,
                        "جاري رفع الفيديو...",
                      );
                      final success =
                          await mediaService.uploadVideo(
                        file,
                        caption,
                        durationSeconds: durationSeconds,
                      );
                      if (screenContext.mounted) {
                        Navigator.of(screenContext, rootNavigator: true).pop();
                      }
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
                      Icon(Icons.calendar_month, color: colors.primary),
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
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final authService = context.watch<AuthService>();
    final currentUser = authService.currentUser;
    final effectiveUser = widget.user ?? currentUser;

    if (effectiveUser == null) return const SizedBox();

    final bool isLoggedIn = authService.isAuthenticated && currentUser != null;
    final bool isOwner = isLoggedIn &&
        (effectiveUser.id.toString() == currentUser.id.toString());

    final User displayUser =
        isOwner ? currentUser : (_fullProfile ?? effectiveUser);
    final bool isCreator = displayUser.role == UserRole.creator;

    final bool showUpload = isOwner && isCreator;

    final List<Widget> tabs;
    final List<Widget> tabViews;

    if (isCreator) {
      tabs = const [
        Tab(text: "إعلاناتي"),
        Tab(text: "الصور"),
        Tab(text: "الفيديوهات"),
        Tab(text: "الجدول"),
      ];
      tabViews = [
        Align(alignment: Alignment.topCenter, child: ProfileMediaGrid(
            userId: displayUser.id,
            type: "Offer",
            isOwner: isOwner,
            refreshToken: _mediaReloadTick)),
        Align(alignment: Alignment.topCenter, child: ProfileMediaGrid(
            userId: displayUser.id,
            type: "Photo",
            isOwner: isOwner,
            refreshToken: _mediaReloadTick)),
        Align(alignment: Alignment.topCenter, child: ProfileMediaGrid(
            userId: displayUser.id,
            type: "Video",
            isOwner: isOwner,
            refreshToken: _mediaReloadTick)),
        Align(alignment: Alignment.topCenter, child: ProfileMediaGrid(
            userId: displayUser.id,
            type: "Event",
            isOwner: isOwner,
            refreshToken: _mediaReloadTick)),
      ];
    } else {
      tabs = const [
        Tab(text: "مشترياتي"),
        Tab(text: "محفوظات"),
      ];
      tabViews = [
        Align(alignment: Alignment.topCenter, child: ProfileMediaGrid(
            userId: displayUser.id,
            type: "Purchased",
            isOwner: isOwner,
            refreshToken: _mediaReloadTick)),
        Align(alignment: Alignment.topCenter, child: ProfileMediaGrid(
            userId: displayUser.id,
            type: "Saved",
            isOwner: isOwner,
            refreshToken: _mediaReloadTick)),
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

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        actions: [
          if (!isOwner && isLoggedIn)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(
                    right: 8.0, top: 8.0, bottom: 8.0),
                child: ElevatedButton(
                  onPressed: () => _toggleFollow(displayUser.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isFollowing ? colors.textTertiary : colors.info,
                    foregroundColor:
                        _isFollowing ? colors.background : colors.textPrimary,
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
                color: colors.background.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.flag_outlined, color: colors.textPrimary),
                onPressed: () => _showProfileReportDialog(displayUser),
              ),
            ),
          if (isOwner)
            Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.background.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.settings, color: colors.textPrimary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            EditProfileScreen(user: displayUser)),
                  );
                },
              ),
            ),
          if (isOwner && displayUser.isSuperadmin)
            Container(
              margin: const EdgeInsets.only(
                  right: 8.0, top: 8.0, bottom: 8.0),
              decoration: BoxDecoration(
                color: _isReloadingBadge
                    ? colors.primaryDark.withValues(alpha: 0.55)
                    : colors.primaryDark.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isReloadingBadge
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: colors.textPrimary),
                      )
                    : Icon(Icons.refresh, color: colors.textPrimary),
                tooltip: 'Reload superadmin badge',
                onPressed:
                    _isReloadingBadge ? null : _forceReloadSuperadminBadge,
              ),
            )
        ],
      ),
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 280,
              width: double.infinity,
              child: Stack(
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
                          colors.background.withValues(alpha: 0.7)
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
                                  Border.all(color: colors.textPrimary, width: 3),
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
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              displayUser.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          if ((displayUser.gender ?? '')
                                              .trim()
                                              .toLowerCase() == 'male')
                                            Icon(Icons.male,
                                                color: colors.primary,
                                                size: 20)
                                          else if ((displayUser.gender ?? '')
                                              .trim()
                                              .toLowerCase() == 'female')
                                            Icon(Icons.female,
                                                color: colors.accentPink,
                                                size: 20),
                                          if (displayUser.role == UserRole.creator)
                                            const SizedBox(width: 6),
                                          if (displayUser.role == UserRole.creator)
                                            Icon(Icons.verified,
                                                color: colors.info, size: 20),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              Text(
                                "@${displayUser.email.split('@')[0]}",
                                style: TextStyle(color: colors.textSecondary),
                              ),
                                if ((displayUser.role == UserRole.creator &&
                                        (displayUser.creatorLevelName ?? '')
                                            .trim()
                                            .isNotEmpty &&
                                        (displayUser.creatorLevelIcon ?? '')
                                            .trim()
                                            .isNotEmpty) ||
                                    displayUser.isSuperadmin) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      if (displayUser.role == UserRole.creator &&
                                          (displayUser.creatorLevelName ?? '')
                                              .trim()
                                              .isNotEmpty &&
                                          (displayUser.creatorLevelIcon ?? '')
                                              .trim()
                                              .isNotEmpty)
                                        _buildCreatorLevelBadge(
                                          icon: displayUser.creatorLevelIcon!.trim(),
                                          name: displayUser.creatorLevelName!.trim(),
                                        ),
                                      if (displayUser.isSuperadmin)
                                        _buildSuperadminBadgeIcon(
                                          iconUrl: displayUser.superadminBadgeIconUrl,
                                          label: displayUser.superadminBadgeLabel,
                                        ),
                                    ],
                                  ),
                                ],
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
                                  ],
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
            Padding(
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
                          TextStyle(color: colors.textTertiary, height: 1.4)),
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
                        Icon(Icons.location_on_outlined,
                            size: 18, color: colors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            serviceAreaLabel,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (isOwner && displayUser.isSuperadmin) ...[
                    const SizedBox(height: 14),
                    const Text(
                      "Superadmin badge debug",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      "imageStatus=${_debugLastImageStatus ?? 'not-rendered-yet'}\n"
                      "raw=${displayUser.superadminBadgeIconUrl ?? 'null'}\n"
                      "resolved=${_debugLastNormalizedUrl ?? 'null'}\n"
                      "badgeReloadTick=$_badgeReloadTick\n"
                      "reloadStatus=${_badgeReloadStatus ?? 'idle'}",
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      icon: _isReloadingBadge
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: colors.textPrimary),
                            )
                          : Icon(Icons.refresh, size: 14, color: colors.textPrimary),
                      label: Text(
                        _isReloadingBadge ? "Reloadar..." : "Force reload badge",
                        style: TextStyle(color: colors.textPrimary),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.textPrimary.withValues(alpha: 0.4)),
                      ),
                      onPressed:
                          _isReloadingBadge ? null : _forceReloadSuperadminBadge,
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
            _buildProfileTabBarRow(
              controller: _tabController,
              colors: colors,
              config: theme.config,
              showUpload: showUpload,
              onUpload: _handleUpload,
              tabs: tabs,
            ),
            tabViews[_tabController.index],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTabBarRow({
    required TabController controller,
    required dynamic colors,
    required dynamic config,
    required bool showUpload,
    VoidCallback? onUpload,
    required List<Widget> tabs,
  }) {
    const double actionSlotWidth = 60;
    return Container(
      color: colors.background,
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: actionSlotWidth,
                child: showUpload
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: config.effects.primaryGradient(colors.primary, colors.primaryDark),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(Icons.add_rounded,
                                color: colors.textPrimary, size: 24),
                            tooltip: 'إضافة',
                            onPressed: onUpload,
                            splashRadius: 22,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: TabBar(
                  controller: controller,
                  labelColor: colors.primaryLight,
                  unselectedLabelColor: colors.textSecondary,
                  indicatorColor: colors.primary,
                  overlayColor: WidgetStateProperty.all(
                    colors.primaryDark.withValues(alpha: 0.10),
                  ),
                  physics: const BouncingScrollPhysics(),
                  isScrollable: false,
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 8.0),
                  padding: EdgeInsets.zero,
                  tabs: tabs,
                ),
              ),
              const SizedBox(width: actionSlotWidth),
            ],
          ),
          const Divider(height: 1),
        ],
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

  Widget _buildCreatorLevelBadge({
    required String icon,
    required String name,
  }) {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.textPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.textPrimary.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuperadminBadgeIcon({
    required String? iconUrl,
    required String? label,
  }) {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final normalizedUrl = _normalizePublicMediaUrl(iconUrl ?? '');
    final tooltip = (label ?? '').trim().isEmpty ? 'سوبر أدمن' : label!.trim();
    final cacheBuster = _badgeReloadTick > 0 ? '?t=$_badgeReloadTick' : '';
    final imageUrl = normalizedUrl.isEmpty
        ? normalizedUrl
        : (normalizedUrl.contains('?')
            ? '$normalizedUrl&t=$_badgeReloadTick'
            : '$normalizedUrl$cacheBuster');
    // #region debug-point C:superadmin-badge-build
    _debugLastNormalizedUrl = imageUrl;
    debugPrint(
      "[DEBUG] buildSuperadminBadge C: rawIconUrl=$iconUrl "
      "normalizedUrl=$normalizedUrl imageUrl=$imageUrl badgeReloadTick=$_badgeReloadTick",
    );
    // #endregion

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 28,
        height: 28,
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                key: ValueKey('superadmin-badge-$imageUrl-$_badgeReloadTick'),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (frame != null || wasSynchronouslyLoaded) {
                    // #region debug-point B:superadmin-image-loaded
                    _debugLastImageStatus = 'loaded';
                    debugPrint(
                      "[DEBUG] superadmin badge image B: loaded url=$imageUrl frame=$frame sync=$wasSynchronouslyLoaded",
                    );
                    // #endregion
                  }
                  return child;
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.textSecondary,
                        value: progress.expectedTotalBytes == null
                            ? null
                            : progress.cumulativeBytesLoaded /
                                (progress.expectedTotalBytes ?? 1),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, error, stackTrace) {
                  // #region debug-point B:superadmin-image-error
                  _debugLastImageStatus = 'error';
                  debugPrint(
                    "[DEBUG] superadmin badge image B: error url=$imageUrl error=$error",
                  );
                  // #endregion
                  return Icon(
                    Icons.shield_rounded,
                    color: colors.textPrimary,
                    size: 22,
                  );
                },
              )
            : Builder(
                builder: (context) {
                  // #region debug-point B:superadmin-image-missing-url
                  _debugLastImageStatus = 'missing-url';
                  debugPrint(
                    "[DEBUG] superadmin badge image B: missing-url rawIconUrl=$iconUrl normalizedUrl=$normalizedUrl",
                  );
                  // #endregion
                  return Icon(
                    Icons.shield_rounded,
                    color: colors.textPrimary,
                    size: 22,
                  );
                },
              ),
      ),
    );
  }

  Widget _buildProfileMetaChip({
    required IconData icon,
    required String label,
  }) {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.textPrimary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.textPrimary,
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
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: tappable ? colors.primaryDark : null,
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
                style: TextStyle(color: colors.textTertiary, fontSize: 12)),
            if (tappable)
              Icon(Icons.arrow_forward_ios, size: 10, color: colors.info),
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

  String _normalizeMediaUrl(String raw) =>
      normalizePublicMediaUrl(raw);

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

  Color _calendarStatusColor(dynamic raw, RemoteThemeColors colors) {
    final status = raw?.toString().toLowerCase();
    if (status == 'busy') return colors.warning;
    if (status == 'booked') return colors.accentPink;
    return colors.primaryLight;
  }

  Color _calendarStatusBackground(dynamic raw, RemoteThemeColors colors) {
    final status = raw?.toString().toLowerCase();
    if (status == 'busy') return colors.warningBg;
    if (status == 'booked') return colors.errorBg;
    return colors.infoBg;
  }

  Widget _buildCalendarStatusChip({
    required String label,
    required IconData icon,
    required String status,
    required String currentStatus,
    required VoidCallback onTap,
    required RemoteThemeColors colors,
    required AppThemeConfig config,
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
          gradient: isSelected ? config.effects.primaryGradient(colors.primary, colors.primaryDark) : null,
          color: isSelected ? null : colors.surfaceLight,
          boxShadow: isSelected ? AppShadows.glowAccent : null,
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : colors.border.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colors.textPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700),
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

  Color _calendarStatusCardColor(String status, RemoteThemeColors colors) {
    if (status == 'busy') return colors.warningBg;
    return colors.errorBg;
  }

  Color _calendarStatusBorderColor(String status, RemoteThemeColors colors) {
    if (status == 'busy') return colors.warning.withValues(alpha: 0.45);
    return colors.accentPink.withValues(alpha: 0.45);
  }

  List<Map<String, dynamic>> _eventsForDay(
    DateTime day,
    Map<DateTime, List<Map<String, dynamic>>> grouped,
  ) {
    return grouped[_dayOnly(day)] ?? const [];
  }

  Widget _buildEventPreviewThumb(Map<String, dynamic> item, {double size = 18, required RemoteThemeColors colors}) {
    final previewUrl = _normalizeMediaUrl(item['cover_image_url']?.toString() ?? '');
    final isVideo = _isVideoUrl(previewUrl);
    if (previewUrl.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _calendarStatusBackground(item['calendar_status'], colors),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          _calendarStatusIcon(item['calendar_status']),
          size: size * 0.65,
          color: _calendarStatusColor(item['calendar_status'], colors),
        ),
      );
    }

    if (isVideo) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors.darkGradient),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          Icons.play_circle_fill_rounded,
          color: colors.textPrimary,
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
          color: colors.surfaceLight,
          child: Icon(Icons.image, color: colors.textSecondary, size: 12),
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
    required RemoteThemeColors colors,
    required AppThemeConfig config,
  }) {
    final primaryEvent = events.isNotEmpty ? events.first : null;
    final statusColor = primaryEvent == null
        ? Colors.transparent
        : _calendarStatusColor(primaryEvent['calendar_status'], colors);
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
                  color: isSelected ? colors.surfaceLight : colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? colors.accentPink.withValues(alpha: 0.85)
                        : hasEvent
                            ? statusColor.withValues(alpha: 0.45)
                            : colors.borderLight,
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
                                gradient: LinearGradient(
                                  colors: colors.accentGradient,
                                ),
                                boxShadow: AppShadows.glowAccent,
                              )
                            : null,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            color: colors.textPrimary,
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
                              : colors.textPrimary.withValues(alpha: 0.05),
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

  Widget _buildSelectedDayPanel(List<Map<String, dynamic>> events, RemoteThemeColors colors, AppThemeConfig config) {
    final selectedDay = _selectedDay ?? _dayOnly(DateTime.now());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderLight),
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
                    Text(
                      'تفاصيل اليوم',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fullDateLabel(selectedDay),
                      style: TextStyle(
                        color: colors.textSecondary,
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
                color: colors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.borderLight),
              ),
              child: Text(
                'لا توجد عناصر في هذا اليوم',
                style: TextStyle(color: colors.textSecondary),
              ),
            )
          else
            ...events.map(
              (item) {
                final previewUrl =
                    _normalizeMediaUrl(item['cover_image_url']?.toString() ?? '');
                final isVideo = _isVideoUrl(previewUrl);
                final statusColor = _calendarStatusColor(item['calendar_status'], colors);
                final statusBg = _calendarStatusBackground(item['calendar_status'], colors);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEventPreviewThumb(item, size: 54, colors: colors),
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
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (isVideo)
                                  Icon(
                                    Icons.videocam_rounded,
                                    size: 16,
                                    color: colors.textSecondary,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['title']?.toString().trim().isNotEmpty == true
                                  ? item['title'].toString().trim()
                                  : _calendarStatusLabel(item['calendar_status']),
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if ((item['location']?.toString().trim().isNotEmpty ??
                                false)) ...[
                              const SizedBox(height: 6),
                              Text(
                                item['location'].toString().trim(),
                                style: TextStyle(
                                  color: colors.primaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if ((item['notes']?.toString().trim().isNotEmpty ??
                                false)) ...[
                              const SizedBox(height: 6),
                              Text(
                                item['notes'].toString().trim(),
                                style: TextStyle(
                                  color: colors.textSecondary,
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
    final theme = context.read<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
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
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.borderLight),
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
                            colors: colors,
                            config: config,
                          ),
                          _buildCalendarStatusChip(
                            label: "مشغول",
                            icon: Icons.block,
                            status: 'busy',
                            currentStatus: selectedStatus,
                            onTap: () => setDialogState(() => selectedStatus = 'busy'),
                            colors: colors,
                            config: config,
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
                              leading: Icon(Icons.image, color: colors.info),
                              title: const Text("رفع صورة"),
                              onTap: () => Navigator.pop(sheetContext, "image"),
                            ),
                            ListTile(
                              leading: Icon(Icons.videocam, color: colors.error),
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
                    color: _calendarStatusCardColor(selectedStatus, colors),
                    border: Border.all(
                      color: _calendarStatusBorderColor(selectedStatus, colors),
                    ),
                  ),
                  child: Text(
                    selectedStatus == 'booked'
                        ? "سيظهر هذا اليوم للعميل كـ محجوز"
                        : "سيظهر هذا اليوم للعميل كـ مشغول",
                    style: TextStyle(
                      color: colors.textPrimary,
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
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, _didChange);
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: colors.background,
          elevation: 0,
          foregroundColor: colors.textPrimary,
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
                  style: TextStyle(color: colors.textSecondary),
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
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: colors.borderLight),
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
                            icon: Icon(Icons.chevron_left, color: colors.textPrimary),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'الأسبوع $weekNumber',
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _weekRangeLabel(_visibleWeekStart),
                                  style: TextStyle(
                                    color: colors.textSecondary,
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
                            icon: Icon(Icons.chevron_right, color: colors.textPrimary),
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
                              style: TextStyle(
                                color: colors.primaryLight,
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
                                  style: TextStyle(
                                    color: colors.textSecondary,
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
                              colors: colors,
                              config: config,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildSelectedDayPanel(selectedDayEvents, colors, config),
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

  Widget _buildVideoTile(RemoteThemeColors colors, AppThemeConfig config) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.darkGradient,
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.error.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned(
            bottom: -24,
            left: -16,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.borderLight,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_fill_rounded,
                    color: colors.textPrimary, size: 52),
                const SizedBox(height: 10),
                Text(
                  "فيديو",
                  style: TextStyle(
                    color: colors.textPrimary,
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
                color: colors.background.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.borderLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_rounded, color: colors.textPrimary, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    "HD",
                    style: TextStyle(
                      color: colors.textPrimary,
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

  String _normalizeMediaUrl(String raw) =>
      normalizePublicMediaUrl(raw);

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

  Color _calendarStatusColorGrid(dynamic raw, RemoteThemeColors colors) {
    final status = raw?.toString().toLowerCase();
    if (status == 'busy') return colors.warning;
    if (status == 'booked') return colors.accentPink;
    return colors.primaryLight;
  }

  Color _calendarStatusBackgroundGrid(dynamic raw, RemoteThemeColors colors) {
    final status = raw?.toString().toLowerCase();
    if (status == 'busy') return colors.warningBg;
    if (status == 'booked') return colors.errorBg;
    return colors.infoBg;
  }

  Widget _buildEventGridCard(dynamic rawItem, RemoteThemeColors colors, AppThemeConfig config) {
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
    final badgeColor = _calendarStatusColorGrid(item['calendar_status'], colors);
    final badgeBackground = _calendarStatusBackgroundGrid(item['calendar_status'], colors);

    return Card(
      color: colors.surface,
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors.darkGradient,
                ),
              ),
              child: Stack(
                children: [
                  if (hasPreview)
                    Positioned.fill(
                      child: isVideo
                          ? _buildVideoTile(colors, config)
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
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (formattedDate.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                color: colors.textSecondary,
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
                              style: TextStyle(
                                color: colors.primaryLight,
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
                              style: TextStyle(
                                color: colors.textSecondary,
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
                        icon: Icon(
                          Icons.more_vert,
                          size: 20,
                          color: colors.textSecondary,
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
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
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
          final emptyIcons = <String, IconData>{
            'Purchased': Icons.shopping_bag_outlined,
            'Saved': Icons.bookmark_border_rounded,
            'Offer': Icons.sell_outlined,
            'Photo': Icons.photo_library_outlined,
            'Video': Icons.ondemand_video_outlined,
            'Event': Icons.event_available_outlined,
          };
          final emptyTitlesAr = <String, String>{
            'Purchased': "لا توجد مشتريات بعد",
            'Saved': "لا توجد عناصر محفوظة حتى الآن",
            'Offer': "لا توجد عروض حتى الآن",
            'Photo': "لا توجد صور مرفوعة حتى الآن",
            'Video': "لا توجد فيديوهات مرفوعة حتى الآن",
            'Event': "لا توجد حجوزات مجدولة حتى الآن",
          };
          final emptyHintsAr = <String, String>{
            'Purchased': "ستظهر عروضك التي قمت بشرائها هنا.",
            'Saved': "اضغط على زر الحفظ داخل أي عرض لحفظه هنا.",
            'Offer': widget.isOwner
                ? "اضغط على زر الجمع بالأعلى لإنشاء أول عرض لك."
                : "لم يقم هذا المبدع بنشر أي عرض بعد.",
            'Photo': widget.isOwner
                ? "اضغط على زر الجمع بالأعلى لرفع أول صورة لك."
                : "لم يقم هذا المبدع برفع أي صور بعد.",
            'Video': widget.isOwner
                ? "اضغط على زر الجمع بالأعلى لرفع أول فيديو لك."
                : "لم يقم هذا المبدع برفع أي فيديوهات بعد.",
            'Event': widget.isOwner
                ? "اضغط على زر الجمع في علامة الجدول لإضافة مواعيد للحجوزات."
                : "لا توجد حجوزات لعرضها حاليا.",
          };
          const known = ['Purchased','Saved','Offer','Photo','Video','Event'];
          final typeKey = known.contains(widget.type) ? widget.type : 'Photo';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            child: Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.10),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                      emptyIcons[typeKey] ?? Icons.perm_media_outlined,
                      size: 44,
                      color: colors.primary),
                ),
                const SizedBox(height: 22),
                Text(
                    emptyTitlesAr[typeKey] ?? "لا يوجد محتوى بعد",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 10),
                Text(
                    emptyHintsAr[typeKey] ?? "",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.55,
                    )),
              ],
            )),
          );
        }

        final bool isOfferGrid =
            widget.type == "Offer" || widget.type == "Saved";

        final sw = MediaQuery.sizeOf(context).width;
        const cols = 2;
        const padL = 8.0, padR = 8.0, padTop = 6.0, padBot = 20.0;
        const crossSpc = 8.0, mainSpc = 8.0;
        final cardW = (sw - (padL + padR + crossSpc * (cols - 1))) / cols;
        final aspect = isOfferGrid
            ? 0.95
            : widget.type == "Event"
                ? 0.86
                : 0.75;
        final cardH = cardW / aspect;
        final rows = (items.length + cols - 1) ~/ cols;
        final totH = padTop +
            padBot +
            rows * cardH +
            (rows > 1 ? (rows - 1) * mainSpc : 0.0);

        return SizedBox(height: totH, child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: isOfferGrid
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
              return _buildEventGridCard(item, colors, config);
            }
            String imageUrl = "";
            String previewUrl = "";
            String title = "";
            String subtitle = "";
            bool isPreviewVideo = false;
            bool isGridVideo = false;

            bool showVideoBadge = false;

            if (isOfferGrid) {
              final offer = Offer.fromJson(
                Map<String, dynamic>.from(item as Map),
              );

              title = offer.title.isEmpty ? "No Title" : offer.title;
              subtitle = "${offer.price.toStringAsFixed(0)} IQD";

              final normalizedMedia = offer.mediaItems
                  .map(
                    (m) => OfferMediaItem(
                      rawUrl: m.rawUrl,
                      url: _normalizeMediaUrl(m.url),
                      type: m.type,
                    ),
                  )
                  .toList();

              showVideoBadge = normalizedMedia.any((m) => m.isVideo);
              final firstImage = normalizedMedia.firstWhere(
                (m) => !m.isVideo && m.url.trim().isNotEmpty,
                orElse: () => const OfferMediaItem(rawUrl: '', url: '', type: 'image'),
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
                            if (isOfferGrid) {
                              try {
                                final offer = Offer.fromJson(
                                  Map<String, dynamic>.from(item as Map),
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => OfferDetailsScreen(offer: offer),
                                  ),
                                );
                              } catch (e, stack) {
                                debugPrint(
                                    "❌ CreatorProfile grid Offer open error: $e\n$stack");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        "تعذر فتح العرض. الرجاء تحديث الصفحة."),
                                    action: SnackBarAction(
                                        label: 'تحديث',
                                        onPressed: () => setState(() {
                                              _loadFuture = _loadData();
                                            })),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
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
                            ? _buildVideoTile(colors, config)
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
                                          color: colors.background.withValues(alpha: 0.35),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                              color: colors.borderLight),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.videocam_rounded,
                                                color: colors.textPrimary, size: 12),
                                            const SizedBox(width: 4),
                                            Text(
                                              "HD",
                                              style: TextStyle(
                                                color: colors.textPrimary,
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
                                  style: TextStyle(
                                      color: colors.success, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                        if (widget.isOwner &&
                            (isOfferGrid ||
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
                            icon: Icon(Icons.flag_outlined,
                                size: 20, color: colors.error),
                            onPressed: () => _showReportDialog(item),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else if (!widget.isOwner && isOfferGrid)
                          IconButton(
                            icon: Icon(Icons.flag_outlined,
                                size: 20, color: colors.error),
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
        )); // GridView.builder + SizedBox(height: totH) STÄNGNING
      },
    );
  }

  void _showItemOptions(BuildContext context, dynamic item) {
    final theme = this.context.read<AppThemeService>();
    final colors = theme.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.background,
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
                  color: colors.textSecondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text("تعديل",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _handleEdit(item);
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.delete, color: colors.error),
                title: Text("حذف",
                    style: TextStyle(
                        color: colors.error,
                        fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  _handleDelete(item);
                },
              ),
              const SizedBox(height: 10),
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
    final theme = context.read<AppThemeService>();
    final colors = theme.colors;
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
            child: Text("حذف", style: TextStyle(color: colors.error)),
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

  Future<String?> _deleteOfferWithResult(
      MediaService service, String id) async {
    try {
      debugPrint("🔄 DELETE Offer id=$id → calling service.deleteOffer...");
      final res = await service.deleteOffer(id);
      debugPrint("✅ DELETE Offer id=$id → result success=$res");
      return res ? null : "Unauthorized or not found (API returned false).";
    } catch (e) {
      debugPrint("❌ DELETE Offer id=$id EXCEPTION: $e");
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

  Widget _buildVideo(RemoteThemeColors colors) {
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            _controller == null ||
            !_controller!.value.isInitialized) {
          return Center(
            child: CircularProgressIndicator(color: colors.textPrimary),
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
                  decoration: BoxDecoration(
                    color: colors.background.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: colors.textPrimary,
                    size: 44,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImage(RemoteThemeColors colors) {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4,
      child: Center(
        child: Image.network(
          widget.mediaUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return CircularProgressIndicator(color: colors.textPrimary);
          },
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.broken_image_outlined,
            color: colors.textPrimary,
            size: 56,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        title: Text(
          widget.title.isEmpty
              ? (widget.isVideo ? 'فيديو' : 'صورة')
              : widget.title,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: widget.isVideo ? _buildVideo(colors) : _buildImage(colors),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController controller;
  final bool showUpload;
  final VoidCallback? onUpload;
  final List<Widget> tabs;

  _SliverAppBarDelegate(
      {required this.controller,
      this.showUpload = false,
      this.onUpload,
      required this.tabs});

  @override
  double get minExtent => 48.0 + 1;
  @override
  double get maxExtent => 48.0 + 1;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = context.watch<AppThemeService>();
    final colors = theme.colors;
    final config = theme.config;
    const double actionSlotWidth = 60;
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: actionSlotWidth,
                child: showUpload
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: config.effects.primaryGradient(colors.primary, colors.primaryDark),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.25),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(Icons.add_rounded,
                                color: colors.textPrimary, size: 24),
                            tooltip: 'إضافة',
                            onPressed: onUpload,
                            splashRadius: 22,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: TabBar(
                  controller: controller,
                  labelColor: colors.primaryLight,
                  unselectedLabelColor: colors.textSecondary,
                  indicatorColor: colors.primary,
                  overlayColor: WidgetStateProperty.all(
                    colors.primaryDark.withValues(alpha: 0.10),
                  ),
                  physics: const BouncingScrollPhysics(),
                  isScrollable: false,
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 8.0),
                  padding: EdgeInsets.zero,
                  tabs: tabs,
                ),
              ),
              const SizedBox(width: actionSlotWidth),
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
