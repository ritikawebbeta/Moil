// lib/modules/auth/controller/auth_controller.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../model/user_model.dart';
import '../../../utils/app_config.dart';
import '../../profile/controller/profile_controller.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthController extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;

  AuthController() {
    _loadUser();
  }

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJsonStr = prefs.getString('auth_user');
      if (userJsonStr != null) {
        final Map<String, dynamic> userMap = jsonDecode(userJsonStr);
        _user = UserModel.fromJson(userMap);
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String employeeId, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();


    try {
      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'employee_number': employeeId.trim(),
          'password': password.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final Map<String, dynamic> emp = data['employee'];

        _user = UserModel(
          id: emp['employee_number']?.toString() ?? '',
          employeeId: emp['employee_number']?.toString() ?? '',
          name: emp['name']?.toString() ?? '',
          email: emp['email']?.toString() ?? '',
          department: emp['department']?.toString() ?? '',
          designation: emp['position']?.toString() ?? '',
          role: emp['group']?.toString() ?? 'Employee',
          reportingOfficer: emp['reporting_officer']?.toString(),
          reportingOfficerName: emp['reporting_officer_name']?.toString(),
          reportingOfficer1: emp['reporting_officer_1']?.toString(),
          reportingOfficer1Name: emp['reporting_officer_1_name']?.toString(),
          mobileNumber: emp['mobile']?.toString(),
          address: '',
          emergencyContact: '',
          token: data['token']?.toString() ?? '',
          permissions: const ['leave.view', 'leave.apply', 'tour.view', 'tour.apply', 'payslip.view', 'holiday.view'],
          mustChangePassword: data['must_change_password'] ?? emp['must_change_password'] ?? false,
        );

        _status = AuthStatus.authenticated;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_user', jsonEncode(_user!.toJson()));
        
        notifyListeners();
        return true;
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        _errorMessage = errorData['error'] ?? 'Invalid Employee Number or Password';
        _status = AuthStatus.error;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Connection failed. Please check your internet or server.';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _status = AuthStatus.unauthenticated;
    _user = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_user');
    } catch (_) {}
    notifyListeners();
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJsonStr = prefs.getString('auth_user');
      if (userJsonStr == null) return false;
      final userMap = jsonDecode(userJsonStr);
      final token = userMap['token'];

      final response = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'new_password': newPassword,
        }),
      );

      final success = response.statusCode == 200;
      if (success && _user != null) {
        _user = _user!.copyWith(mustChangePassword: false);
        await prefs.setString('auth_user', jsonEncode(_user!.toJson()));
        notifyListeners();
      }
      return success;
    } catch (e) {
      return false;
    }
  }
}
