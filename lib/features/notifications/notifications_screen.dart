import 'package:flutter/material.dart';
import 'package:fotgraf_mobile/models/notification_item.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme_service.dart';
import '../../core/localization/app_locale_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeService>().colors;
    context.watch<AppLocaleService>();
    // Mock Data
    final notifications = [
      NotificationItem(
        id: '1',
        title: tr('طلب حجز جديد', 'New booking request'),
        message: tr('طلب علي سعراً لباقة حفل زفاف', 'Ali requested a quote for a wedding package'),
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: false,
        type: 'booking',
      ),
      NotificationItem(
        id: '2',
        title: tr('تمت الموافقة على المشروع', 'Project approved'),
        message: tr('تم قبول مشروع تصميم الشعار من قبل العميل', 'The logo design project was accepted by the client'),
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: true,
        type: 'approval',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('الإشعارات', 'Notifications')),
      ),
      body: ListView.separated(
        itemCount: notifications.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = notifications[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: item.isRead
                  ? colors.surfaceLight.withValues(alpha: 0.45)
                  : colors.primary.withValues(alpha: 0.12),
              child: Icon(
                _getIcon(item.type),
                color: item.isRead ? colors.textSecondary : colors.primary,
              ),
            ),
            title: Text(
              item.title,
              style: TextStyle(
                fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Text(item.message),
            trailing: Text(
              '${item.timestamp.hour}:${item.timestamp.minute}',
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
            tileColor: item.isRead
                ? colors.surface
                : colors.primary.withValues(alpha: 0.08),
          );
        },
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'booking': return Icons.calendar_today;
      case 'approval': return Icons.check_circle;
      case 'delivery': return Icons.local_shipping;
      default: return Icons.notifications;
    }
  }
}
