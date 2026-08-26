import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fotgraf_mobile/core/auth/token_storage.dart';
import 'package:fotgraf_mobile/core/design/design_tokens.dart';
import 'package:fotgraf_mobile/core/network/api_client.dart';
import 'package:fotgraf_mobile/core/theme/app_theme_background.dart';
import 'package:fotgraf_mobile/core/theme/app_theme_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saved server theme cannot overwrite an active admin preview', () async {
    final service = AppThemeService(ApiClient(TokenStorage()));

    service.applyPreview({
      'colors': {
        // The Theme Engine uses CSS #RRGGBBAA, not Flutter's 0xAARRGGBB.
        'primary': '#E4255BFF',
        'primaryLight': '#F59AB5FF',
        'primaryDark': '#9F1239FF',
        'background': '#380D24FF',
        'heroStart': '#380D24FF',
        'heroMid': '#E4255BFF',
        'heroEnd': '#E35997FF',
      },
    });

    expect(service.isPreviewMode, isTrue);
    expect(service.colors.primary.toARGB32(), 0xFFE4255B);
    expect(service.colors.background.toARGB32(), 0xFF380D24);

    // Both the service and MainNavigation can request this on lifecycle
    // resume. In preview mode it must be a no-op and must not fetch the saved
    // (often blue) production palette.
    await service.loadFromServer(forceRefresh: true);

    expect(service.colors.primary.toARGB32(), 0xFFE4255B);
    expect(service.colors.heroMid.toARGB32(), 0xFFE4255B);
    service.dispose();
  });

  test('preview accepts versioned Style DNA without breaking legacy colors', () {
    final service = AppThemeService(ApiClient(TokenStorage()));
    service.applyPreview({
      'schemaVersion': 2,
      'styleDNA': {
        'darkness': .82,
        'contrast': .9,
        'accentStrength': .18,
        'glassStrength': .54,
        'ambientLight': .18,
        'vignetteStrength': .22,
        'radiusStyle': .72,
      },
      'colors': {'primary': '#9F1239FF'}
    });

    expect(service.config.styleDNA.schemaVersion, 2);
    expect(service.config.styleDNA.contrast, .9);
    expect(service.colors.primary.toARGB32(), 0xFF9F1239);
    service.dispose();
  });

  test('custom surfaces derive hero tones instead of legacy maroon fallbacks', () {
    final service = AppThemeService(ApiClient(TokenStorage()));
    service.applyPreview({
      'colors': {
        'background': '#F8FAFCFF',
        'surface': '#E2E8F0FF',
        'surfaceLight': '#FFFFFFFF',
        'textPrimary': '#111827FF',
      },
    });

    // A payload with its own light surfaces must not recreate the default
    // maroon hero midpoint/end just because optional hero keys were omitted.
    expect(service.colors.heroMid.computeLuminance(), greaterThan(.5));
    expect(service.colors.heroEnd.computeLuminance(), greaterThan(.5));
    expect(service.colors.heroMid.toARGB32(), isNot(0xFF3E0A1B));
    service.dispose();
  });

  testWidgets('shared route background premium-tones the composer gradient',
      (tester) async {
    final service = AppThemeService(ApiClient(TokenStorage()));
    service.applyPreview({
      'colors': {
        'heroStart': '#380D24FF',
        'heroMid': '#E4255BFF',
        'heroEnd': '#E35997FF',
      },
    });

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: service,
        child: MaterialApp(
          theme: ThemeData(scaffoldBackgroundColor: Colors.transparent),
          home: const AppThemeBackground(
            child: Scaffold(body: SizedBox.expand()),
          ),
        ),
      ),
    );

    final background = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(AppThemeBackground),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = background.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;

    final premium = PremiumDesignTokens.from(service.config);
    expect(
      gradient.colors.map((color) => color.toARGB32()),
      premium.backgroundGradient.colors.map((color) => color.toARGB32()),
    );
    // The composer may intentionally provide bright hero tones; the shared
    // renderer must preserve the selected palette rather than forcing every
    // gradient stop into the historical dark-maroon range.
    expect(gradient.colors.first.toARGB32(), 0xFF380D24);
    expect(gradient.colors[1].toARGB32(), 0xFFE4255B);
    final scaffoldContext = tester.element(find.byType(Scaffold));
    expect(
      Theme.of(scaffoldContext).scaffoldBackgroundColor,
      Colors.transparent,
    );
    service.dispose();
  });
}
