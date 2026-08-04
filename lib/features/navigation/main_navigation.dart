import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme_service.dart';
import '../../core/theme/app_theme_config.dart';
import '../home/home_screen.dart';
import '../search/global_search_screen.dart';
import '../categories/categories_screen.dart';
import '../profile/profile_screen.dart';
import '../auth/protected_screen.dart';
import '../orders/orders_screen.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const GlobalSearchScreen(),
    const CategoriesScreen(),
    const ProtectedScreen(
      title: 'حجوزاتي',
      child: OrdersScreen(),
    ),
    const ProtectedScreen(
      title: 'البروفايل',
      child: ProfileScreen(),
    ),
  ];

  final List<IconData> _icons = [
    PhosphorIconsRegular.house,
    PhosphorIconsRegular.magnifyingGlass,
    PhosphorIconsRegular.squaresFour,
    PhosphorIconsRegular.shoppingBag,
    PhosphorIconsRegular.user,
  ];

  static const int _fabIndex = 2;

  String? _navIconUrlForIndex(RemoteNavIcons navIcons, int index, {required bool active}) {
    switch (index) {
      case 0:
        return active ? navIcons.homeActive ?? navIcons.home : navIcons.home;
      case 1:
        return active ? navIcons.searchActive ?? navIcons.search : navIcons.search;
      case 2:
        return active
            ? navIcons.categoriesActive ?? navIcons.categories
            : navIcons.categories;
      case 3:
        return active ? navIcons.ordersActive ?? navIcons.orders : navIcons.orders;
      case 4:
        return active ? navIcons.profileActive ?? navIcons.profile : navIcons.profile;
    }
    return null;
  }

  String? _navIconIdForIndex(RemoteNavIcons navIcons, int index, {required bool active}) {
    switch (index) {
      case 0:
        return active ? navIcons.homeActiveId ?? navIcons.homeId : navIcons.homeId;
      case 1:
        return active ? navIcons.searchActiveId ?? navIcons.searchId : navIcons.searchId;
      case 2:
        return active
            ? navIcons.categoriesActiveId ?? navIcons.categoriesId
            : navIcons.categoriesId;
      case 3:
        return active ? navIcons.ordersActiveId ?? navIcons.ordersId : navIcons.ordersId;
      case 4:
        return active ? navIcons.profileActiveId ?? navIcons.profileId : navIcons.profileId;
    }
    return null;
  }

  IconData? _resolveNavIcon(RemoteNavIcons navIcons, int index, {required bool active}) {
    final rawId = _navIconIdForIndex(navIcons, index, active: active);
    if (rawId == null) return null;
    final parsed = parsePhosphorIconId(rawId);
    if (parsed == null) return null;
    return resolvePhosphorIcon(parsed.name, parsed.weight);
  }

  String _normalizePublicUrl(String raw) {
    if (raw.trim().isEmpty) return raw;
    String url = raw.trim();
    if (url.startsWith('/')) {
      url = 'https://sawrly.com$url';
    } else if (url.startsWith('http://10.0.2.2:') ||
        url.startsWith('http://127.0.0.1:') ||
        url.startsWith('http://localhost:')) {
      const host = 'http://10.0.2.2:3000';
      final pathIndex = url.indexOf('/', 8);
      final rest = pathIndex >= 0 ? url.substring(pathIndex) : '';
      url = '$host$rest';
    }
    return url;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex.clamp(0, _screens.length - 1);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AppThemeService>().loadFromServer(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppThemeService>(
      builder: (context, themeService, child) {
        return Scaffold(
          extendBody: true,
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: _buildFloatingNavBar(themeService),
        );
      },
    );
  }

  Widget _buildFloatingNavBar(AppThemeService theme) {
    final c = theme.colors;
    final e = theme.effects;
    final navRadius = BorderRadius.circular(14);
    final activeOpacity = e.activeGlowOpacity.clamp(0.0, 1.0);
    final navShadow = e.navShadowOpacity.clamp(0.0, 1.0);

    final activeGlow = [
      BoxShadow(
        color: c.primary.withValues(alpha: activeOpacity * 0.7),
        blurRadius: 18,
        spreadRadius: 1,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: c.primaryLight.withValues(alpha: activeOpacity * 0.4),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ];

    final navOuterShadow = [
      BoxShadow(
        color: Colors.black.withValues(alpha: navShadow),
        blurRadius: 26,
        offset: const Offset(0, -8),
      ),
      BoxShadow(
        color: c.primary.withValues(alpha: navShadow * 0.4),
        blurRadius: 14,
        offset: const Offset(0, -2),
      ),
    ];

    return SafeArea(
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 22, right: 22, bottom: 16),
        child: RepaintBoundary(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: navRadius,
                  boxShadow: navOuterShadow,
                ),
                child: ClipRRect(
                  borderRadius: navRadius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: e.glassBlur,
                      sigmaY: e.glassBlur,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.menuBackground.withValues(alpha: e.surfaceOpacity),
                        borderRadius: navRadius,
                        border: Border.all(
                          color: c.primaryLight.withValues(alpha: e.borderOpacity.clamp(0, 0.8)),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          _icons.length,
                          (i) => i == _fabIndex
                              ? const SizedBox(width: 56, height: 64)
                              : _buildNavItem(theme, i, activeGlow),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -22,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildCenterFab(theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterFab(AppThemeService theme) {
    final c = theme.colors;
    final isPressed = _currentIndex == _fabIndex;
    final pressedScale = isPressed ? 0.94 : 1.0;
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = _fabIndex);
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        scale: pressedScale,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c.primaryLight,
                c.primary,
                c.primaryDark,
              ],
            ),
            border: Border.all(
              color: c.primaryLight.withValues(alpha: 0.7),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: c.primary.withValues(alpha: 0.55),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: c.primaryLight.withValues(alpha: 0.3),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            isPressed ? PhosphorIconsFill.squaresFour : PhosphorIconsBold.plus,
            color: Colors.white,
            size: isPressed ? 24 : 28,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(AppThemeService theme, int index, List<BoxShadow> activeGlow) {
    final isActive = _currentIndex == index;
    return SizedBox(
      width: 56,
      height: 64,
      child: InkWell(
        onTap: () {
          if (_currentIndex == index) {
            return;
          }
          setState(() => _currentIndex = index);
        },
        borderRadius: BorderRadius.circular(14),
        child: Center(
          child: isActive
              ? _buildActiveIcon(theme, index, activeGlow)
              : _buildInactiveIcon(theme, index),
        ),
      ),
    );
  }

  Widget _buildActiveIcon(AppThemeService theme, int index, List<BoxShadow> activeGlow) {
    final c = theme.colors;
    final e = theme.effects;
    final navIcons = theme.navIcons;
    final customUrl = _navIconUrlForIndex(navIcons, index, active: true);
    final resolvedUrl = customUrl != null ? _normalizePublicUrl(customUrl) : null;
    final resolvedIcon = _resolveNavIcon(navIcons, index, active: true);
    final activeRadius = BorderRadius.circular(13);
    const iconSize = 21.0;

    Widget iconChild;
    if (resolvedIcon != null) {
      iconChild = Icon(
        resolvedIcon,
        color: c.primaryLight,
        size: iconSize,
      );
    } else if (resolvedUrl != null) {
      iconChild = Padding(
        padding: const EdgeInsets.all(7),
        child: Image.network(
          resolvedUrl,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Icon(
            _icons[index],
            color: c.primaryLight,
            size: iconSize,
          ),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: c.primaryLight,
                  value: progress.expectedTotalBytes == null
                      ? null
                      : progress.cumulativeBytesLoaded /
                          (progress.expectedTotalBytes ?? 1),
                ),
              ),
            );
          },
        ),
      );
    } else {
      iconChild = Icon(
        _icons[index],
        color: c.primaryLight,
        size: iconSize,
      );
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: e.primaryGradient(c.primary.withValues(alpha: 0.35), c.primaryDark.withValues(alpha: 0.18)),
        borderRadius: activeRadius,
        border: Border.all(
          color: c.primaryLight.withValues(alpha: 0.72),
          width: 1.3,
        ),
        boxShadow: activeGlow,
      ),
      child: Center(child: iconChild),
    );
  }

  Widget _buildInactiveIcon(AppThemeService theme, int index) {
    final c = theme.colors;
    final navIcons = theme.navIcons;
    final customUrl = _navIconUrlForIndex(navIcons, index, active: false);
    final resolvedUrl = customUrl != null ? _normalizePublicUrl(customUrl) : null;
    final resolvedIcon = _resolveNavIcon(navIcons, index, active: false);
    final iconColor = c.textPrimary.withValues(alpha: 0.55);
    const iconSize = 22.0;

    if (resolvedIcon != null) {
      return Icon(
        resolvedIcon,
        color: iconColor,
        size: iconSize,
      );
    }
    if (resolvedUrl != null) {
      return SizedBox(
        width: 26,
        height: 26,
        child: Image.network(
          resolvedUrl,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (_, __, ___) => Icon(
            _icons[index],
            color: iconColor,
            size: iconSize,
          ),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: iconColor,
                  value: progress.expectedTotalBytes == null
                      ? null
                      : progress.cumulativeBytesLoaded /
                          (progress.expectedTotalBytes ?? 1),
                ),
              ),
            );
          },
        ),
      );
    }
    return Icon(
      _icons[index],
      color: iconColor,
      size: iconSize,
    );
  }
}
