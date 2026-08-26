import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

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
  final Color heroStart;
  final Color heroMid;
  final Color heroEnd;

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
    required this.heroStart,
    required this.heroMid,
    required this.heroEnd,
  });

  List<Color> get primaryGradient => [primary, primaryDark];
  List<Color> get accentGradient => [accentPink, primaryDark];
  List<Color> get darkGradient => [background, primaryDark];
  List<Color> get backgroundGradient => [heroStart, heroMid, heroEnd];

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
  final String? homeId;
  final String? searchId;
  final String? categoriesId;
  final String? ordersId;
  final String? profileId;
  final String? homeActiveId;
  final String? searchActiveId;
  final String? categoriesActiveId;
  final String? ordersActiveId;
  final String? profileActiveId;

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
    this.homeId,
    this.searchId,
    this.categoriesId,
    this.ordersId,
    this.profileId,
    this.homeActiveId,
    this.searchActiveId,
    this.categoriesActiveId,
    this.ordersActiveId,
    this.profileActiveId,
  });
}

class ThemeGlow {
  final Color color;
  final double x;
  final double y;
  final double radius;
  final double opacity;
  const ThemeGlow(
      {required this.color,
      required this.x,
      required this.y,
      required this.radius,
      required this.opacity});
}

class RemoteThemeVisuals {
  final bool meshEnabled;
  final List<ThemeGlow> meshPoints;
  final List<ThemeGlow> ambientGlows;
  final Color cardTint;
  final Color headerTint;
  final Color navigationTint;
  final String headerStyle;
  final bool noiseEnabled;
  final double noiseOpacity;
  final bool vignetteEnabled;
  final double vignetteStrength;
  const RemoteThemeVisuals(
      {this.meshEnabled = false,
      this.meshPoints = const [],
      this.ambientGlows = const [],
      this.cardTint = Colors.transparent,
      this.headerTint = Colors.transparent,
      this.navigationTint = Colors.transparent,
      this.headerStyle = 'gradient',
      this.noiseEnabled = false,
      this.noiseOpacity = 0.0,
      this.vignetteEnabled = false,
      this.vignetteStrength = 0.0});
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

  AlignmentGeometry get gradientBegin =>
      _angleToAlignment(primaryGradientAngle).$1;
  AlignmentGeometry get gradientEnd =>
      _angleToAlignment(primaryGradientAngle).$2;

  static (AlignmentGeometry, AlignmentGeometry) _angleToAlignment(
      double degrees) {
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

/// Versioned Style DNA sent by Theme Studio. Defaults preserve v1 themes.
class RemoteStyleDNA {
  final int schemaVersion;
  final double darkness;
  final double contrast;
  final double accentStrength;
  final double glassStrength;
  final double ambientLight;
  final double vignetteStrength;
  final double radiusStyle;

  const RemoteStyleDNA({
    this.schemaVersion = 1,
    this.darkness = .82,
    this.contrast = .74,
    this.accentStrength = .18,
    this.glassStrength = .54,
    this.ambientLight = .18,
    this.vignetteStrength = .22,
    this.radiusStyle = .72,
  });
}

class AppThemeConfig {
  final RemoteThemeColors colors;
  final RemoteNavIcons navIcons;
  final RemoteThemeEffects effects;
  final RemoteThemeVisuals visuals;
  final RemoteStyleDNA styleDNA;

  const AppThemeConfig({
    required this.colors,
    required this.navIcons,
    required this.effects,
    this.visuals = const RemoteThemeVisuals(),
    this.styleDNA = const RemoteStyleDNA(),
  });
}

Color? _parseHexColor(dynamic raw) {
  if (raw is! String) return null;
  String v = raw.trim();
  if (v.isEmpty) return null;
  if (!v.startsWith('#')) return null;
  final String body = v.substring(1);
  // The web Theme Engine serializes colors as CSS hex: #RRGGBBAA.
  // Flutter's Color(int) expects 0xAARRGGBB, so an 8-digit web color must be
  // reordered. Passing it through unchanged turns the final alpha byte (often
  // FF) into blue, which made unrelated presets render as the same blue theme.
  final String argbBody = body.length == 8
      ? '${body.substring(6, 8)}${body.substring(0, 6)}'
      : body.length == 6
          ? 'FF$body'
          : body.length == 3
              ? 'FF${body.split('').map((c) => '$c$c').join()}'
              : '';
  final int? value = int.tryParse(
    argbBody,
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
  Color? maybe(String key) => _parseHexColor(map![key]);

  final primary = maybe('primary');
  final primaryLight = maybe('primaryLight');
  final primaryDark = maybe('primaryDark');

  // A theme can be sent with a complete surface/background palette while
  // omitting one of the optional legacy keys. Treat those values as a custom
  // palette too; otherwise all derived colors silently fall back to the old
  // maroon defaults.
  final hasCustomPalette = <String>[
    'primary',
    'primaryLight',
    'primaryDark',
    'accentPink',
    'background',
    'surface',
    'surfaceLight',
    'menuBackground',
    'heroStart',
    'heroMid',
    'heroEnd',
  ].any((key) => maybe(key) != null);
  final effectivePrimary = primary ?? defaults.primary;
  final effectivePrimaryLight =
      primaryLight ?? _lighten(effectivePrimary, 0.18);
  final effectivePrimaryDark = primaryDark ?? _darken(effectivePrimary, 0.18);

  final Color effectiveAccentPink = maybe('accentPink') ??
      Color.lerp(effectivePrimary, const Color(0xFFFF4DA6), 0.5) ??
      const Color(0xFFFF4DA6);

  final Color effectiveBackground;
  if (maybe('background') case final bg?) {
    effectiveBackground = bg;
  } else if (hasCustomPalette) {
    effectiveBackground = _darken(_desaturate(effectivePrimary, 0.35), 0.45);
  } else {
    effectiveBackground = defaults.background;
  }

  final Color effectiveSurface;
  if (maybe('surface') case final s?) {
    effectiveSurface = s;
  } else if (hasCustomPalette) {
    effectiveSurface = _lighten(effectiveBackground, 0.12);
  } else {
    effectiveSurface = defaults.surface;
  }

  final Color effectiveSurfaceLight;
  if (maybe('surfaceLight') case final sl?) {
    effectiveSurfaceLight = sl;
  } else if (hasCustomPalette) {
    effectiveSurfaceLight = _lighten(effectiveSurface, 0.12);
  } else {
    effectiveSurfaceLight = defaults.surfaceLight;
  }

  final Color effectiveMenuBackground;
  if (maybe('menuBackground') case final mb?) {
    effectiveMenuBackground = mb;
  } else if (hasCustomPalette) {
    effectiveMenuBackground = _darken(effectiveBackground, 0.06);
  } else {
    effectiveMenuBackground = defaults.menuBackground;
  }

  final effectiveTextPrimary = maybe('textPrimary') ?? defaults.textPrimary;
  final effectiveTextSecondary = maybe('textSecondary') ??
      (hasCustomPalette
          ? effectiveTextPrimary.withValues(alpha: 0.72)
          : defaults.textSecondary);
  final effectiveTextTertiary = maybe('textTertiary') ??
      (hasCustomPalette
          ? effectiveTextPrimary.withValues(alpha: 0.48)
          : defaults.textTertiary);
  final effectiveSuccess = maybe('success') ?? defaults.success;
  final effectiveWarning = maybe('warning') ?? defaults.warning;
  final effectiveError = maybe('error') ?? defaults.error;
  final effectiveInfo = maybe('info') ?? defaults.info;

  final Color effectiveBorder;
  if (maybe('border') case final b?) {
    effectiveBorder = b;
  } else if (hasCustomPalette) {
    effectiveBorder = _lighten(_desaturate(effectivePrimaryDark, 0.2), 0.08);
  } else {
    effectiveBorder = defaults.border;
  }

  final Color effectiveBorderLight;
  if (maybe('borderLight') case final bl?) {
    effectiveBorderLight = bl;
  } else if (hasCustomPalette) {
    effectiveBorderLight = _lighten(effectiveBorder, 0.18);
  } else {
    effectiveBorderLight = defaults.borderLight;
  }

  return RemoteThemeColors(
    primary: effectivePrimary,
    primaryLight: effectivePrimaryLight,
    primaryDark: effectivePrimaryDark,
    accentPink: effectiveAccentPink,
    background: effectiveBackground,
    surface: effectiveSurface,
    surfaceLight: effectiveSurfaceLight,
    menuBackground: effectiveMenuBackground,
    textPrimary: effectiveTextPrimary,
    textSecondary: effectiveTextSecondary,
    textTertiary: effectiveTextTertiary,
    success: effectiveSuccess,
    warning: effectiveWarning,
    error: effectiveError,
    info: effectiveInfo,
    border: effectiveBorder,
    borderLight: effectiveBorderLight,
    heroStart: maybe('heroStart') ?? effectiveBackground,
    // Do not use the historical maroon primaryDark/accent fallback for a
    // palette that supplied its own surfaces. The hero must be derived from
    // the same background/surface family so a light/blue/green theme cannot
    // retain a red-brown band in the app background.
    heroMid: maybe('heroMid') ??
        (hasCustomPalette
            ? Color.lerp(effectiveBackground, effectiveSurfaceLight, .5)!
            : effectivePrimaryDark),
    heroEnd: maybe('heroEnd') ??
        (hasCustomPalette
            ? (effectiveBackground.computeLuminance() > .52
                ? Color.lerp(effectiveBackground, effectiveSurface, .35)!
                : _darken(effectiveBackground, .18))
            : effectiveAccentPink),
  );
}

Color _darken(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  final l = (hsl.lightness - amount).clamp(0.0, 1.0);
  return hsl.withLightness(l).toColor();
}

Color _lighten(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  final l = (hsl.lightness + amount).clamp(0.0, 1.0);
  return hsl.withLightness(l).toColor();
}

Color _desaturate(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  final s = (hsl.saturation - amount).clamp(0.0, 1.0);
  return hsl.withSaturation(s).toColor();
}

RemoteNavIcons parseRemoteNavIcons(dynamic raw) {
  Map<Object?, Object?>? map;
  if (raw is Map) map = raw as Map<Object?, Object?>;
  if (raw is Map<String, dynamic>) map = raw;
  String? s(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  String? id(Object? v) {
    final sv = s(v);
    if (sv == null) return null;
    final lower = sv.toLowerCase();
    final valid = RegExp(r'^[a-z0-9_.-]{1,80}$').hasMatch(lower);
    return valid ? lower : null;
  }

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
    homeId: id(map['homeId']),
    searchId: id(map['searchId']),
    categoriesId: id(map['categoriesId']),
    ordersId: id(map['ordersId']),
    profileId: id(map['profileId']),
    homeActiveId: id(map['homeActiveId']),
    searchActiveId: id(map['searchActiveId']),
    categoriesActiveId: id(map['categoriesActiveId']),
    ordersActiveId: id(map['ordersActiveId']),
    profileActiveId: id(map['profileActiveId']),
  );
}

({String name, String weight})? parsePhosphorIconId(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final lower = trimmed.toLowerCase();
  final parts =
      lower.split(RegExp(r'[.]+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return null;
  String name;
  String weight;
  if (parts[0] == 'phosphor') {
    name = parts.elementAtOrNull(1) ?? 'circle';
    weight = parts.elementAtOrNull(2) ?? 'regular';
  } else {
    name = parts[0];
    weight = parts.elementAtOrNull(1) ?? 'regular';
  }
  const validWeights = {'thin', 'light', 'regular', 'bold', 'fill'};
  if (!validWeights.contains(weight)) weight = 'regular';
  if (!RegExp(r'^[a-z0-9-]{1,40}$').hasMatch(name)) return null;
  return (name: name, weight: weight);
}

Map<String, IconData> _buildPhosphorIconMap(String weight) {
  Map<String, IconData> Function(Map<String, IconData>)? getter;
  switch (weight) {
    case 'thin':
      getter = (Map<String, IconData> out) {
        out['house'] = PhosphorIconsThin.house;
        out['magnifying-glass'] = PhosphorIconsThin.magnifyingGlass;
        out['squares-four'] = PhosphorIconsThin.squaresFour;
        out['shopping-bag'] = PhosphorIconsThin.shoppingBag;
        out['user'] = PhosphorIconsThin.user;
        out['heart'] = PhosphorIconsThin.heart;
        out['star'] = PhosphorIconsThin.star;
        out['gem'] = PhosphorIconsThin.diamond;
        out['compass'] = PhosphorIconsThin.compass;
        out['bell'] = PhosphorIconsThin.bell;
        out['bookmark'] = PhosphorIconsThin.bookmark;
        out['bolt'] = PhosphorIconsThin.lightning;
        out['gift'] = PhosphorIconsThin.gift;
        out['chat-circle'] = PhosphorIconsThin.chatCircle;
        out['calendar'] = PhosphorIconsThin.calendar;
        out['map-pin'] = PhosphorIconsThin.mapPin;
        out['shopping-cart'] = PhosphorIconsThin.shoppingCart;
        out['crown'] = PhosphorIconsThin.crown;
        out['flame'] = PhosphorIconsThin.flame;
        out['camera'] = PhosphorIconsThin.camera;
        out['music-note'] = PhosphorIconsThin.musicNote;
        out['film-strip'] = PhosphorIconsThin.filmStrip;
        out['headphones'] = PhosphorIconsThin.headphones;
        out['game-controller'] = PhosphorIconsThin.gameController;
        out['wallet'] = PhosphorIconsThin.wallet;
        out['credit-card'] = PhosphorIconsThin.creditCard;
        out['ticket'] = PhosphorIconsThin.ticket;
        out['couch'] = PhosphorIconsThin.couch;
        out['car'] = PhosphorIconsThin.car;
        out['airplane'] = PhosphorIconsThin.airplane;
        out['briefcase'] = PhosphorIconsThin.briefcase;
        out['paw-print'] = PhosphorIconsThin.pawPrint;
        out['leaf'] = PhosphorIconsThin.leaf;
        out['sun'] = PhosphorIconsThin.sun;
        out['moon'] = PhosphorIconsThin.moon;
        out['sparkle'] = PhosphorIconsThin.sparkle;
        out['fire'] = PhosphorIconsThin.fire;
        out['lightbulb'] = PhosphorIconsThin.lightbulb;
        out['rocket'] = PhosphorIconsThin.rocket;
        out['trophy'] = PhosphorIconsThin.trophy;
        out['award'] = PhosphorIconsThin.medal;
        out['scissors'] = PhosphorIconsThin.scissors;
        out['scooter'] = PhosphorIconsThin.scooter;
        out['truck'] = PhosphorIconsThin.truck;
        out['flower-lotus'] = PhosphorIconsThin.flowerLotus;
        out['coffee'] = PhosphorIconsThin.coffee;
        out['cake'] = PhosphorIconsThin.cake;
        out['hand-heart'] = PhosphorIconsThin.handHeart;
        out['user-circle'] = PhosphorIconsThin.userCircle;
        out['users'] = PhosphorIconsThin.users;
        out['image'] = PhosphorIconsThin.image;
        out['video'] = PhosphorIconsThin.video;
        out['notebook'] = PhosphorIconsThin.notebook;
        out['archive'] = PhosphorIconsThin.archive;
        out['folder'] = PhosphorIconsThin.folder;
        out['tag'] = PhosphorIconsThin.tag;
        out['hash'] = PhosphorIconsThin.hash;
        out['rss'] = PhosphorIconsThin.rss;
        out['chat-teardrop'] = PhosphorIconsThin.chatTeardrop;
        out['envelope-simple'] = PhosphorIconsThin.envelopeSimple;
        out['phone'] = PhosphorIconsThin.phone;
        out['fingerprint'] = PhosphorIconsThin.fingerprint;
        out['lock-key'] = PhosphorIconsThin.lockKey;
        out['gear-six'] = PhosphorIconsThin.gearSix;
        out['sliders-horizontal'] = PhosphorIconsThin.slidersHorizontal;
        out['funnel'] = PhosphorIconsThin.funnel;
        out['arrows-left-right'] = PhosphorIconsThin.arrowsLeftRight;
        out['trash'] = PhosphorIconsThin.trash;
        out['pencil-simple'] = PhosphorIconsThin.pencilSimple;
        out['eye'] = PhosphorIconsThin.eye;
        out['heartbeat'] = PhosphorIconsThin.heartbeat;
        out['diamonds-four'] = PhosphorIconsThin.diamondsFour;
        out['pentagram'] = PhosphorIconsThin.pentagram;
        out['list-dashes'] = PhosphorIconsThin.listDashes;
        out['grid-four'] = PhosphorIconsThin.gridFour;
        out['dot-nine'] = PhosphorIconsThin.dotsNine;
        out['baseball'] = PhosphorIconsThin.baseball;
        out['basketball'] = PhosphorIconsThin.basketball;
        out['soccer-ball'] = PhosphorIconsThin.soccerBall;
        out['tennis-ball'] = PhosphorIconsThin.tennisBall;
        out['volleyball'] = PhosphorIconsThin.volleyball;
        return out;
      };
      break;
    case 'light':
      getter = (Map<String, IconData> out) {
        out['house'] = PhosphorIconsLight.house;
        out['magnifying-glass'] = PhosphorIconsLight.magnifyingGlass;
        out['squares-four'] = PhosphorIconsLight.squaresFour;
        out['shopping-bag'] = PhosphorIconsLight.shoppingBag;
        out['user'] = PhosphorIconsLight.user;
        out['heart'] = PhosphorIconsLight.heart;
        out['star'] = PhosphorIconsLight.star;
        out['gem'] = PhosphorIconsLight.diamond;
        out['compass'] = PhosphorIconsLight.compass;
        out['bell'] = PhosphorIconsLight.bell;
        out['bookmark'] = PhosphorIconsLight.bookmark;
        out['bolt'] = PhosphorIconsLight.lightning;
        out['gift'] = PhosphorIconsLight.gift;
        out['chat-circle'] = PhosphorIconsLight.chatCircle;
        out['calendar'] = PhosphorIconsLight.calendar;
        out['map-pin'] = PhosphorIconsLight.mapPin;
        out['shopping-cart'] = PhosphorIconsLight.shoppingCart;
        out['crown'] = PhosphorIconsLight.crown;
        out['flame'] = PhosphorIconsLight.flame;
        out['camera'] = PhosphorIconsLight.camera;
        out['music-note'] = PhosphorIconsLight.musicNote;
        out['film-strip'] = PhosphorIconsLight.filmStrip;
        out['headphones'] = PhosphorIconsLight.headphones;
        out['game-controller'] = PhosphorIconsLight.gameController;
        out['wallet'] = PhosphorIconsLight.wallet;
        out['credit-card'] = PhosphorIconsLight.creditCard;
        out['ticket'] = PhosphorIconsLight.ticket;
        out['couch'] = PhosphorIconsLight.couch;
        out['car'] = PhosphorIconsLight.car;
        out['airplane'] = PhosphorIconsLight.airplane;
        out['briefcase'] = PhosphorIconsLight.briefcase;
        out['paw-print'] = PhosphorIconsLight.pawPrint;
        out['leaf'] = PhosphorIconsLight.leaf;
        out['sun'] = PhosphorIconsLight.sun;
        out['moon'] = PhosphorIconsLight.moon;
        out['sparkle'] = PhosphorIconsLight.sparkle;
        out['fire'] = PhosphorIconsLight.fire;
        out['lightbulb'] = PhosphorIconsLight.lightbulb;
        out['rocket'] = PhosphorIconsLight.rocket;
        out['trophy'] = PhosphorIconsLight.trophy;
        out['award'] = PhosphorIconsLight.medal;
        out['scissors'] = PhosphorIconsLight.scissors;
        out['scooter'] = PhosphorIconsLight.scooter;
        out['truck'] = PhosphorIconsLight.truck;
        out['flower-lotus'] = PhosphorIconsLight.flowerLotus;
        out['coffee'] = PhosphorIconsLight.coffee;
        out['cake'] = PhosphorIconsLight.cake;
        out['hand-heart'] = PhosphorIconsLight.handHeart;
        out['user-circle'] = PhosphorIconsLight.userCircle;
        out['users'] = PhosphorIconsLight.users;
        out['image'] = PhosphorIconsLight.image;
        out['video'] = PhosphorIconsLight.video;
        out['notebook'] = PhosphorIconsLight.notebook;
        out['archive'] = PhosphorIconsLight.archive;
        out['folder'] = PhosphorIconsLight.folder;
        out['tag'] = PhosphorIconsLight.tag;
        out['hash'] = PhosphorIconsLight.hash;
        out['rss'] = PhosphorIconsLight.rss;
        out['chat-teardrop'] = PhosphorIconsLight.chatTeardrop;
        out['envelope-simple'] = PhosphorIconsLight.envelopeSimple;
        out['phone'] = PhosphorIconsLight.phone;
        out['fingerprint'] = PhosphorIconsLight.fingerprint;
        out['lock-key'] = PhosphorIconsLight.lockKey;
        out['gear-six'] = PhosphorIconsLight.gearSix;
        out['sliders-horizontal'] = PhosphorIconsLight.slidersHorizontal;
        out['funnel'] = PhosphorIconsLight.funnel;
        out['arrows-left-right'] = PhosphorIconsLight.arrowsLeftRight;
        out['trash'] = PhosphorIconsLight.trash;
        out['pencil-simple'] = PhosphorIconsLight.pencilSimple;
        out['eye'] = PhosphorIconsLight.eye;
        out['heartbeat'] = PhosphorIconsLight.heartbeat;
        out['diamonds-four'] = PhosphorIconsLight.diamondsFour;
        out['pentagram'] = PhosphorIconsLight.pentagram;
        out['list-dashes'] = PhosphorIconsLight.listDashes;
        out['grid-four'] = PhosphorIconsLight.gridFour;
        out['dot-nine'] = PhosphorIconsLight.dotsNine;
        out['baseball'] = PhosphorIconsLight.baseball;
        out['basketball'] = PhosphorIconsLight.basketball;
        out['soccer-ball'] = PhosphorIconsLight.soccerBall;
        out['tennis-ball'] = PhosphorIconsLight.tennisBall;
        out['volleyball'] = PhosphorIconsLight.volleyball;
        return out;
      };
      break;
    case 'bold':
      getter = (Map<String, IconData> out) {
        out['house'] = PhosphorIconsBold.house;
        out['magnifying-glass'] = PhosphorIconsBold.magnifyingGlass;
        out['squares-four'] = PhosphorIconsBold.squaresFour;
        out['shopping-bag'] = PhosphorIconsBold.shoppingBag;
        out['user'] = PhosphorIconsBold.user;
        out['heart'] = PhosphorIconsBold.heart;
        out['star'] = PhosphorIconsBold.star;
        out['gem'] = PhosphorIconsBold.diamond;
        out['compass'] = PhosphorIconsBold.compass;
        out['bell'] = PhosphorIconsBold.bell;
        out['bookmark'] = PhosphorIconsBold.bookmark;
        out['bolt'] = PhosphorIconsBold.lightning;
        out['gift'] = PhosphorIconsBold.gift;
        out['chat-circle'] = PhosphorIconsBold.chatCircle;
        out['calendar'] = PhosphorIconsBold.calendar;
        out['map-pin'] = PhosphorIconsBold.mapPin;
        out['shopping-cart'] = PhosphorIconsBold.shoppingCart;
        out['crown'] = PhosphorIconsBold.crown;
        out['flame'] = PhosphorIconsBold.flame;
        out['camera'] = PhosphorIconsBold.camera;
        out['music-note'] = PhosphorIconsBold.musicNote;
        out['film-strip'] = PhosphorIconsBold.filmStrip;
        out['headphones'] = PhosphorIconsBold.headphones;
        out['game-controller'] = PhosphorIconsBold.gameController;
        out['wallet'] = PhosphorIconsBold.wallet;
        out['credit-card'] = PhosphorIconsBold.creditCard;
        out['ticket'] = PhosphorIconsBold.ticket;
        out['couch'] = PhosphorIconsBold.couch;
        out['car'] = PhosphorIconsBold.car;
        out['airplane'] = PhosphorIconsBold.airplane;
        out['briefcase'] = PhosphorIconsBold.briefcase;
        out['paw-print'] = PhosphorIconsBold.pawPrint;
        out['leaf'] = PhosphorIconsBold.leaf;
        out['sun'] = PhosphorIconsBold.sun;
        out['moon'] = PhosphorIconsBold.moon;
        out['sparkle'] = PhosphorIconsBold.sparkle;
        out['fire'] = PhosphorIconsBold.fire;
        out['lightbulb'] = PhosphorIconsBold.lightbulb;
        out['rocket'] = PhosphorIconsBold.rocket;
        out['trophy'] = PhosphorIconsBold.trophy;
        out['award'] = PhosphorIconsBold.medal;
        out['scissors'] = PhosphorIconsBold.scissors;
        out['scooter'] = PhosphorIconsBold.scooter;
        out['truck'] = PhosphorIconsBold.truck;
        out['flower-lotus'] = PhosphorIconsBold.flowerLotus;
        out['coffee'] = PhosphorIconsBold.coffee;
        out['cake'] = PhosphorIconsBold.cake;
        out['hand-heart'] = PhosphorIconsBold.handHeart;
        out['user-circle'] = PhosphorIconsBold.userCircle;
        out['users'] = PhosphorIconsBold.users;
        out['image'] = PhosphorIconsBold.image;
        out['video'] = PhosphorIconsBold.video;
        out['notebook'] = PhosphorIconsBold.notebook;
        out['archive'] = PhosphorIconsBold.archive;
        out['folder'] = PhosphorIconsBold.folder;
        out['tag'] = PhosphorIconsBold.tag;
        out['hash'] = PhosphorIconsBold.hash;
        out['rss'] = PhosphorIconsBold.rss;
        out['chat-teardrop'] = PhosphorIconsBold.chatTeardrop;
        out['envelope-simple'] = PhosphorIconsBold.envelopeSimple;
        out['phone'] = PhosphorIconsBold.phone;
        out['fingerprint'] = PhosphorIconsBold.fingerprint;
        out['lock-key'] = PhosphorIconsBold.lockKey;
        out['gear-six'] = PhosphorIconsBold.gearSix;
        out['sliders-horizontal'] = PhosphorIconsBold.slidersHorizontal;
        out['funnel'] = PhosphorIconsBold.funnel;
        out['arrows-left-right'] = PhosphorIconsBold.arrowsLeftRight;
        out['trash'] = PhosphorIconsBold.trash;
        out['pencil-simple'] = PhosphorIconsBold.pencilSimple;
        out['eye'] = PhosphorIconsBold.eye;
        out['heartbeat'] = PhosphorIconsBold.heartbeat;
        out['diamonds-four'] = PhosphorIconsBold.diamondsFour;
        out['pentagram'] = PhosphorIconsBold.pentagram;
        out['list-dashes'] = PhosphorIconsBold.listDashes;
        out['grid-four'] = PhosphorIconsBold.gridFour;
        out['dot-nine'] = PhosphorIconsBold.dotsNine;
        out['baseball'] = PhosphorIconsBold.baseball;
        out['basketball'] = PhosphorIconsBold.basketball;
        out['soccer-ball'] = PhosphorIconsBold.soccerBall;
        out['tennis-ball'] = PhosphorIconsBold.tennisBall;
        out['volleyball'] = PhosphorIconsBold.volleyball;
        return out;
      };
      break;
    case 'fill':
      getter = (Map<String, IconData> out) {
        out['house'] = PhosphorIconsFill.house;
        out['magnifying-glass'] = PhosphorIconsFill.magnifyingGlass;
        out['squares-four'] = PhosphorIconsFill.squaresFour;
        out['shopping-bag'] = PhosphorIconsFill.shoppingBag;
        out['user'] = PhosphorIconsFill.user;
        out['heart'] = PhosphorIconsFill.heart;
        out['star'] = PhosphorIconsFill.star;
        out['gem'] = PhosphorIconsFill.diamond;
        out['compass'] = PhosphorIconsFill.compass;
        out['bell'] = PhosphorIconsFill.bell;
        out['bookmark'] = PhosphorIconsFill.bookmark;
        out['bolt'] = PhosphorIconsFill.lightning;
        out['gift'] = PhosphorIconsFill.gift;
        out['chat-circle'] = PhosphorIconsFill.chatCircle;
        out['calendar'] = PhosphorIconsFill.calendar;
        out['map-pin'] = PhosphorIconsFill.mapPin;
        out['shopping-cart'] = PhosphorIconsFill.shoppingCart;
        out['crown'] = PhosphorIconsFill.crown;
        out['flame'] = PhosphorIconsFill.flame;
        out['camera'] = PhosphorIconsFill.camera;
        out['music-note'] = PhosphorIconsFill.musicNote;
        out['film-strip'] = PhosphorIconsFill.filmStrip;
        out['headphones'] = PhosphorIconsFill.headphones;
        out['game-controller'] = PhosphorIconsFill.gameController;
        out['wallet'] = PhosphorIconsFill.wallet;
        out['credit-card'] = PhosphorIconsFill.creditCard;
        out['ticket'] = PhosphorIconsFill.ticket;
        out['couch'] = PhosphorIconsFill.couch;
        out['car'] = PhosphorIconsFill.car;
        out['airplane'] = PhosphorIconsFill.airplane;
        out['briefcase'] = PhosphorIconsFill.briefcase;
        out['paw-print'] = PhosphorIconsFill.pawPrint;
        out['leaf'] = PhosphorIconsFill.leaf;
        out['sun'] = PhosphorIconsFill.sun;
        out['moon'] = PhosphorIconsFill.moon;
        out['sparkle'] = PhosphorIconsFill.sparkle;
        out['fire'] = PhosphorIconsFill.fire;
        out['lightbulb'] = PhosphorIconsFill.lightbulb;
        out['rocket'] = PhosphorIconsFill.rocket;
        out['trophy'] = PhosphorIconsFill.trophy;
        out['award'] = PhosphorIconsFill.medal;
        out['scissors'] = PhosphorIconsFill.scissors;
        out['scooter'] = PhosphorIconsFill.scooter;
        out['truck'] = PhosphorIconsFill.truck;
        out['flower-lotus'] = PhosphorIconsFill.flowerLotus;
        out['coffee'] = PhosphorIconsFill.coffee;
        out['cake'] = PhosphorIconsFill.cake;
        out['hand-heart'] = PhosphorIconsFill.handHeart;
        out['user-circle'] = PhosphorIconsFill.userCircle;
        out['users'] = PhosphorIconsFill.users;
        out['image'] = PhosphorIconsFill.image;
        out['video'] = PhosphorIconsFill.video;
        out['notebook'] = PhosphorIconsFill.notebook;
        out['archive'] = PhosphorIconsFill.archive;
        out['folder'] = PhosphorIconsFill.folder;
        out['tag'] = PhosphorIconsFill.tag;
        out['hash'] = PhosphorIconsFill.hash;
        out['rss'] = PhosphorIconsFill.rss;
        out['chat-teardrop'] = PhosphorIconsFill.chatTeardrop;
        out['envelope-simple'] = PhosphorIconsFill.envelopeSimple;
        out['phone'] = PhosphorIconsFill.phone;
        out['fingerprint'] = PhosphorIconsFill.fingerprint;
        out['lock-key'] = PhosphorIconsFill.lockKey;
        out['gear-six'] = PhosphorIconsFill.gearSix;
        out['sliders-horizontal'] = PhosphorIconsFill.slidersHorizontal;
        out['funnel'] = PhosphorIconsFill.funnel;
        out['arrows-left-right'] = PhosphorIconsFill.arrowsLeftRight;
        out['trash'] = PhosphorIconsFill.trash;
        out['pencil-simple'] = PhosphorIconsFill.pencilSimple;
        out['eye'] = PhosphorIconsFill.eye;
        out['heartbeat'] = PhosphorIconsFill.heartbeat;
        out['diamonds-four'] = PhosphorIconsFill.diamondsFour;
        out['pentagram'] = PhosphorIconsFill.pentagram;
        out['list-dashes'] = PhosphorIconsFill.listDashes;
        out['grid-four'] = PhosphorIconsFill.gridFour;
        out['dot-nine'] = PhosphorIconsFill.dotsNine;
        out['baseball'] = PhosphorIconsFill.baseball;
        out['basketball'] = PhosphorIconsFill.basketball;
        out['soccer-ball'] = PhosphorIconsFill.soccerBall;
        out['tennis-ball'] = PhosphorIconsFill.tennisBall;
        out['volleyball'] = PhosphorIconsFill.volleyball;
        return out;
      };
      break;
    case 'regular':
    default:
      getter = (Map<String, IconData> out) {
        out['house'] = PhosphorIconsRegular.house;
        out['magnifying-glass'] = PhosphorIconsRegular.magnifyingGlass;
        out['squares-four'] = PhosphorIconsRegular.squaresFour;
        out['shopping-bag'] = PhosphorIconsRegular.shoppingBag;
        out['user'] = PhosphorIconsRegular.user;
        out['heart'] = PhosphorIconsRegular.heart;
        out['star'] = PhosphorIconsRegular.star;
        out['gem'] = PhosphorIconsRegular.diamond;
        out['compass'] = PhosphorIconsRegular.compass;
        out['bell'] = PhosphorIconsRegular.bell;
        out['bookmark'] = PhosphorIconsRegular.bookmark;
        out['bolt'] = PhosphorIconsRegular.lightning;
        out['gift'] = PhosphorIconsRegular.gift;
        out['chat-circle'] = PhosphorIconsRegular.chatCircle;
        out['calendar'] = PhosphorIconsRegular.calendar;
        out['map-pin'] = PhosphorIconsRegular.mapPin;
        out['shopping-cart'] = PhosphorIconsRegular.shoppingCart;
        out['crown'] = PhosphorIconsRegular.crown;
        out['flame'] = PhosphorIconsRegular.flame;
        out['camera'] = PhosphorIconsRegular.camera;
        out['music-note'] = PhosphorIconsRegular.musicNote;
        out['film-strip'] = PhosphorIconsRegular.filmStrip;
        out['headphones'] = PhosphorIconsRegular.headphones;
        out['game-controller'] = PhosphorIconsRegular.gameController;
        out['wallet'] = PhosphorIconsRegular.wallet;
        out['credit-card'] = PhosphorIconsRegular.creditCard;
        out['ticket'] = PhosphorIconsRegular.ticket;
        out['couch'] = PhosphorIconsRegular.couch;
        out['car'] = PhosphorIconsRegular.car;
        out['airplane'] = PhosphorIconsRegular.airplane;
        out['briefcase'] = PhosphorIconsRegular.briefcase;
        out['paw-print'] = PhosphorIconsRegular.pawPrint;
        out['leaf'] = PhosphorIconsRegular.leaf;
        out['sun'] = PhosphorIconsRegular.sun;
        out['moon'] = PhosphorIconsRegular.moon;
        out['sparkle'] = PhosphorIconsRegular.sparkle;
        out['fire'] = PhosphorIconsRegular.fire;
        out['lightbulb'] = PhosphorIconsRegular.lightbulb;
        out['rocket'] = PhosphorIconsRegular.rocket;
        out['trophy'] = PhosphorIconsRegular.trophy;
        out['award'] = PhosphorIconsRegular.medal;
        out['scissors'] = PhosphorIconsRegular.scissors;
        out['scooter'] = PhosphorIconsRegular.scooter;
        out['truck'] = PhosphorIconsRegular.truck;
        out['flower-lotus'] = PhosphorIconsRegular.flowerLotus;
        out['coffee'] = PhosphorIconsRegular.coffee;
        out['cake'] = PhosphorIconsRegular.cake;
        out['hand-heart'] = PhosphorIconsRegular.handHeart;
        out['user-circle'] = PhosphorIconsRegular.userCircle;
        out['users'] = PhosphorIconsRegular.users;
        out['image'] = PhosphorIconsRegular.image;
        out['video'] = PhosphorIconsRegular.video;
        out['notebook'] = PhosphorIconsRegular.notebook;
        out['archive'] = PhosphorIconsRegular.archive;
        out['folder'] = PhosphorIconsRegular.folder;
        out['tag'] = PhosphorIconsRegular.tag;
        out['hash'] = PhosphorIconsRegular.hash;
        out['rss'] = PhosphorIconsRegular.rss;
        out['chat-teardrop'] = PhosphorIconsRegular.chatTeardrop;
        out['envelope-simple'] = PhosphorIconsRegular.envelopeSimple;
        out['phone'] = PhosphorIconsRegular.phone;
        out['fingerprint'] = PhosphorIconsRegular.fingerprint;
        out['lock-key'] = PhosphorIconsRegular.lockKey;
        out['gear-six'] = PhosphorIconsRegular.gearSix;
        out['sliders-horizontal'] = PhosphorIconsRegular.slidersHorizontal;
        out['funnel'] = PhosphorIconsRegular.funnel;
        out['arrows-left-right'] = PhosphorIconsRegular.arrowsLeftRight;
        out['trash'] = PhosphorIconsRegular.trash;
        out['pencil-simple'] = PhosphorIconsRegular.pencilSimple;
        out['eye'] = PhosphorIconsRegular.eye;
        out['heartbeat'] = PhosphorIconsRegular.heartbeat;
        out['diamonds-four'] = PhosphorIconsRegular.diamondsFour;
        out['pentagram'] = PhosphorIconsRegular.pentagram;
        out['list-dashes'] = PhosphorIconsRegular.listDashes;
        out['grid-four'] = PhosphorIconsRegular.gridFour;
        out['dot-nine'] = PhosphorIconsRegular.dotsNine;
        out['baseball'] = PhosphorIconsRegular.baseball;
        out['basketball'] = PhosphorIconsRegular.basketball;
        out['soccer-ball'] = PhosphorIconsRegular.soccerBall;
        out['tennis-ball'] = PhosphorIconsRegular.tennisBall;
        out['volleyball'] = PhosphorIconsRegular.volleyball;
        return out;
      };
  }
  final out = <String, IconData>{};
  return getter(out);
}

final Map<String, Map<String, IconData>> _phosphorCache = {};

IconData? resolvePhosphorIcon(String name, String weight) {
  final key = '${weight}_$name';
  final map =
      _phosphorCache.putIfAbsent(key, () => _buildPhosphorIconMap(weight));
  return map[name];
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
    primaryGradientAngle: pick(
        'primaryGradientAngle', defaults.primaryGradientAngle,
        min: 0, max: 360),
    cardRadius: pick('cardRadius', defaults.cardRadius, min: 0, max: 60),
    chipRadius: pick('chipRadius', defaults.chipRadius, min: 0, max: 9999),
    buttonRadius: pick('buttonRadius', defaults.buttonRadius, min: 0, max: 60),
    navShadowOpacity:
        pick('navShadowOpacity', defaults.navShadowOpacity, min: 0, max: 1),
    cardShadowOpacity:
        pick('cardShadowOpacity', defaults.cardShadowOpacity, min: 0, max: 1),
    activeGlowOpacity:
        pick('activeGlowOpacity', defaults.activeGlowOpacity, min: 0, max: 1),
    glassBlur: pick('glassBlur', defaults.glassBlur, min: 0, max: 60),
    surfaceOpacity:
        pick('surfaceOpacity', defaults.surfaceOpacity, min: 0.2, max: 1),
    borderOpacity:
        pick('borderOpacity', defaults.borderOpacity, min: 0, max: 1),
  );
}

RemoteThemeVisuals parseRemoteVisuals(dynamic raw) {
  if (raw is! Map) return const RemoteThemeVisuals();
  Map<String, dynamic> map = Map<String, dynamic>.from(raw);
  ThemeGlow parseGlow(dynamic value) {
    final item =
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
    return ThemeGlow(
      color: _parseHexColor(item['color']) ?? Colors.transparent,
      x: _parseDouble(item['x'], .5, min: 0, max: 1),
      y: _parseDouble(item['y'], .5, min: 0, max: 1),
      radius: _parseDouble(item['radius'], 320, min: 20, max: 800),
      opacity: _parseDouble(item['opacity'], .12, min: 0, max: 1),
    );
  }

  List<ThemeGlow> list(String key) => (map[key] is List)
      ? (map[key] as List).map(parseGlow).toList()
      : const [];
  final mesh = map['backgroundMesh'] is Map
      ? Map<String, dynamic>.from(map['backgroundMesh'])
      : <String, dynamic>{};
  final tint = map['surfaceTint'] is Map
      ? Map<String, dynamic>.from(map['surfaceTint'])
      : <String, dynamic>{};
  final noise = map['noise'] is Map
      ? Map<String, dynamic>.from(map['noise'])
      : <String, dynamic>{};
  final vignette = map['vignette'] is Map
      ? Map<String, dynamic>.from(map['vignette'])
      : <String, dynamic>{};
  return RemoteThemeVisuals(
      meshEnabled: mesh['enabled'] == true,
      meshPoints: listFrom(mesh['points']),
      ambientGlows: list('ambientGlows'),
      cardTint: _parseHexColor(tint['card']) ?? Colors.transparent,
      headerTint: _parseHexColor(tint['header']) ?? Colors.transparent,
      navigationTint: _parseHexColor(tint['navigation']) ?? Colors.transparent,
      headerStyle: (map['headerStyle'] as String?) ?? 'gradient',
      noiseEnabled: noise['enabled'] == true,
      noiseOpacity: _parseDouble(noise['opacity'], 0.0, min: 0, max: .1),
      vignetteEnabled: vignette['enabled'] == true,
      vignetteStrength:
          _parseDouble(vignette['strength'], 0.0, min: 0, max: .3));
}

RemoteStyleDNA parseRemoteStyleDNA(dynamic raw, {dynamic schemaVersion}) {
  if (raw is! Map) return const RemoteStyleDNA();
  final map = Map<String, dynamic>.from(raw);
  double pick(String key, double fallback) =>
      _parseDouble(map[key], fallback, min: 0, max: 1);
  return RemoteStyleDNA(
    schemaVersion: schemaVersion is num ? schemaVersion.toInt() : 1,
    darkness: pick('darkness', .82),
    contrast: pick('contrast', .74),
    accentStrength: pick('accentStrength', .18),
    glassStrength: pick('glassStrength', .54),
    ambientLight: pick('ambientLight', .18),
    vignetteStrength: pick('vignetteStrength', .22),
    radiusStyle: pick('radiusStyle', .72),
  );
}

List<ThemeGlow> listFrom(dynamic value) => value is List
    ? value.map((item) {
        final map =
            item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
        return ThemeGlow(
            color: _parseHexColor(map['color']) ?? Colors.transparent,
            x: _parseDouble(map['x'], .5, min: 0, max: 1),
            y: _parseDouble(map['y'], .5, min: 0, max: 1),
            radius: _parseDouble(map['radius'], 320, min: 20, max: 800),
            opacity: _parseDouble(map['opacity'], .12, min: 0, max: 1));
      }).toList()
    : const [];

class _DefaultAppTheme {
  static const RemoteThemeColors colors = RemoteThemeColors(
    primary: Color(0xFFD91F68),
    primaryLight: Color(0xFFFF326F),
    primaryDark: Color(0xFF76072E),
    accentPink: Color(0xFFF0296B),
    background: Color(0xFF200810),
    surface: Color(0xFF35101A),
    surfaceLight: Color(0xFF531020),
    menuBackground: Color(0xFF250512),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFCBC3C6),
    textTertiary: Color(0xFF9E9297),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF3B82F6),
    border: Color(0xFF8D2948),
    borderLight: Color(0xFF5D1B31),
    heroStart: Color(0xFF200810),
    heroMid: Color(0xFF3E0A1B),
    heroEnd: Color(0xFF0D0509),
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
