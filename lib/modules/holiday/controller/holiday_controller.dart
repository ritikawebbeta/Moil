// lib/modules/holiday/controller/holiday_controller.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../model/holiday_model.dart';
import '../../../utils/app_config.dart';

class HolidayController extends ChangeNotifier {
  bool _isLoading = false;
  List<HolidayModel> _holidays = [];
  int _selectedYear = 2026;
  int? _selectedMonth;

  bool get isLoading => _isLoading;
  List<HolidayModel> get holidays => _holidays;
  int get selectedYear => _selectedYear;
  int? get selectedMonth => _selectedMonth;

  List<HolidayModel> get filteredHolidays {
    return _holidays.where((h) {
      final yearMatch = h.date.year == _selectedYear;
      final monthMatch = _selectedMonth == null || h.date.month == _selectedMonth;
      return yearMatch && monthMatch;
    }).toList();
  }

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

  Future<void> fetchHolidays() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/holidays'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _holidays = data.map((item) => HolidayModel(
          id: item['id'] ?? '',
          name: item['name'] ?? '',
          date: DateTime.tryParse(item['date'] ?? '') ?? DateTime.now(),
          type: item['type'] ?? 'Optional',
          isNational: item['type'] == 'Mandatory',
        )).toList();
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  void setYear(int year) {
    _selectedYear = year;
    notifyListeners();
  }

  void setMonth(int? month) {
    _selectedMonth = month;
    notifyListeners();
  }
}
