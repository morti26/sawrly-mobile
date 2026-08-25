import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/auth/auth_service.dart';
import 'core/auth/token_storage.dart';
import 'core/network/api_client.dart';
import 'core/services/status_service.dart';
import 'core/services/cart_service.dart';
import 'core/services/media_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/support_service.dart';
import 'core/theme/app_theme_service.dart';
import 'core/localization/app_locale_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep Android's controls visible. The themed navigation-bar surface is
  // synchronized in App so Samsung's three-button mode cannot add a black
  // contrast slab behind the Flutter navigation.
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Color(0xFF1D0812),
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage);
  final authService = AuthService(apiClient, tokenStorage);
  final statusService = StatusService(apiClient);
  final mediaService = MediaService(apiClient);
  final notificationService = NotificationService(apiClient);
  final cartService = CartService();
  final supportService = SupportService(apiClient);
  final themeService = AppThemeService(apiClient);
  final localeService = AppLocaleService();
  await localeService.init();

  final previewPayload = Uri.base.queryParameters['previewTheme'];
  var isPreview = false;
  var initialPreviewTab = 0;
  final directPreviewColors = <String, dynamic>{};
  const previewColorKeys = [
    'primary',
    'primaryLight',
    'primaryDark',
    'accentPink',
    'background',
    'surface',
    'surfaceLight',
    'cardBackground',
    'cardBorder',
    'menuBackground',
    'textPrimary',
    'textSecondary',
    'textTertiary',
    'border',
    'borderLight',
    'heroStart',
    'heroMid',
    'heroEnd',
    'onPrimary',
    'onSurface',
  ];
  for (final key in previewColorKeys) {
    final value = Uri.base.queryParameters['preview_$key'];
    if (value != null && value.isNotEmpty) directPreviewColors[key] = value;
  }
  if (directPreviewColors.isNotEmpty) {
    themeService.applyPreview({'colors': directPreviewColors});
    isPreview = true;
  } else if (previewPayload != null && previewPayload.isNotEmpty) {
    try {
      // Accept both regular Base64 (admin panel) and URL-safe Base64. A
      // decode failure must never silently replace a selected theme with the
      // default blue palette.
      final normalized =
          previewPayload.replaceAll('-', '+').replaceAll('_', '/');
      final decoded = utf8.decode(base64.decode(base64.normalize(normalized)));
      final raw = jsonDecode(decoded);
      if (raw is Map) {
        themeService.applyPreview(Map<String, dynamic>.from(raw));
        isPreview = true;
      }
    } catch (_) {
      // Preview parameters are best-effort; normal server theme remains active.
    }
  }
  if (isPreview) {
    initialPreviewTab =
        (int.tryParse(Uri.base.queryParameters['previewTab'] ?? '') ?? 0)
            .clamp(0, 4);
  }
  // The embedded admin preview must render without waiting for authentication
  // or a live API session. The real app still initializes auth normally.
  if (!isPreview) {
    await authService.init();
  }
  // Theme init is best-effort: if the request fails, the app still uses defaults.
  if (!isPreview) {
    unawaited(themeService.loadFromServer());
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: statusService),
        Provider.value(value: mediaService),
        ChangeNotifierProvider.value(value: notificationService),
        ChangeNotifierProvider.value(value: cartService), // Add CartService
        ChangeNotifierProvider.value(value: supportService),
        ChangeNotifierProvider.value(value: themeService),
        ChangeNotifierProvider.value(value: localeService),
        Provider.value(value: apiClient),
      ],
      child: FotgrafApp(initialPreviewTab: initialPreviewTab),
    ),
  );
}
