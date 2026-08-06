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
  );
  DateTime? _lastFetchAt;
  bool _isLoading = false;

  AppThemeConfig get config => _config;
  RemoteThemeColors get colors => _config.colors;
  RemoteNavIcons get navIcons => _config.navIcons;
  RemoteThemeEffects get effects => _config.effects;
  bool get isLoading => _isLoading;

  static const _cacheTtl = Duration(seconds: 10);

  Future<void> loadFromServer({bool forceRefresh = false}) async {
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
        final navIcons = parseRemoteNavIcons(theme is Map ? theme['navIcons'] : null);
        final effects = parseRemoteEffects(theme is Map ? theme['effects'] : null);
        _config = AppThemeConfig(colors: colors, navIcons: navIcons, effects: effects);
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
