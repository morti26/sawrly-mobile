import 'package:flutter/material.dart';

import '../theme/app_theme_config.dart';

/// Design tokens for the Fotgraf mobile app
/// Centralized color, typography, and spacing values
class AppColors {
  AppColors._();

  // Primary brand colors
  static const Color primary = Color(0xFFD91F68);
  static const Color primaryLight = Color(0xFFFF326F);
  static const Color primaryDark = Color(0xFF76072E);
  static const Color accentPink = Color(0xFFF0296B);

  // Background colors
  static const Color background = Color(0xFF200810);
  static const Color surface = Color(0xFF35101A);
  static const Color surfaceLight = Color(0xFF531020);
  static const Color menuBackground = Color(0xFF250512);

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCBC3C6);
  static const Color textTertiary = Color(0xFF9E9297);

  // Status colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Status badge colors (light variants)
  static const Color successBg = Color(0xFF1A3D2E);
  static const Color warningBg = Color(0xFF3D2E1A);
  static const Color errorBg = Color(0xFF3D1A1A);
  static const Color infoBg = Color(0xFF1A2D3D);

  // Border colors
  static const Color border = Color(0xFF8D2948);
  static const Color borderLight = Color(0xFF5D1B31);

  // Gradient colors
  static const List<Color> primaryGradient = [
    Color(0xFFE92B78),
    Color(0xFF8C164A),
  ];

  static const List<Color> accentGradient = [
    Color(0xFFE92B78),
    Color(0xFF8C45F5),
  ];

  static const List<Color> darkGradient = [
    Color(0xFF310914),
    Color(0xFF0D0509),
  ];
}

class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Tajawal';

  // Headings
  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  static const TextStyle h4 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  // Body text
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  // Labels
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  // Button text
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  // Caption
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.normal,
    color: AppColors.textTertiary,
    height: 1.3,
  );
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;

  // Screen padding
  static const double screenPadding = 16;

  // Card padding
  static const double cardPadding = 12;

  // Border radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusFull = 100;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get button => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get modal => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get glowPrimary => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.55),
          blurRadius: 14,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: AppColors.primaryLight.withValues(alpha: 0.22),
          blurRadius: 22,
          spreadRadius: 2,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get glowAccent => [
        BoxShadow(
          color: AppColors.accentPink.withValues(alpha: 0.30),
          blurRadius: 16,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.22),
          blurRadius: 22,
          spreadRadius: 2,
          offset: const Offset(0, 12),
        ),
      ];
}

/// Dynamic premium tokens derived from the active Enterprise Theme Engine.
///
/// This is the single visual translation layer used by premium surfaces. It
/// keeps the customer's palette as source of truth while normalising depth,
/// borders, radii, typography contrast and motion across components.
class PremiumDesignTokens {
  final Color backgroundTop;
  final Color backgroundMiddle;
  final Color backgroundDeep;
  final Color backgroundLower;
  final Color surfacePrimary;
  final Color surfaceSecondary;
  final Color surfaceElevated;
  final Color glassSurface;
  final Color borderSubtle;
  final Color borderHighlight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accentPrimary;
  final Color accentSoft;
  final Color accentWarm;
  final Color priceColor;
  final Color shadowColor;
  final double radiusSmall;
  final double radiusMedium;
  final double radiusLarge;
  final double radiusFloating;
  final double cardShadowOpacity;

  const PremiumDesignTokens._({
    required this.backgroundTop,
    required this.backgroundMiddle,
    required this.backgroundDeep,
    required this.backgroundLower,
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.surfaceElevated,
    required this.glassSurface,
    required this.borderSubtle,
    required this.borderHighlight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentPrimary,
    required this.accentSoft,
    required this.accentWarm,
    required this.priceColor,
    required this.shadowColor,
    required this.radiusSmall,
    required this.radiusMedium,
    required this.radiusLarge,
    required this.radiusFloating,
    required this.cardShadowOpacity,
  });

  factory PremiumDesignTokens.from(AppThemeConfig theme) {
    final c = theme.colors;
    final e = theme.effects;
    final dna = theme.styleDNA;
    // The resolved Theme Studio tokens are the source of truth. The previous
    // implementation blended every preset over fixed Sawrly Noir anchors,
    // leaving Ocean/Purple/Light themes visibly burgundy.
    final backgroundTop = c.heroStart;
    final backgroundMiddle = c.heroMid;
    final backgroundLower = Color.lerp(c.heroMid, c.heroEnd, .58)!;
    final backgroundDeep = c.heroEnd;
    final surfacePrimary = c.surface;
    final surfaceSecondary = theme.visuals.cardTint == Colors.transparent
        ? c.surfaceLight
        : theme.visuals.cardTint;
    final surfaceElevated = c.surfaceLight;
    final glassSurface = theme.visuals.navigationTint == Colors.transparent
        ? c.menuBackground
        : theme.visuals.navigationTint;
    final isLight = c.background.computeLuminance() > .52;

    return PremiumDesignTokens._(
      backgroundTop: backgroundTop,
      backgroundMiddle: backgroundMiddle,
      backgroundLower: backgroundLower,
      backgroundDeep: backgroundDeep,
      surfacePrimary: surfacePrimary,
      surfaceSecondary: surfaceSecondary,
      surfaceElevated: surfaceElevated,
      glassSurface: glassSurface,
      borderSubtle: c.border.withValues(
        alpha: (e.borderOpacity * (.9 + dna.contrast * .25)).clamp(.10, .42),
      ),
      borderHighlight: c.primaryLight.withValues(
        alpha: e.borderOpacity.clamp(.12, .20),
      ),
      textPrimary: c.textPrimary,
      textSecondary: c.textSecondary,
      textMuted: c.textTertiary,
      accentPrimary: Color.lerp(
          c.primary, c.primaryLight, dna.accentStrength.clamp(.12, .45))!,
      accentSoft: Color.lerp(
          c.primary, c.accentPink, dna.accentStrength.clamp(.12, .55))!,
      accentWarm: const Color(0xFFF4B63F),
      priceColor: const Color(0xFFFFC34A),
      // A light palette should use a neutral shadow. Reusing primaryDark
      // here allowed the legacy maroon tone to tint every card and elevated
      // surface after the administrator selected a different theme.
      shadowColor: isLight
          ? Colors.black.withValues(alpha: .16)
          : Color.alphaBlend(
              c.primaryDark.withValues(alpha: .22), Colors.black),
      radiusSmall: e.buttonRadius.clamp(8, 14),
      radiusMedium: e.cardRadius.clamp(14, 26),
      radiusLarge: (e.cardRadius + 6 * dna.radiusStyle).clamp(18, 28),
      radiusFloating: (e.cardRadius + 18 * dna.radiusStyle).clamp(24, 44),
      cardShadowOpacity: e.cardShadowOpacity.clamp(.10, .18),
    );
  }

  LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          backgroundTop,
          backgroundMiddle,
          backgroundLower,
          backgroundDeep,
        ],
        stops: const [0, .32, .70, 1],
      );

  LinearGradient get headerGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(Colors.white.withValues(alpha: .035), glassSurface),
          glassSurface,
          Color.alphaBlend(Colors.black.withValues(alpha: .08), glassSurface),
        ],
      );

  LinearGradient get cardGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [surfaceElevated, surfaceSecondary, surfacePrimary],
        stops: const [0, .48, 1],
      );

  List<BoxShadow> get levelOneShadow => [
        BoxShadow(
          color: shadowColor.withValues(alpha: cardShadowOpacity * .72),
          blurRadius: 16,
          spreadRadius: -5,
          offset: const Offset(0, 6),
        ),
      ];

  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: shadowColor.withValues(alpha: cardShadowOpacity),
          blurRadius: 18,
          spreadRadius: -6,
          offset: const Offset(0, 8),
        ),
      ];

  static const Duration tapDuration = Duration(milliseconds: 140);
  static const Duration stateDuration = Duration(milliseconds: 200);
}
