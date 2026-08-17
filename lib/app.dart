import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'features/navigation/main_navigation.dart';
import 'core/design/design_tokens.dart';
import 'core/theme/app_theme_service.dart';
import 'core/theme/app_theme_background.dart';

class FotgrafApp extends StatelessWidget {
  final int initialPreviewTab;

  const FotgrafApp({super.key, this.initialPreviewTab = 0});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppThemeService>(
      builder: (context, themeService, child) {
        final c = themeService.colors;
        final e = themeService.effects;
        final premium = PremiumDesignTokens.from(themeService.config);
        final chipRadius =
            BorderRadius.circular(e.chipRadius >= 999 ? 9999 : e.chipRadius);
        final cardRadius = BorderRadius.circular(e.cardRadius);
        final buttonRadius = BorderRadius.circular(e.buttonRadius);
        final cardShadowOpacity = e.cardShadowOpacity.clamp(0.0, 1.0);

        final colorScheme = ColorScheme.fromSeed(
          seedColor: c.primary,
          brightness: Brightness.dark,
          surface: premium.surfacePrimary,
          primary: premium.accentPrimary,
          onPrimary: premium.textPrimary,
          onSurface: premium.textPrimary,
        );

        final smallLabel = AppTextStyles.label.copyWith(
          fontSize: 10,
          height: 1.2,
          letterSpacing: 0.2,
        );

        return MaterialApp(
          title: 'صورلي',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar', ''),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ar', ''),
          ],
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData(
            fontFamily: AppTextStyles.fontFamily,
            colorScheme: colorScheme,
            // The shared AppThemeBackground renders behind every route.
            // Scaffolds stay transparent so they cannot hide the selected
            // Theme Composer gradient on non-home screens.
            scaffoldBackgroundColor: Colors.transparent,
            appBarTheme: AppBarTheme(
              backgroundColor: premium.glassSurface
                  .withValues(alpha: e.surfaceOpacity.clamp(0.5, 1.0)),
              foregroundColor: premium.textPrimary,
              elevation: 0,
              scrolledUnderElevation: 0,
              shadowColor: Colors.black.withValues(alpha: cardShadowOpacity),
              surfaceTintColor: Colors.transparent,
            ),
            cardTheme: CardThemeData(
              color: premium.surfaceSecondary.withValues(alpha: .94),
              elevation: 0,
              shadowColor: Colors.black.withValues(alpha: cardShadowOpacity),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: cardRadius,
                side: BorderSide(color: premium.borderSubtle),
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: premium.surfaceSecondary,
              selectedColor: premium.accentPrimary.withValues(alpha: 0.18),
              labelStyle:
                  AppTextStyles.bodySmall.copyWith(color: c.textPrimary),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: chipRadius),
              side: BorderSide(
                color: premium.borderSubtle,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: premium.surfaceSecondary.withValues(alpha: .92),
              border: OutlineInputBorder(
                borderRadius: cardRadius,
                borderSide: BorderSide(color: premium.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: cardRadius,
                borderSide: BorderSide(color: premium.borderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: cardRadius,
                borderSide: BorderSide(color: premium.accentPrimary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: cardRadius,
                borderSide: BorderSide(color: c.error),
              ),
              labelStyle: AppTextStyles.label,
              hintStyle: AppTextStyles.body.copyWith(color: c.textTertiary),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: premium.accentPrimary,
                foregroundColor: premium.textPrimary,
                elevation: 0,
                shadowColor: premium.accentPrimary.withValues(alpha: 0.28),
                shape: RoundedRectangleBorder(borderRadius: buttonRadius),
                textStyle: AppTextStyles.button,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.md,
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: premium.accentPrimary,
                shape: RoundedRectangleBorder(borderRadius: buttonRadius),
                textStyle: AppTextStyles.button,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: premium.accentPrimary,
                side: BorderSide(color: premium.borderSubtle),
                shape: RoundedRectangleBorder(borderRadius: buttonRadius),
                textStyle: AppTextStyles.button,
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: premium.glassSurface.withValues(alpha: .96),
              elevation: 0,
              shadowColor: Colors.black
                  .withValues(alpha: e.navShadowOpacity.clamp(0, 1)),
              surfaceTintColor: Colors.transparent,
              indicatorColor: premium.accentPrimary.withValues(alpha: 0.22),
              height: 68,
              labelTextStyle: WidgetStatePropertyAll(
                  smallLabel.copyWith(color: premium.textSecondary)),
              iconTheme: WidgetStatePropertyAll(
                IconThemeData(color: premium.textSecondary, size: 24),
              ),
            ),
            badgeTheme: BadgeThemeData(
              backgroundColor: colorScheme.tertiary,
              textColor: colorScheme.onTertiary,
              smallSize: 8,
              largeSize: 18,
              textStyle: smallLabel.copyWith(
                color: colorScheme.onTertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              backgroundColor: premium.surfaceElevated,
              contentTextStyle: AppTextStyles.bodySmall.copyWith(
                color: c.textPrimary,
              ),
              shape: RoundedRectangleBorder(borderRadius: cardRadius),
              behavior: SnackBarBehavior.floating,
              elevation: 4,
              actionTextColor: premium.accentPrimary,
              closeIconColor: premium.textPrimary,
            ),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
                TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
              },
            ),
            useMaterial3: true,
          ),
          builder: (context, child) {
            final isAndroid =
                Theme.of(context).platform == TargetPlatform.android;
            final deepTone = HSLColor.fromColor(premium.backgroundDeep);
            final systemNavigationSurface = isAndroid
                ? deepTone
                    .withLightness((deepTone.lightness * 1.4).clamp(0.0, 1.0))
                    .toColor()
                : premium.backgroundDeep;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
                // Home renders this exact final gradient tone at the bottom.
                // Matching it removes the visible seam around Samsung's
                // persistent three-button navigation area.
                systemNavigationBarColor: systemNavigationSurface,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarIconBrightness: Brightness.light,
                systemNavigationBarContrastEnforced: false,
              ),
              child: AppThemeBackground(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: child!,
                ),
              ),
            );
          },
          home: child,
        );
      },
      child: MainNavigation(initialIndex: initialPreviewTab),
    );
  }
}
