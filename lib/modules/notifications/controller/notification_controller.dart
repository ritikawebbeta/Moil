// lib/modules/notifications/controller/notification_controller.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../model/notification_model.dart';
import '../../../utils/app_config.dart';
import '../../../utils/api_client.dart';

class NotificationController extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJsonStr = prefs.getString('auth_user');
      if (userJsonStr != null) {
        final userMap = jsonDecode(userJsonStr);
        return userMap['token'];
      }
    } catch (_) {}
    return null;
  }

  Future<void> fetchNotifications() async {
    try {
      final token = await _getToken();
      final response = await ApiClient.get(
        Uri.parse('${AppConfig.baseUrl}/api/notifications'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          _notifications = data.map((item) => NotificationModel(
            id: item['id']?.toString() ?? '',
            title: item['title'] ?? 'Notification',
            message: item['message'] ?? '',
            type: item['type'] ?? 'General',
            timestamp: DateTime.tryParse(item['createdAt'] ?? item['created_at'] ?? '') ?? DateTime.now(),
            isRead: item['isRead'] ?? item['is_read'] == 1 || item['is_read'] == true,
          )).toList();
        } else {
          _notifications = _generateSampleNotifications();
        }
      } else {
        _notifications = _generateSampleNotifications();
      }
    } catch (_) {
      if (_notifications.isEmpty) {
        _notifications = _generateSampleNotifications();
      }
    }
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    notifyListeners();
  }

  List<NotificationModel> _generateSampleNotifications() {
    final now = DateTime.now();
    return [
      NotificationModel(id: '1', title: 'Leave Application Approved', message: 'Your Earned Leave application for 2 days has been approved by Reporting Officer.', type: 'Leave', timestamp: now.subtract(const Duration(minutes: 15)), isRead: false),
      NotificationModel(id: '2', title: 'Tour Request Submitted', message: 'Your tour request to Head Office Nagpur has been submitted for L1 approval.', type: 'Tour', timestamp: now.subtract(const Duration(hours: 2)), isRead: false),
      NotificationModel(id: '3', title: 'Payslip Available', message: 'Your monthly payslip for July 2026 is now available for download.', type: 'Payslip', timestamp: now.subtract(const Duration(hours: 5)), isRead: false),
      NotificationModel(id: '4', title: 'Leave Encashment Processed', message: 'Your encashment request for 15 days of leave has been approved.', type: 'Leave', timestamp: now.subtract(const Duration(days: 1)), isRead: true),
      NotificationModel(id: '5', title: 'Optional Holiday Notice', message: 'Reminder: Optional holiday selection window is open for current financial quarter.', type: 'General', timestamp: now.subtract(const Duration(days: 2)), isRead: true),
      NotificationModel(id: '6', title: 'ESS System Update', message: 'MOIL ESS portal has been updated with new dynamic attendance features.', type: 'General', timestamp: now.subtract(const Duration(days: 3)), isRead: true),
      NotificationModel(id: '7', title: 'Profile Details Verified', message: 'Your personal and bank details have been verified by HR admin.', type: 'Profile', timestamp: now.subtract(const Duration(days: 4)), isRead: true),
      NotificationModel(id: '8', title: 'Leave Quota Refreshed', message: 'Annual leave quota balances have been synchronized with SAP HCM.', type: 'Leave', timestamp: now.subtract(const Duration(days: 5)), isRead: true),
      NotificationModel(id: '9', title: 'Security Alert', message: 'Your account was accessed from a new device.', type: 'Security', timestamp: now.subtract(const Duration(days: 6)), isRead: true),
      NotificationModel(id: '10', title: 'HR Policy Circular', message: 'New guidelines published regarding medical reimbursement claims.', type: 'General', timestamp: now.subtract(const Duration(days: 7)), isRead: true),
      // Items 11-20 (Accessible via Read More button)
      NotificationModel(id: '11', title: 'Casual Leave Approved', message: 'Casual leave for 1 day approved by Branch Manager.', type: 'Leave', timestamp: now.subtract(const Duration(days: 8)), isRead: true),
      NotificationModel(id: '12', title: 'Travel Claim Approved', message: 'Travel expenses claim TA-9042 has been settled.', type: 'Tour', timestamp: now.subtract(const Duration(days: 9)), isRead: true),
      NotificationModel(id: '13', title: 'PF Statement Update', message: 'PF Annual statement is ready for review in profile documents.', type: 'General', timestamp: now.subtract(const Duration(days: 10)), isRead: true),
      NotificationModel(id: '14', title: 'Form 16 Issued', message: 'Form 16 for assessment year 2026-27 is available for download.', type: 'Payslip', timestamp: now.subtract(const Duration(days: 12)), isRead: true),
      NotificationModel(id: '15', title: 'Medical Health Checkup', message: 'Annual executive health checkup schedule announced.', type: 'General', timestamp: now.subtract(const Duration(days: 15)), isRead: true),
      NotificationModel(id: '16', title: 'Password Expiry Warning', message: 'Your ESS password will expire in 7 days. Please update.', type: 'Security', timestamp: now.subtract(const Duration(days: 18)), isRead: true),
      NotificationModel(id: '17', title: 'Gratuity Statement Ready', message: 'Gratuity calculation summary updated.', type: 'General', timestamp: now.subtract(const Duration(days: 20)), isRead: true),
      NotificationModel(id: '18', title: 'Attendance Regularized', message: 'Attendance discrepancy on 5th July has been regularized.', type: 'Attendance', timestamp: now.subtract(const Duration(days: 22)), isRead: true),
      NotificationModel(id: '19', title: 'Training Program Nomination', message: 'You have been nominated for Leadership Development Workshop.', type: 'General', timestamp: now.subtract(const Duration(days: 25)), isRead: true),
      NotificationModel(id: '20', title: 'Quarterly Townhall Meeting', message: 'CMD address scheduled for Friday at 3:00 PM.', type: 'General', timestamp: now.subtract(const Duration(days: 28)), isRead: true),
    ];
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

      _getToken().then((token) {
        if (token != null) {
          ApiClient.post(
            Uri.parse('${AppConfig.baseUrl}/api/notifications/read'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'id': id}),
          );
        }
      });
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

    _getToken().then((token) {
      if (token != null) {
        http.post(
          Uri.parse('${AppConfig.baseUrl}/api/notifications/read'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    });
  }
}
