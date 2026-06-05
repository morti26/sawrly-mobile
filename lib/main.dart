import 'package:flutter/material.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenStorage = TokenStorage();
  final apiClient = ApiClient(tokenStorage);
  final authService = AuthService(apiClient, tokenStorage);
  final statusService = StatusService(apiClient);
  final mediaService = MediaService(apiClient);
  final notificationService = NotificationService(apiClient);
  final cartService = CartService();
  final supportService = SupportService(apiClient);

  // Start initialization
  await authService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        ChangeNotifierProvider.value(value: statusService),
        Provider.value(value: mediaService),
        ChangeNotifierProvider.value(value: notificationService),
        ChangeNotifierProvider.value(value: cartService), // Add CartService
        ChangeNotifierProvider.value(value: supportService),
        Provider.value(value: apiClient),
      ],
      child: const FotgrafApp(),
    ),
  );
}
