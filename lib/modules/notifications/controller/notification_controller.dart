// lib/modules/notifications/controller/notification_controller.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../model/notification_model.dart';
import '../../../utils/app_config.dart';

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
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/notifications'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _notifications = data.map((item) => NotificationModel(
          id: item['id'] ?? '',
          title: item['title'] ?? '',
          message: item['message'] ?? '',
          type: item['type'] ?? 'General',
          timestamp: DateTime.tryParse(item['createdAt'] ?? '') ?? DateTime.now(),
          isRead: item['isRead'] ?? false,
        )).toList();
        _unreadCount = _notifications.where((n) => !n.isRead).length;
      }
    } catch (_) {}
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

      _getToken().then((token) {
        if (token != null) {
          http.post(
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
