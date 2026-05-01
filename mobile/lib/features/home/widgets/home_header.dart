import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../notifications/notification_screen.dart';
import '../../support/support_chat_screen.dart';
import '../../../core/services/media_service.dart';

/// Camera logo built from pure Flutter widgets — no PNG, no white background, never black
class CameraLogoWidget extends StatelessWidget {
  final double size;
  const CameraLogoWidget({super.key, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            // ── Blue base (full background) ──
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),

            // ── Orange sector top-right ──
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: size * 0.60,
                height: size * 0.60,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFCA28), Color(0xFFEF5350)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.elliptical(200, 200),
                  ),
                ),
              ),
            ),

            // ── Purple sector bottom-right ──
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.62,
                height: size * 0.62,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFAB47BC), Color(0xFF4527A0)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.elliptical(200, 200),
                  ),
                ),
              ),
            ),

            // ── Lens: white ring ──
            Center(
              child: Container(
                width: size * 0.58,
                height: size * 0.58,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),

            // ── Lens: dark body with blue radial gradient ──
            Center(
              child: Container(
                width: size * 0.50,
                height: size * 0.50,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF000000)],
                    center: Alignment(-0.3, -0.3),
                    stops: [0.2, 1.0],
                  ),
                ),
              ),
            ),

            // ── Lens: highlight reflection ──
            Positioned(
              left: size * 0.25,
              top: size * 0.20,
              child: Container(
                width: size * 0.12,
                height: size * 0.12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final iconColor = Colors.white.withValues(alpha: 0.85);
    final logoFuture = context.read<MediaService>().fetchHomeLogoUrl();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF141C28).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: FutureBuilder<String?>(
                    future: logoFuture,
                    builder: (context, snapshot) {
                      final logoUrl = snapshot.data?.trim();
                      if (logoUrl != null && logoUrl.isNotEmpty) {
                        return Image.network(
                          logoUrl,
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Image.asset(
                              'assets/images/logo.png',
                              width: 30,
                              height: 30,
                              fit: BoxFit.cover,
                            );
                          },
                        );
                      }
                      return Image.asset(
                        'assets/images/logo.png',
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'صورلي',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationScreen()),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                  icon: Icon(Icons.notifications_none, size: 22, color: iconColor),
                ),
                const SizedBox(width: 14),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SupportChatScreen()),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                  icon: Icon(Icons.headset_mic_outlined, size: 20, color: iconColor),
                  tooltip: 'تحدث مع الدعم', // Chat with Support
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
