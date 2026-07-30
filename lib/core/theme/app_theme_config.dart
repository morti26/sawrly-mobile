import 'dart:math' as math;
import 'package:flutter/material.dart';

class RemoteThemeColors {
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color accentPink;
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color menuBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color border;
  final Color borderLight;

  const RemoteThemeColors({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.accentPink,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.menuBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.border,
    required this.borderLight,
  });

  List<Color> get primaryGradient => [primary, primaryDark];
  List<Color> get accentGradient => [accentPink, primaryDark];
  List<Color> get darkGradient => [background, primaryDark];

  Color get successBg => Color.lerp(background, success, 0.12) ?? background;
  Color get warningBg => Color.lerp(background, warning, 0.12) ?? background;
  Color get errorBg => Color.lerp(background, error, 0.12) ?? background;
  Color get infoBg => Color.lerp(background, info, 0.12) ?? background;
}

class RemoteNavIcons {
  final String? home;
  final String? search;
  final String? categories;
  final String? orders;
  final String? profile;
  final String? homeActive;
  final String? searchActive;
  final String? categoriesActive;
  final String? ordersActive;
  final String? profileActive;

  const RemoteNavIcons({
    this.home,
    this.search,
    this.categories,
    this.orders,
    this.profile,
    this.homeActive,
    this.searchActive,
    this.categoriesActive,
    this.ordersActive,
    this.profileActive,
  });
}

class RemoteThemeEffects {
  final double primaryGradientAngle;
  final double cardRadius;
  final double chipRadius;
  final double buttonRadius;
  final double navShadowOpacity;
  final double cardShadowOpacity;
  final double activeGlowOpacity;
  final double glassBlur;
  final double surfaceOpacity;
  final double borderOpacity;

  const RemoteThemeEffects({
    required this.primaryGradientAngle,
    required this.cardRadius,
    required this.chipRadius,
    required this.buttonRadius,
    required this.navShadowOpacity,
    required this.cardShadowOpacity,
    required this.activeGlowOpacity,
    required this.glassBlur,
    required this.surfaceOpacity,
    required this.borderOpacity,
  });

  AlignmentGeometry get gradientBegin => _angleToAlignment(primaryGradientAngle).$1;
  AlignmentGeometry get gradientEnd => _angleToAlignment(primaryGradientAngle).$2;

  static (AlignmentGeometry, AlignmentGeometry) _angleToAlignment(double degrees) {
    final rad = degrees * math.pi / 180;
    final dx = math.sin(rad);
    final dy = -math.cos(rad);
    return (
      Alignment(-dx.clamp(-1.0, 1.0), -dy.clamp(-1.0, 1.0)),
      Alignment(dx.clamp(-1.0, 1.0), dy.clamp(-1.0, 1.0)),
    );
  }

  LinearGradient primaryGradient(Color primary, Color primaryDark) {
    return LinearGradient(
      begin: gradientBegin,
      end: gradientEnd,
      colors: [primary, primaryDark],
    );
  }
}

class AppThemeConfig {
  final RemoteThemeColors colors;
  final RemoteNavIcons navIcons;
  final RemoteThemeEffects effects;

  const AppThemeConfig({
    required this.colors,
    required this.navIcons,
    required this.effects,
  });
}

Color? _parseHexColor(dynamic raw) {
  if (raw is! String) return null;
  String v = raw.trim();
  if (v.isEmpty) return null;
  if (!v.startsWith('#')) return null;
  final String body = v.substring(1);
  final int? value = int.tryParse(
    body.length == 3
        ? body.split('').map((c) => '$c$c').join()
        : body.length == 6
            ? 'FF$body'
            : body.length == 8
                ? body
                : '',
    radix: 16,
  );
  if (value == null) return null;
  return Color(value);
}

RemoteThemeColors parseRemoteColors(dynamic raw) {
  const defaults = _DefaultAppTheme.colors;
  Map<String, dynamic>? map;
  if (raw is Map<String, dynamic>) {
    map = raw;
  } else if (raw is Map) {
    map = Map<String, dynamic>.from(raw);
  }
  if (map == null) return defaults;
  Color pick(String key, Color fallback) {
    final Object? v = map![key];
    return _parseHexColor(v) ?? fallback;
  }

  return RemoteThemeColors(
    primary: pick('primary', defaults.primary),
    primaryLight: pick('primaryLight', defaults.primaryLight),
    primaryDark: pick('primaryDark', defaults.primaryDark),
    accentPink: pick('accentPink', defaults.accentPink),
    background: pick('background', defaults.background),
    surface: pick('surface', defaults.surface),
    surfaceLight: pick('surfaceLight', defaults.surfaceLight),
    menuBackground: pick('menuBackground', defaults.menuBackground),
    textPrimary: pick('textPrimary', defaults.textPrimary),
    textSecondary: pick('textSecondary', defaults.textSecondary),
    textTertiary: pick('textTertiary', defaults.textTertiary),
    success: pick('success', defaults.success),
    warning: pick('warning', defaults.warning),
    error: pick('error', defaults.error),
    info: pick('info', defaults.info),
    border: pick('border', defaults.border),
    borderLight: pick('borderLight', defaults.borderLight),
  );
}

RemoteNavIcons parseRemoteNavIcons(dynamic raw) {
  Map<Object?, Object?>? map;
  if (raw is Map) map = raw as Map<Object?, Object?>;
  if (raw is Map<String, dynamic>) map = raw;
  String? s(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  if (map == null) return const RemoteNavIcons();
  return RemoteNavIcons(
    home: s(map['home']),
    search: s(map['search']),
    categories: s(map['categories']),
    orders: s(map['orders']),
    profile: s(map['profile']),
    homeActive: s(map['homeActive']),
    searchActive: s(map['searchActive']),
    categoriesActive: s(map['categoriesActive']),
    ordersActive: s(map['ordersActive']),
    profileActive: s(map['profileActive']),
  );
}

double _parseDouble(dynamic raw, double fallback, {double? min, double? max}) {
  double? parsed;
  if (raw is num) {
    parsed = raw.toDouble();
  } else if (raw is String) {
    parsed = double.tryParse(raw.trim());
  }
  if (parsed == null || !parsed.isFinite) return fallback;
  if (min != null && parsed < min) return fallback;
  if (max != null && parsed > max) return fallback;
  return parsed;
}

RemoteThemeEffects parseRemoteEffects(dynamic raw) {
  const defaults = _DefaultAppTheme.effects;
  Map<String, dynamic>? map;
  if (raw is Map<String, dynamic>) {
    map = raw;
  } else if (raw is Map) {
    map = Map<String, dynamic>.from(raw);
  }
  if (map == null) return defaults;
  double pick(String key, double fb, {double? min, double? max}) {
    return _parseDouble(map![key], fb, min: min, max: max);
  }

  return RemoteThemeEffects(
    primaryGradientAngle: pick('primaryGradientAngle', defaults.primaryGradientAngle, min: 0, max: 360),
    cardRadius: pick('cardRadius', defaults.cardRadius, min: 0, max: 60),
    chipRadius: pick('chipRadius', defaults.chipRadius, min: 0, max: 9999),
    buttonRadius: pick('buttonRadius', defaults.buttonRadius, min: 0, max: 60),
    navShadowOpacity: pick('navShadowOpacity', defaults.navShadowOpacity, min: 0, max: 1),
    cardShadowOpacity: pick('cardShadowOpacity', defaults.cardShadowOpacity, min: 0, max: 1),
    activeGlowOpacity: pick('activeGlowOpacity', defaults.activeGlowOpacity, min: 0, max: 1),
    glassBlur: pick('glassBlur', defaults.glassBlur, min: 0, max: 60),
    surfaceOpacity: pick('surfaceOpacity', defaults.surfaceOpacity, min: 0.2, max: 1),
    borderOpacity: pick('borderOpacity', defaults.borderOpacity, min: 0, max: 1),
  );
}

class _DefaultAppTheme {
  static const RemoteThemeColors colors = RemoteThemeColors(
    primary: Color(0xFF9B4DFF),
    primaryLight: Color(0xFFC48CFF),
    primaryDark: Color(0xFF7230CC),
    accentPink: Color(0xFFFF4DA6),
    background: Color(0xFF46205A),
    surface: Color(0xFF57246F),
    surfaceLight: Color(0xFF6F2E8E),
    menuBackground: Color(0xFF421B54),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0B0B0),
    textTertiary: Color(0xFF707070),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF3B82F6),
    border: Color(0xFF7B469C),
    borderLight: Color(0xFF5E2B79),
  );

  static const RemoteThemeEffects effects = RemoteThemeEffects(
    primaryGradientAngle: 135,
    cardRadius: 16,
    chipRadius: 999,
    buttonRadius: 12,
    navShadowOpacity: 0.18,
    cardShadowOpacity: 0.12,
    activeGlowOpacity: 0.22,
    glassBlur: 14,
    surfaceOpacity: 0.85,
    borderOpacity: 0.45,
  );
}
