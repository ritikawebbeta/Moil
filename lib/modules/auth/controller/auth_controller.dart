// lib/modules/auth/controller/auth_controller.dart

import 'package:flutter/material.dart';
import '../../../model/user_model.dart';

import '../../profile/controller/profile_controller.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthController extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<bool> login(String employeeId, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 1));

      final employeeIdTrimmed = employeeId.trim();
      final passwordTrimmed = password.trim();

      if (employeeIdTrimmed.isEmpty || passwordTrimmed.isEmpty) {
        _errorMessage = 'Employee number and PAN card password cannot be empty.';
        _status = AuthStatus.error;
        notifyListeners();
        return false;
      }

      // Strict index check in raw employee list
      final matchIndex = ProfileController.rawEmployees.indexWhere(
        (e) => e['empNo'] == employeeIdTrimmed
      );

      if (matchIndex == -1) {
        _errorMessage = 'Employee number not found. Access denied.';
        _status = AuthStatus.error;
        notifyListeners();
        return false;
      }

      final match = ProfileController.rawEmployees[matchIndex];

      // Strict PAN check as password (case-insensitive comparison)
      final correctPan = (match['pan'] ?? '').toString().trim().toLowerCase();
      if (correctPan != passwordTrimmed.toLowerCase()) {
        _errorMessage = 'Incorrect PAN number password. Access denied.';
        _status = AuthStatus.error;
        notifyListeners();
        return false;
      }

      _user = UserModel(
        id: match['empNo'] ?? '283',
        employeeId: match['empNo'] ?? '283',
        name: match['name'] ?? 'Nitin Purushottam Kajarekar',
        email: match['email'] ?? 'ABC@gmail.com',
        department: match['dept'] ?? 'Finance',
        designation: match['position'] ?? 'General Manager-Finance',
        role: match['empRoll'] ?? 'RO',
        reportingOfficer: match['empRoll'] ?? 'RO',
        mobileNumber: match['mobile'] ?? '123456789',
        address: match['permAddress'] ?? 'Bhavan',
        emergencyContact: match['emergAddress'] ?? 'EA Bhavan',
        token: 'mock_jwt_token_12345',
        permissions: ['leave.view', 'leave.apply', 'tour.view', 'tour.apply', 'payslip.view', 'holiday.view'],
      );
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Connection or authentication failed.';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _status = AuthStatus.unauthenticated;
    _user = null;
    notifyListeners();
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      return true;
    } catch (e) {
      return false;
    }
  }
}
