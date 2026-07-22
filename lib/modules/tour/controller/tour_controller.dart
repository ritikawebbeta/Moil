// lib/modules/tour/controller/tour_controller.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../model/tour_model.dart';
import '../../../utils/app_config.dart';

enum TourStatus { initial, loading, loaded, error }

class TourController extends ChangeNotifier {
  TourStatus _status = TourStatus.initial;
  List<TourModel> _tours = [];
  List<TourModel> _pendingApprovals = [];
  String? _errorMessage;

  TourStatus get status => _status;
  List<TourModel> get tours => _tours;
  List<TourModel> get pendingApprovals => _pendingApprovals;
  String? get errorMessage => _errorMessage;

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

  Future<void> fetchTours(String employeeId) async {
    _status = TourStatus.loading;
    notifyListeners();

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/tours?employee_id=$employeeId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _tours = data.map((item) => TourModel.fromJson(item)).toList();
        _status = TourStatus.loaded;
      } else {
        _status = TourStatus.error;
      }
    } catch (e) {
      _status = TourStatus.error;
    }
    notifyListeners();
  }

  Future<bool> applyTour(TourModel tour) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/tours/apply'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'destination': tour.destination,
          'start_date': tour.startDate.toIso8601String().split('T')[0],
          'end_date': tour.endDate.toIso8601String().split('T')[0],
          'purpose': tour.travelPurpose,
          'transport_mode': tour.transportMode,
          'tour_type': tour.tourType,
        }),
      );
      if (response.statusCode == 201) {
        await fetchTours(tour.employeeId);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteTour(String tourId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _tours.removeWhere((t) => t.id == tourId);
    notifyListeners();
    return true;
  }

  Future<void> fetchPendingApprovals() async {
    _status = TourStatus.loading;
    notifyListeners();

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/tours/pending-approvals'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _pendingApprovals = data.map((item) => TourModel.fromJson(item)).toList();
        _status = TourStatus.loaded;
      } else {
        _status = TourStatus.error;
      }
    } catch (e) {
      _status = TourStatus.error;
    }
    notifyListeners();
  }

  Future<bool> approveTour(String tourId, String remarks) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/tours/approve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'tour_id': tourId,
          'remarks': remarks,
        }),
      );
      if (response.statusCode == 200) {
        _pendingApprovals.removeWhere((t) => t.id == tourId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectTour(String tourId, String remarks) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/tours/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'tour_id': tourId,
          'remarks': remarks,
        }),
      );
      if (response.statusCode == 200) {
        _pendingApprovals.removeWhere((t) => t.id == tourId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> _teamCalendar = [];
  List<Map<String, dynamic>> get teamCalendar => _teamCalendar;

  Future<void> fetchTeamCalendar() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/tours/team-calendar'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _teamCalendar = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }
}
