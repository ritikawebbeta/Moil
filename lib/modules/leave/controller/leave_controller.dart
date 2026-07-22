// lib/modules/leave/controller/leave_controller.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../model/leave_model.dart';
import '../../../utils/app_config.dart';

enum LeaveStatus { initial, loading, loaded, error }

class LeaveController extends ChangeNotifier {
  LeaveStatus _status = LeaveStatus.initial;
  List<LeaveModel> _leaves = [];
  List<LeaveBalanceModel> _balances = [];
  List<LeaveModel> _pendingApprovals = [];
  String? _errorMessage;

  DateTime _showFrom = DateTime(2026, 2, 1);
  String _selectedTimeAccount = 'All Types';
  DateTime _timeAccountShowFrom = DateTime(2026, 1, 1);
  int _activeTabIndex = 0;

  LeaveStatus get status => _status;
  List<LeaveModel> get leaves => _leaves;
  List<LeaveBalanceModel> get balances => _balances;
  List<LeaveModel> get pendingApprovals => _pendingApprovals;
  String? get errorMessage => _errorMessage;

  DateTime get showFrom => _showFrom;
  String get selectedTimeAccount => _selectedTimeAccount;
  DateTime get timeAccountShowFrom => _timeAccountShowFrom;
  int get activeTabIndex => _activeTabIndex;

  void setActiveTabIndex(int index) {
    if (_activeTabIndex != index) {
      _activeTabIndex = index;
      notifyListeners();
    }
  }

  void updateShowFrom(DateTime val) {
    _showFrom = val;
    notifyListeners();
  }

  void updateSelectedTimeAccount(String val) {
    _selectedTimeAccount = val;
    notifyListeners();
  }

  void updateTimeAccountShowFrom(DateTime val) {
    _timeAccountShowFrom = val;
    notifyListeners();
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

  Future<void> fetchLeaves(String employeeId) async {
    _status = LeaveStatus.loading;
    notifyListeners();

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/leaves?employee_id=$employeeId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _leaves = data.map((item) => LeaveModel.fromJson(item)).toList();
        _status = LeaveStatus.loaded;
      } else {
        _status = LeaveStatus.error;
      }
    } catch (e) {
      _status = LeaveStatus.error;
    }
    notifyListeners();
  }

  Future<void> fetchBalances(String employeeId) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/leave-balances?employee_id=$employeeId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _balances = data.map((item) => LeaveBalanceModel.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> applyLeave(LeaveApplicationRequest request) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/leaves/apply'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'leave_type': request.leaveType,
          'start_date': request.startDate.toIso8601String().split('T')[0],
          'end_date': request.endDate.toIso8601String().split('T')[0],
          'start_time': request.beginTime,
          'end_time': request.endTime,
          'duration': request.duration,
          'reason': request.note ?? '',
        }),
      );

      if (response.statusCode == 201) {
        await fetchLeaves(request.employeeId);
        await fetchBalances(request.employeeId);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> fetchPendingApprovals() async {
    _status = LeaveStatus.loading;
    notifyListeners();

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/leaves/pending-approvals'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _pendingApprovals = data.map((item) => LeaveModel.fromJson(item)).toList();
        _status = LeaveStatus.loaded;
      } else {
        _status = LeaveStatus.error;
      }
    } catch (e) {
      _status = LeaveStatus.error;
    }
    notifyListeners();
  }

  Future<bool> approveLeave(String leaveId, String remarks) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/leaves/approve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'leave_id': leaveId,
          'remarks': remarks,
        }),
      );
      if (response.statusCode == 200) {
        _pendingApprovals.removeWhere((l) => l.id == leaveId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectLeave(String leaveId, String remarks) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/leaves/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'leave_id': leaveId,
          'remarks': remarks,
        }),
      );
      if (response.statusCode == 200) {
        _pendingApprovals.removeWhere((l) => l.id == leaveId);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  List<dynamic> _teamCalendar = [];
  List<dynamic> get teamCalendar => _teamCalendar;

  Future<void> fetchTeamCalendar() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/leaves/team-calendar'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _teamCalendar = jsonDecode(response.body);
        notifyListeners();
      }
    } catch (_) {}
  }
}
