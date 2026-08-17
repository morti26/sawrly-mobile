import 'package:flutter/material.dart';
import 'package:fotgraf_mobile/models/notification_item.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<AppThemeService>().colors;
    // Mock Data
    final notifications = [
      NotificationItem(
        id: '1',
        title: 'طلب حجز جديد',
        message: 'طلب علي سعراً لباقة حفل زفاف',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        isRead: false,
        type: 'booking',
      ),
      NotificationItem(
        id: '2',
        title: 'تمت الموافقة على المشروع',
        message: 'تم قبول مشروع تصميم الشعار من قبل العميل',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: true,
        type: 'approval',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
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
