// lib/modules/leave/controller/leave_controller.dart

import 'package:flutter/material.dart';
import '../../../model/leave_model.dart';

enum LeaveStatus { initial, loading, loaded, error }

class LeaveController extends ChangeNotifier {
  LeaveStatus _status = LeaveStatus.initial;
  List<LeaveModel> _leaves = [];
  List<LeaveBalanceModel> _balances = [];
  String? _errorMessage;

  DateTime _showFrom = DateTime(2026, 2, 1);
  String _selectedTimeAccount = 'All Types';
  DateTime _timeAccountShowFrom = DateTime(2026, 1, 1);
  int _activeTabIndex = 0;

  LeaveStatus get status => _status;
  List<LeaveModel> get leaves => _leaves;
  List<LeaveBalanceModel> get balances => _balances;
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

  Future<void> fetchLeaves(String employeeId) async {
    _status = LeaveStatus.loading;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1));

      _leaves = [
        LeaveModel(
          id: '1',
          employeeId: employeeId,
          leaveType: 'Official Tour',
          startDate: DateTime(2026, 5, 11),
          startTime: '06:00:00',
          endDate: DateTime(2026, 5, 11),
          endTime: '23:30:00',
          duration: 'Full-Day',
          status: 'Approved',
          absenceHours: 17.50,
        ),
        LeaveModel(
          id: '2',
          employeeId: employeeId,
          leaveType: 'Official Tour',
          startDate: DateTime(2026, 7, 5),
          startTime: '00:00:00',
          endDate: DateTime(2026, 10, 5),
          endTime: '00:00:00',
          duration: 'Full-Day',
          status: 'Approved',
          absenceHours: 17.00,
        ),
        LeaveModel(
          id: '3',
          employeeId: employeeId,
          leaveType: 'Official Tour',
          startDate: DateTime(2026, 4, 1),
          startTime: '00:00:00',
          endDate: DateTime(2026, 4, 4),
          endTime: '00:00:00',
          duration: 'Full-Day',
          status: 'Approved',
          absenceHours: 34.00,
        ),
        LeaveModel(
          id: '4',
          employeeId: employeeId,
          leaveType: 'Casual Leave',
          startDate: DateTime(2026, 3, 26),
          startTime: '10:00:00',
          endDate: DateTime(2026, 3, 26),
          endTime: '14:15:00',
          duration: 'Half-Day',
          status: 'Approved',
          absenceHours: 4.25,
          used: '0.50 Days',
        ),
        LeaveModel(
          id: '5',
          employeeId: employeeId,
          leaveType: 'Casual Leave',
          startDate: DateTime(2026, 3, 2),
          startTime: '00:00:00',
          endDate: DateTime(2026, 3, 2),
          endTime: '00:00:00',
          duration: 'Full-Day',
          processor: 'Nitin Pagnis',
          status: 'Approved',
          absenceHours: 6.45,
          used: '1 Days',
        ),
      ];

      _status = LeaveStatus.loaded;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to fetch leave data.';
      _status = LeaveStatus.error;
      notifyListeners();
    }
  }

  Future<void> fetchBalances(String employeeId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 800));

      _balances = [
        LeaveBalanceModel(
          timeAccount: 'Earned leave',
          deductionFrom: DateTime(2026, 1, 1),
          deductionTo: DateTime(2026, 12, 31),
          entitlement: 215.50,
          entitlementMinusPlanned: 185.50,
        ),
        LeaveBalanceModel(
          timeAccount: 'Casual Leave',
          deductionFrom: DateTime(2026, 1, 1),
          deductionTo: DateTime(2026, 12, 31),
          entitlement: 12.00,
          entitlementMinusPlanned: 10.50,
        ),
        LeaveBalanceModel(
          timeAccount: 'HPL',
          deductionFrom: DateTime(2026, 1, 1),
          deductionTo: DateTime(2026, 12, 31),
          entitlement: 107.00,
          entitlementMinusPlanned: 107.00,
        ),
        LeaveBalanceModel(
          timeAccount: 'Optional Holiday',
          deductionFrom: DateTime(2026, 1, 1),
          deductionTo: DateTime(2026, 12, 31),
          entitlement: 2.00,
          entitlementMinusPlanned: 2.00,
        ),
      ];

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to fetch leave balance.';
    }
  }

  Future<bool> applyLeave(LeaveApplicationRequest request) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      // Add mock new leave
      _leaves.insert(0, LeaveModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        employeeId: request.employeeId,
        leaveType: request.leaveType,
        startDate: request.startDate,
        startTime: request.beginTime,
        endDate: request.endDate,
        endTime: request.endTime,
        duration: request.duration,
        processor: request.processor,
        status: 'Pending',
        reason: request.note,
        appliedOn: DateTime.now(),
      ));
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> cancelLeave(String leaveId) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      final index = _leaves.indexWhere((l) => l.id == leaveId);
      if (index != -1) {
        notifyListeners();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> approveLeave(String leaveId, String remarks) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> rejectLeave(String leaveId, String remarks) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      return false;
    }
  }
}
