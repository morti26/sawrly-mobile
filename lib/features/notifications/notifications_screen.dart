import 'package:flutter/material.dart';
import 'package:fotgraf_mobile/models/notification_item.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  ? Colors.grey.shade200
                  : Colors.blue.withValues(alpha: 0.1),
              child: Icon(
                _getIcon(item.type),
                color: item.isRead ? Colors.grey : Colors.blue,
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
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            tileColor: item.isRead
                ? Colors.white
                : Colors.blue.withValues(alpha: 0.05),
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
