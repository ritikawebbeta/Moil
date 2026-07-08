// lib/modules/holiday/controller/holiday_controller.dart

import 'package:flutter/material.dart';
import '../../../model/holiday_model.dart';

class HolidayController extends ChangeNotifier {
  bool _isLoading = false;
  List<HolidayModel> _holidays = [];
  int _selectedYear = 2025;
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

    await Future.delayed(const Duration(milliseconds: 300));

    _holidays = [
      // 2025 Public Holidays (from previous screenshot)
      HolidayModel(id: '1', name: 'Republic Day', date: DateTime(2025, 1, 26), type: 'National', isNational: true),
      HolidayModel(id: '2', name: 'Holi', date: DateTime(2025, 3, 14), type: 'National', isNational: true),
      HolidayModel(id: '3', name: 'Dr.Babasaheb Ambedkar Jayanti', date: DateTime(2025, 4, 14), type: 'National', isNational: true),
      HolidayModel(id: '4', name: 'Independence Day', date: DateTime(2025, 8, 15), type: 'National', isNational: true),
      HolidayModel(id: '5', name: 'Narbodh/Pola', date: DateTime(2025, 8, 24), type: 'Regional', isNational: false),
      HolidayModel(id: '6', name: 'Mahatma Gandhi Jayanti', date: DateTime(2025, 10, 2), type: 'National', isNational: true),
      HolidayModel(id: '7', name: 'Diwali', date: DateTime(2025, 10, 20), type: 'National', isNational: true),
      HolidayModel(id: '8', name: 'Diwali', date: DateTime(2025, 10, 21), type: 'National', isNational: true),

      // 2026 Optional/Restricted Holidays (from the new screenshot)
      HolidayModel(id: 'opt1', name: 'NEW YEAR\'S DAY', date: DateTime(2026, 1, 1), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt2', name: 'MAKAR SANKRANTI', date: DateTime(2026, 1, 3), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt3', name: 'PONGAL/GURU GOVIND SINGH\'S BIRTHDAY', date: DateTime(2026, 1, 14), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt4', name: 'BASANT PANCHAMI / SRI PANCHAMI', date: DateTime(2026, 1, 23), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt5', name: 'SHIVAJI JAYANTI', date: DateTime(2026, 2, 1), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt6', name: 'GURU RAVIDAS\'S BIRTHDAY', date: DateTime(2026, 2, 12), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt7', name: 'SWAMI DAYANANDA SARASWATI JAYANTI', date: DateTime(2026, 2, 15), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt8', name: 'MAHA SHIVARATRI', date: DateTime(2026, 2, 19), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt9', name: 'HOLIKA DAHAN, DOLYATRA/EASTER SUNDAY', date: DateTime(2026, 3, 3), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt10', name: 'CHAITRA SUKLADI/ GUDI PADAVA/UGADI/ CHETI CHAND', date: DateTime(2026, 3, 19), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt11', name: 'JAMAT-UI-VIDA', date: DateTime(2026, 3, 20), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt12', name: 'RAM NAVMI', date: DateTime(2026, 3, 26), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt13', name: 'EASTER SUNDAY', date: DateTime(2026, 4, 5), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt14', name: 'VAISHAKHI /VISU/MESHADI (TAMIL NEW YEAR\'S DAY)', date: DateTime(2026, 4, 14), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt15', name: 'VAISAKHADI (BENGAL)/ BAHAG BIHU (ASSAM)', date: DateTime(2026, 4, 15), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt16', name: 'BIRTHDAY OF GURU RABINDRANATH TAGORE', date: DateTime(2026, 5, 9), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt17', name: 'RATH YATRA', date: DateTime(2026, 7, 16), type: 'Optional', isNational: false),
      HolidayModel(id: 'opt18', name: 'PARSI NEW YEAR\'S DAY / NAURAJ', date: DateTime(2026, 8, 15), type: 'Optional', isNational: false),
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
