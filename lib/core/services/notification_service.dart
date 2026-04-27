import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../../models/notification_item.dart';

class NotificationService extends ChangeNotifier {
  final ApiClient _apiClient;

  List<NotificationItem> _notifications = [];
  bool _isLoading = false;
  String? _error;

  NotificationService(this._apiClient);

  List<NotificationItem> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiClient.client.get('/notifications');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _notifications = data.map((json) => NotificationItem.fromJson(json)).toList();
      } else {
        _error = "Failed to load notifications: ${response.statusCode} ${response.statusMessage}";
        debugPrint(_error);
      }
    } catch (e) {
      _error = e.toString();
      debugPrint("Notification Fetch Error: $_error");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1 || _notifications[index].isRead) {
      return;
    }

    final original = _notifications[index];
    _notifications[index] = original.copyWith(isRead: true);
    notifyListeners();

    try {
      await _apiClient.client.post('/notifications/read', data: {
        'notificationIds': [id],
      });
    } catch (e) {
      _notifications[index] = original;
      _error = e.toString();
      debugPrint("Notification Read Error: $_error");
      notifyListeners();
    }
  }
}
