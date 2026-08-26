import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../network/api_client.dart';
import 'app_theme_config.dart';

class AppThemeService extends ChangeNotifier with WidgetsBindingObserver {
  final ApiClient _apiClient;

  AppThemeService(this._apiClient) {
    scheduleMicrotask(attachLifecycleObserver);
  }

  void attachLifecycleObserver() {
    try {
      final binding = WidgetsBinding.instance;
      binding.addObserver(this);
    } catch (e) {
      debugPrint('[ThemeService] attachLifecycleObserver error: $e');
    }
  }

  void detachLifecycleObserver() {
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(loadFromServer(forceRefresh: true));
    }
  }

  @override
  void dispose() {
    detachLifecycleObserver();
    super.dispose();
  }

  static const RemoteThemeColors _defaultColors = RemoteThemeColors(
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

  static const RemoteThemeEffects _defaultEffects = RemoteThemeEffects(
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

  AppThemeConfig _config = const AppThemeConfig(
    colors: _defaultColors,
    navIcons: RemoteNavIcons(),
    effects: _defaultEffects,
    visuals: RemoteThemeVisuals(),
  );
  DateTime? _lastFetchAt;
  bool _isLoading = false;
  bool _isPreviewMode = false;

  AppThemeConfig get config => _config;
  RemoteThemeColors get colors => _config.colors;
  RemoteNavIcons get navIcons => _config.navIcons;
  RemoteThemeEffects get effects => _config.effects;
  RemoteThemeVisuals get visuals => _config.visuals;
  bool get isLoading => _isLoading;
  bool get isPreviewMode => _isPreviewMode;

  /// Applies an unsaved theme sent by the admin preview. This never writes to the API.
  void applyPreview(Map<String, dynamic> raw) {
    // Preview is an isolated, unsaved theme session. Both this service and
    // MainNavigation listen for lifecycle resume events; without this guard a
    // resume immediately fetched the saved server theme and replaced the
    // selected preview palette (typically making every preset look blue).
    _isPreviewMode = true;
    final colors = parseRemoteColors(raw['colors']);
    final effects = parseRemoteEffects(raw['effects']);
    final rawColors = raw['colors'];
    final rawPrimary = rawColors is Map ? rawColors['primary'] : null;
    final rawHeroStart = rawColors is Map ? rawColors['heroStart'] : null;
    debugPrint(
      '[ThemePreview] received primary=$rawPrimary heroStart=$rawHeroStart; '
      'applied primary=0x${colors.primary.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()} '
      'background=0x${colors.background.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
    );
    _config = AppThemeConfig(
        colors: colors,
        navIcons: parseRemoteNavIcons(raw['navIcons']),
        effects: effects,
        visuals: parseRemoteVisuals(raw['visuals']),
        styleDNA: parseRemoteStyleDNA(raw['styleDNA'], schemaVersion: raw['schemaVersion']));
    notifyListeners();
  }

  static const _cacheTtl = Duration(seconds: 10);

  Future<void> loadFromServer({bool forceRefresh = false}) async {
    if (_isPreviewMode) return;
    if (_isLoading) return;
    final now = DateTime.now();
    if (!forceRefresh &&
        _lastFetchAt != null &&
        now.difference(_lastFetchAt!) < _cacheTtl) {
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _apiClient.client.get(
        '/config/public',
        queryParameters: forceRefresh
            ? {'__t': now.millisecondsSinceEpoch.toString()}
            : null,
        options: forceRefresh
            ? Options(headers: {
                'Cache-Control': 'no-cache,no-store,must-revalidate',
                'Pragma': 'no-cache',
              })
            : null,
      );
      final data = response.data;
      if (data is Map) {
        final theme = data['theme'];
        final colors = parseRemoteColors(theme is Map ? theme['colors'] : null);
        final navIcons =
            parseRemoteNavIcons(theme is Map ? theme['navIcons'] : null);
        final effects =
            parseRemoteEffects(theme is Map ? theme['effects'] : null);
        final visuals =
            parseRemoteVisuals(theme is Map ? theme['composerVisuals'] : null);
        final styleDNA = parseRemoteStyleDNA(
            theme is Map ? theme['styleDNA'] : null,
            schemaVersion: theme is Map ? theme['schemaVersion'] : null);
        _config = AppThemeConfig(
            colors: colors,
            navIcons: navIcons,
            effects: effects,
            visuals: visuals,
            styleDNA: styleDNA);
        _lastFetchAt = now;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ThemeService] loadFromServer error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
