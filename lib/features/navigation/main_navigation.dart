import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/design/design_tokens.dart';
import '../../core/theme/app_theme_config.dart';
import '../../core/theme/app_theme_service.dart';
import '../../core/localization/app_locale_service.dart';
import '../../core/localization/app_strings.dart';
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
    PhosphorIconsRegular.calendarBlank,
    PhosphorIconsRegular.person,
  ];

  final List<IconData> _activeIcons = [
    PhosphorIconsFill.house,
    PhosphorIconsFill.magnifyingGlass,
    PhosphorIconsFill.squaresFour,
    PhosphorIconsFill.calendarBlank,
    PhosphorIconsFill.person,
  ];

  List<String> get _labels => [
        AppStrings.home,
        AppStrings.search,
        AppStrings.categories,
        AppStrings.bookings,
        AppStrings.profile,
      ];

  IconData _fallbackIcon(int index, {required bool active}) =>
      active ? _activeIcons[index] : _icons[index];

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
    // Watching the locale makes the labels and direction update immediately.
    context.watch<AppLocaleService>();
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
    // Keep the original bottom-menu geometry and ordering regardless of the
    // selected app language. Only the labels are localized.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ClipRRect(
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / _icons.length;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      left: (_currentIndex * itemWidth) + 9,
                      top: 8,
                      width: itemWidth - 18,
                      height: 38,
                      child: _buildSlidingHighlight(premium),
                    ),
                    Row(
                      children: List.generate(
                        _icons.length,
                        (index) => _buildVersionNineItem(theme, index),
                      ),
                    ),
                  ],
                );
              },
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
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: .82, end: 1)
                                .animate(animation),
                            child: child,
                          ),
                        ),
                        child: SizedBox(
                          key: ValueKey(
                              '${isActive ? 'filled' : 'outline'}-$index'),
                          width: 27,
                          height: 27,
                          child: Center(
                            child:
                                _buildMenuGlyph(theme, index, active: isActive),
                          ),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        label,
                        textAlign: index == 0 ? TextAlign.center : null,
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

  Widget _buildSlidingHighlight(PremiumDesignTokens premium) {
    return DecoratedBox(
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
            offset: const Offset(0, -2),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGlyph(AppThemeService theme, int index,
      {required bool active}) {
    final premium = PremiumDesignTokens.from(theme.config);
    final color = active
        ? premium.accentPrimary
        : premium.textPrimary.withValues(alpha: .68);
    final size = active ? 23.0 : 22.0;

    // The profile reference uses a small, detached head over a single curved
    // shoulder line rather than a large person silhouette.
    if (index == 4) {
      return _ProfileGlyph(
        color: color,
        active: active,
        size: size,
      );
    }

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
        errorBuilder: (_, __, ___) => Icon(_fallbackIcon(index, active: active),
            color: color, size: size),
      );
    }
    return Icon(_fallbackIcon(index, active: active), color: color, size: size);
  }
}

class _ProfileGlyph extends StatelessWidget {
  final Color color;
  final bool active;
  final double size;

  const _ProfileGlyph({
    required this.color,
    required this.active,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ProfileGlyphPainter(color: color, active: active),
      ),
    );
  }
}

class _ProfileGlyphPainter extends CustomPainter {
  final Color color;
  final bool active;

  const _ProfileGlyphPainter({required this.color, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final headPaint = Paint()
      ..color = color
      ..style = active ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = active ? 1.6 : 1.45
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final center = Offset(size.width * .5, size.height * .28);
    canvas.drawCircle(center, size.width * .17, headPaint);

    final shoulderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = active ? 2.2 : 1.65
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final shoulders = Path()
      ..moveTo(size.width * .18, size.height * .84)
      ..cubicTo(
        size.width * .25,
        size.height * .62,
        size.width * .75,
        size.height * .62,
        size.width * .82,
        size.height * .84,
      );
    canvas.drawPath(shoulders, shoulderPaint);
  }

  @override
  bool shouldRepaint(covariant _ProfileGlyphPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.active != active;
}
