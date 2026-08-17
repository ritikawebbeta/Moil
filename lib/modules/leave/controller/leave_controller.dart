// lib/modules/leave/controller/leave_controller.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../model/leave_model.dart';
import '../../../utils/app_config.dart';
import '../../../utils/api_client.dart';

enum LeaveStatus { initial, loading, loaded, error }

class LeaveController extends ChangeNotifier {
  LeaveStatus _status = LeaveStatus.initial;
  List<LeaveModel> _leaves = [];
  List<LeaveBalanceModel> _balances = [];
  List<LeaveModel> _pendingApprovals = [];
  String? _errorMessage;

  DateTime _showFrom = DateTime(2026, 1, 1);
  String _selectedTimeAccount = 'All Types';
  DateTime _timeAccountShowFrom = DateTime(2021, 1, 1);
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

  Future<void> fetchLeaves(String employeeId, {DateTime? showFromDate}) async {
    if (showFromDate != null) {
      _showFrom = showFromDate;
    }
    _status = LeaveStatus.loading;
    notifyListeners();

    // Fetch time account quota balances automatically on page load
    fetchBalances(employeeId);

    try {
      final token = await _getToken();
      final formattedShowFrom = DateFormat('yyyy-MM-dd').format(_showFrom);
      final response = await ApiClient.get(
        Uri.parse('${AppConfig.baseUrl}/api/leaves?employee_id=$employeeId&show_from=$formattedShowFrom'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          _leaves = decoded.whereType<Map<String, dynamic>>().map((item) => LeaveModel.fromJson(item)).toList();
          _status = LeaveStatus.loaded;
        } else {
          _status = LeaveStatus.error;
        }
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
      final response = await ApiClient.get(
        Uri.parse('${AppConfig.baseUrl}/api/leave-balances?employee_id=$employeeId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          _balances = decoded.whereType<Map<String, dynamic>>().map((item) => LeaveBalanceModel.fromJson(item)).toList();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  String? _lastError;
  String? get lastError => _lastError;

  Future<bool> applyLeave(LeaveApplicationRequest request) async {
    _lastError = null;
    try {
      final token = await _getToken();
      final response = await ApiClient.post(
        Uri.parse('${AppConfig.baseUrl}/api/leaves'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchLeaves(request.employeeId);
        return true;
      }

      try {
        final decoded = jsonDecode(response.body);
        _lastError = decoded['error']?.toString() ?? decoded['message']?.toString() ?? 'Server Status: ${response.statusCode}';
      } catch (_) {
        _lastError = 'Server Status: ${response.statusCode}';
      }
      return false;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  Future<void> fetchPendingApprovals() async {
    _status = LeaveStatus.loading;
    notifyListeners();

    try {
      final token = await _getToken();
      final response = await ApiClient.get(
        Uri.parse('${AppConfig.baseUrl}/api/leaves/pending-approvals'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          _pendingApprovals = decoded.whereType<Map<String, dynamic>>().map((item) => LeaveModel.fromJson(item)).toList();
          _status = LeaveStatus.loaded;
        } else {
          _status = LeaveStatus.error;
        }
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
      final response = await ApiClient.post(
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
        _pendingApprovals.removeWhere((l) => l.id == leaveId || l.id.toString() == leaveId.toString());
        notifyListeners();
        fetchPendingApprovals();
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
      final response = await ApiClient.post(
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
        _pendingApprovals.removeWhere((l) => l.id == leaveId || l.id.toString() == leaveId.toString());
        notifyListeners();
        fetchPendingApprovals();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> withdrawLeave(String leaveId, String employeeId) async {
    try {
      final token = await _getToken();
      final response = await ApiClient.post(
        Uri.parse('${AppConfig.baseUrl}/api/leaves/withdraw'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'leave_id': leaveId,
        }),
      );
      if (response.statusCode == 200) {
        await fetchLeaves(employeeId);
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
      final response = await ApiClient.get(
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
