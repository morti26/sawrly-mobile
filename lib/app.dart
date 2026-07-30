import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'features/navigation/main_navigation.dart';
import 'core/design/design_tokens.dart';
import 'core/theme/app_theme_service.dart';

class FotgrafApp extends StatelessWidget {
  const FotgrafApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppThemeService>(
      builder: (context, themeService, child) {
        final c = themeService.colors;
        final e = themeService.effects;
        final chipRadius = BorderRadius.circular(e.chipRadius >= 999 ? 9999 : e.chipRadius);
        final cardRadius = BorderRadius.circular(e.cardRadius);
        final buttonRadius = BorderRadius.circular(e.buttonRadius);
        final cardShadowOpacity = e.cardShadowOpacity.clamp(0.0, 1.0);

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
            colorScheme: ColorScheme.fromSeed(
              seedColor: c.primary,
              brightness: Brightness.dark,
              surface: c.surface,
              primary: c.primary,
              onPrimary: c.textPrimary,
              onSurface: c.textPrimary,
            ),
            scaffoldBackgroundColor: c.background,
            appBarTheme: AppBarTheme(
              backgroundColor: c.background.withValues(alpha: e.surfaceOpacity.clamp(0.5, 1.0)),
              foregroundColor: c.textPrimary,
              elevation: 0,
              scrolledUnderElevation: 0,
              shadowColor: Colors.black.withValues(alpha: cardShadowOpacity),
              surfaceTintColor: Colors.transparent,
            ),
            cardTheme: CardThemeData(
              color: c.surface.withValues(alpha: e.surfaceOpacity),
              elevation: 0,
              shadowColor: Colors.black.withValues(alpha: cardShadowOpacity),
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: cardRadius,
                side: BorderSide(color: c.borderLight.withValues(alpha: e.borderOpacity)),
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: c.surfaceLight.withValues(alpha: e.surfaceOpacity),
              selectedColor: c.primary.withValues(alpha: 0.18),
              labelStyle: AppTextStyles.bodySmall.copyWith(color: c.textPrimary),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: chipRadius),
              side: BorderSide(
                color: c.borderLight.withValues(alpha: e.borderOpacity.clamp(0, 0.8)),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: c.surface.withValues(alpha: e.surfaceOpacity),
              border: OutlineInputBorder(
                borderRadius: cardRadius,
                borderSide: BorderSide(color: c.border.withValues(alpha: e.borderOpacity)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: cardRadius,
                borderSide: BorderSide(color: c.border.withValues(alpha: e.borderOpacity)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: cardRadius,
                borderSide: BorderSide(color: c.primary, width: 2),
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
                backgroundColor: c.primary,
                foregroundColor: c.textPrimary,
                elevation: 0,
                shadowColor: c.primary.withValues(alpha: 0.45),
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
                foregroundColor: c.primary,
                shape: RoundedRectangleBorder(borderRadius: buttonRadius),
                textStyle: AppTextStyles.button,
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: c.primary,
                side: BorderSide(color: c.border.withValues(alpha: e.borderOpacity)),
                shape: RoundedRectangleBorder(borderRadius: buttonRadius),
                textStyle: AppTextStyles.button,
              ),
            ),
            useMaterial3: true,
          ),
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.ltr,
              child: child!,
            );
          },
          home: child,
        );
      },
      child: const MainNavigation(),
    );
  }
}
