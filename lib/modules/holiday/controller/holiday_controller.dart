// lib/modules/holiday/controller/holiday_controller.dart

import 'package:flutter/material.dart';
import '../../../model/holiday_model.dart';

class HolidayController extends ChangeNotifier {
  bool _isLoading = false;
  List<HolidayModel> _holidays = [];
  int _selectedYear = DateTime.now().year;
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

  Future<void> fetchHolidays() async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 1));

    _holidays = [
      HolidayModel(id: '1', name: 'Republic Day', date: DateTime(2026, 1, 26), type: 'National', isNational: true),
      HolidayModel(id: '2', name: 'Holi', date: DateTime(2026, 3, 6), type: 'National', isNational: true),
      HolidayModel(id: '3', name: 'Good Friday', date: DateTime(2026, 4, 3), type: 'National', isNational: true),
      HolidayModel(id: '4', name: 'Ram Navami', date: DateTime(2026, 4, 26), type: 'National', isNational: true),
      HolidayModel(id: '5', name: 'Labour Day', date: DateTime(2026, 5, 1), type: 'National', isNational: true),
      HolidayModel(id: '6', name: 'Independence Day', date: DateTime(2026, 8, 15), type: 'National', isNational: true),
      HolidayModel(id: '7', name: 'Ganesh Chaturthi', date: DateTime(2026, 8, 22), type: 'Regional', isNational: false),
      HolidayModel(id: '8', name: 'Gandhi Jayanti', date: DateTime(2026, 10, 2), type: 'National', isNational: true),
      HolidayModel(id: '9', name: 'Dussehra', date: DateTime(2026, 10, 20), type: 'National', isNational: true),
      HolidayModel(id: '10', name: 'Diwali', date: DateTime(2026, 11, 8), type: 'National', isNational: true),
      HolidayModel(id: '11', name: 'Diwali (Laxmi Puja)', date: DateTime(2026, 11, 9), type: 'National', isNational: true),
      HolidayModel(id: '12', name: 'Christmas', date: DateTime(2026, 12, 25), type: 'National', isNational: true),
      // Optional Holidays (Restricted)
      HolidayModel(id: '13', name: 'New Year\'s Day', date: DateTime(2026, 1, 1), type: 'Optional', isNational: false),
      HolidayModel(id: '14', name: 'Guru Govind Singh Jayanti', date: DateTime(2026, 1, 5), type: 'Optional', isNational: false),
      HolidayModel(id: '15', name: 'Basant Panchami', date: DateTime(2026, 1, 23), type: 'Optional', isNational: false),
      HolidayModel(id: '16', name: 'Maha Shivratri', date: DateTime(2026, 2, 15), type: 'Optional', isNational: false),
      HolidayModel(id: '17', name: 'Easter Monday', date: DateTime(2026, 4, 6), type: 'Optional', isNational: false),
      HolidayModel(id: '18', name: 'Raksha Bandhan', date: DateTime(2026, 8, 28), type: 'Optional', isNational: false),
      HolidayModel(id: '19', name: 'Karwa Chauth', date: DateTime(2026, 10, 29), type: 'Optional', isNational: false),
      HolidayModel(id: '20', name: 'Guru Nanak Jayanti', date: DateTime(2026, 11, 24), type: 'Optional', isNational: false),
    ];

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
