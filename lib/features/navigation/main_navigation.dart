import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/design/design_tokens.dart';
import '../../core/theme/app_theme_config.dart';
import '../../core/theme/app_theme_service.dart';
import '../auth/protected_screen.dart';
import '../categories/categories_screen.dart';
import '../home/home_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';
import '../search/global_search_screen.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int? _pressedIndex;

  final List<Widget> _screens = [
    const HomeScreen(),
    const GlobalSearchScreen(),
    const CategoriesScreen(),
    const ProtectedScreen(
      title: '\u062d\u062c\u0648\u0632\u0627\u062a\u064a',
      child: OrdersScreen(),
    ),
    const ProtectedScreen(
      title: '\u0627\u0644\u0628\u0631\u0648\u0641\u0627\u064a\u0644',
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

  final List<IconData> _webIcons = [
    Icons.home_outlined,
    Icons.search_rounded,
    Icons.grid_view_rounded,
    Icons.shopping_bag_outlined,
    Icons.person_outline_rounded,
  ];

  final List<String> _labels = const [
    '\u0627\u0644\u0631\u0626\u064a\u0633\u064a\u0629',
    '\u0628\u062d\u062b',
    '\u0627\u0644\u0623\u0642\u0633\u0627\u0645',
    '\u062d\u062c\u0648\u0632\u0627\u062a\u064a',
    '\u0627\u0644\u0628\u0631\u0648\u0641\u0627\u064a\u0644',
  ];

  IconData _fallbackIcon(int index) =>
      kIsWeb ? _webIcons[index] : _icons[index];

  String? _navIconUrlForIndex(RemoteNavIcons navIcons, int index,
      {required bool active}) {
    switch (index) {
      case 0:
        return active ? navIcons.homeActive ?? navIcons.home : navIcons.home;
      case 1:
        return active
            ? navIcons.searchActive ?? navIcons.search
            : navIcons.search;
      case 2:
        return active
            ? navIcons.categoriesActive ?? navIcons.categories
            : navIcons.categories;
      case 3:
        return active
            ? navIcons.ordersActive ?? navIcons.orders
            : navIcons.orders;
      case 4:
        return active
            ? navIcons.profileActive ?? navIcons.profile
            : navIcons.profile;
    }
    return null;
  }

  String? _navIconIdForIndex(RemoteNavIcons navIcons, int index,
      {required bool active}) {
    switch (index) {
      case 0:
        return active
            ? navIcons.homeActiveId ?? navIcons.homeId
            : navIcons.homeId;
      case 1:
        return active
            ? navIcons.searchActiveId ?? navIcons.searchId
            : navIcons.searchId;
      case 2:
        return active
            ? navIcons.categoriesActiveId ?? navIcons.categoriesId
            : navIcons.categoriesId;
      case 3:
        return active
            ? navIcons.ordersActiveId ?? navIcons.ordersId
            : navIcons.ordersId;
      case 4:
        return active
            ? navIcons.profileActiveId ?? navIcons.profileId
            : navIcons.profileId;
    }
    return null;
  }

  IconData? _resolveNavIcon(RemoteNavIcons navIcons, int index,
      {required bool active}) {
    if (kIsWeb) return null;
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
        final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            fit: StackFit.expand,
            children: [
              IndexedStack(
                index: _currentIndex,
                children: _screens,
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: bottomInset + 5,
                child: _buildVersionNineNavBar(themeService),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The original version-9 menu. Its geometry and navigation stay intact;
  /// only its material treatment follows the active premium theme.
  Widget _buildVersionNineNavBar(AppThemeService theme) {
    final premium = PremiumDesignTokens.from(theme.config);
    return ClipRRect(
      borderRadius: BorderRadius.circular(premium.radiusFloating),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.alphaBlend(
                  Colors.white.withValues(alpha: .18),
                  premium.glassSurface,
                ).withValues(alpha: .38),
                Color.alphaBlend(
                  Colors.white.withValues(alpha: .08),
                  premium.backgroundDeep,
                ).withValues(alpha: .24),
              ],
            ),
            borderRadius: BorderRadius.circular(premium.radiusFloating),
            border: Border.all(
              color: Colors.white.withValues(alpha: .13),
              width: .8,
            ),
            boxShadow: [
              BoxShadow(
                color: premium.shadowColor.withValues(alpha: .12),
                blurRadius: 14,
                spreadRadius: -5,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              _icons.length,
              (index) => _buildVersionNineItem(theme, index),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVersionNineItem(AppThemeService theme, int index) {
    final premium = PremiumDesignTokens.from(theme.config);
    final isActive = _currentIndex == index;
    final label = _labels[index];

    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: label,
        child: Tooltip(
          message: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressedIndex = index),
            onTapCancel: () => setState(() => _pressedIndex = null),
            onTapUp: (_) {
              setState(() {
                _currentIndex = index;
                _pressedIndex = null;
              });
            },
            child: AnimatedScale(
              scale: _pressedIndex == index ? .90 : 1,
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOutCubic,
              child: AnimatedSlide(
                offset: isActive ? const Offset(0, -.035) : Offset.zero,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                child: SizedBox(
                  height: 54,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 340),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: .72, end: 1)
                                .animate(animation),
                            child: child,
                          ),
                        ),
                        child: isActive
                            ? KeyedSubtree(
                                key: ValueKey('active-$index'),
                                child:
                                    _buildVersionNineActiveIcon(theme, index),
                              )
                            : KeyedSubtree(
                                key: ValueKey('inactive-$index'),
                                child:
                                    _buildVersionNineInactiveIcon(theme, index),
                              ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9.5,
                          height: 1,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.w600,
                          color: isActive
                              ? premium.accentPrimary
                              : premium.textPrimary.withValues(alpha: .68),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVersionNineActiveIcon(AppThemeService theme, int index) {
    final premium = PremiumDesignTokens.from(theme.config);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .07),
            premium.accentPrimary.withValues(alpha: .24),
            premium.accentSoft.withValues(alpha: .12),
            premium.surfacePrimary.withValues(alpha: .42),
          ],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: premium.accentPrimary.withValues(alpha: .42),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: premium.accentPrimary.withValues(alpha: .14),
            blurRadius: 13,
            spreadRadius: -1,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: premium.accentSoft.withValues(alpha: .08),
            blurRadius: 22,
            spreadRadius: 1,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 6,
                right: 10,
                top: 3,
                child: Container(
                  height: 7,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: .24),
                        Colors.white.withValues(alpha: .02),
                      ],
                    ),
                  ),
                ),
              ),
              _buildMenuGlyph(theme, index, active: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionNineInactiveIcon(AppThemeService theme, int index) {
    return SizedBox(
      width: 25,
      height: 25,
      child: Center(child: _buildMenuGlyph(theme, index, active: false)),
    );
  }

  Widget _buildMenuGlyph(AppThemeService theme, int index,
      {required bool active}) {
    final premium = PremiumDesignTokens.from(theme.config);
    final color = active
        ? premium.accentPrimary
        : premium.textPrimary.withValues(alpha: .68);
    final size = active ? 23.0 : 22.0;
    final navIcons = theme.navIcons;
    final customUrl = _navIconUrlForIndex(navIcons, index, active: active);
    final resolvedUrl =
        (!kIsWeb && customUrl != null) ? _normalizePublicUrl(customUrl) : null;
    final resolvedIcon = _resolveNavIcon(navIcons, index, active: active);

    if (resolvedIcon != null) {
      return Icon(resolvedIcon, color: color, size: size);
    }
    if (resolvedUrl != null) {
      return Image.network(
        resolvedUrl,
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) =>
            Icon(_fallbackIcon(index), color: color, size: size),
      );
    }
    return Icon(_fallbackIcon(index), color: color, size: size);
  }
}
