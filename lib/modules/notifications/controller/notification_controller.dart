// lib/modules/notifications/controller/notification_controller.dart

import 'package:flutter/material.dart';
import '../../../model/notification_model.dart';

class NotificationController extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  Future<void> fetchNotifications() async {
    await Future.delayed(const Duration(milliseconds: 500));

    _notifications = [
      NotificationModel(
        id: '1',
        title: 'Leave Approved',
        message: 'Your Casual Leave request for 02 Mar 2026 has been approved by Nitin Pagnis.',
        type: 'leave_approved',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false,
      ),
      NotificationModel(
        id: '2',
        title: 'Tour Approved',
        message: 'Your Official Tour to Mumbai (11 May 2026) has been approved.',
        type: 'tour_approved',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        isRead: false,
      ),
      NotificationModel(
        id: '3',
        title: 'Leave Request Received',
        message: 'Your Earned Leave request has been submitted and is pending approval.',
        type: 'leave_pending',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
      ),
      NotificationModel(
        id: '4',
        title: 'Payslip Available',
        message: 'Your payslip for May 2026 is now available for download.',
        type: 'payslip',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        isRead: true,
      ),
      NotificationModel(
        id: '5',
        title: 'System Sync Complete',
        message: 'SAP data synchronization completed successfully. All records are up to date.',
        type: 'system',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        isRead: true,
      ),
    ];

    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = NotificationModel(
        id: _notifications[index].id,
        title: _notifications[index].title,
        message: _notifications[index].message,
        type: _notifications[index].type,
        timestamp: _notifications[index].timestamp,
        isRead: true,
      );
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    _notifications = _notifications
        .map((n) => NotificationModel(
              id: n.id,
              title: n.title,
              message: n.message,
              type: n.type,
              timestamp: n.timestamp,
              isRead: true,
            ))
        .toList();
    _unreadCount = 0;
    notifyListeners();
  }
}
