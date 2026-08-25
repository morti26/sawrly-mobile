import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../design/design_tokens.dart';
import 'app_theme_config.dart';
import 'app_theme_service.dart';

/// One shared renderer for the selected Theme Composer background.
///
/// It lives above the app navigator so every route receives the same gradient,
/// mesh, ambient glow, noise and vignette. Individual screens should keep
/// their Scaffold transparent and use theme surfaces only for actual cards.
class AppThemeBackground extends StatelessWidget {
  final Widget child;

  const AppThemeBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeService>();
    final visuals = theme.visuals;
    final premium = PremiumDesignTokens.from(theme.config);
    final size = MediaQuery.sizeOf(context);
    final isLight = theme.colors.background.computeLuminance() > .52;

    Widget glowLayer(ThemeGlow glow, double blurFactor, double spreadFactor) {
      return Positioned(
        left: size.width * glow.x - glow.radius / 2,
        top: size.height * glow.y - glow.radius / 2,
        width: glow.radius,
        height: glow.radius,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: glow.color.withValues(alpha: glow.opacity * .16),
              boxShadow: [
                BoxShadow(
                  color: glow.color.withValues(alpha: glow.opacity * .20),
                  blurRadius: glow.radius * blurFactor,
                  spreadRadius: glow.radius * spreadFactor,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: premium.backgroundGradient,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Constant, very low-cost ambient lighting. These two layers are
            // intentionally subtle and avoid runtime blur filters.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-.55, -.92),
                    radius: .78,
                    colors: [
                      premium.accentPrimary.withValues(alpha: .055),
                      Colors.transparent,
                    ],
                    stops: const [0, 1],
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      // Keep the depth treatment neutral for light themes.
                      // Tinting this layer with primaryDark made the legacy
                      // maroon color bleed back in at the bottom of every
                      // screen even after a new palette was selected.
                      Colors.black.withValues(alpha: isLight ? .035 : .22),
                    ],
                    stops: const [.58, 1],
                  ),
                ),
              ),
            ),
            if (visuals.meshEnabled)
              ...visuals.meshPoints.map((glow) => glowLayer(glow, .42, .05)),
            ...visuals.ambientGlows.map((glow) => glowLayer(glow, .38, .04)),
            if (visuals.vignetteEnabled)
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: visuals.vignetteStrength > .08 ? .95 : 1.1,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(
                          alpha: visuals.vignetteStrength.clamp(0, 1),
                        ),
                      ],
                      stops: const [.56, 1],
                    ),
                  ),
                ),
              ),
            if (visuals.noiseEnabled)
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.white.withValues(
                    alpha: visuals.noiseOpacity.clamp(0, 1),
                  ),
                ),
              ),
            child,
          ],
        ),
      ),
    );
  }
}
