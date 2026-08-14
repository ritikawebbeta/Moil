// lib/modules/profile/controller/profile_controller.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../model/employee_model.dart';
import '../../../utils/app_config.dart';
import '../../../utils/api_client.dart';

class ProfileController extends ChangeNotifier {
  bool _isLoading = false;
  EmployeeModel? _employee;
  EmployeeModel? _selectedEmployee;
  List<EmployeeModel> _employees = [];

  static List<Map<String, dynamic>> rawEmployees = [];

  bool get isLoading => _isLoading;
  EmployeeModel? get employee => _employee;
  EmployeeModel? get selectedEmployee => _selectedEmployee;
  List<EmployeeModel> get employees => _employees;

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

  Future<String?> _getMyEmployeeId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJsonStr = prefs.getString('auth_user');
      if (userJsonStr != null) {
        final userMap = jsonDecode(userJsonStr);
        return userMap['employeeId']?.toString() ?? userMap['employee_number']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<void> fetchEmployeeProfile(String employeeId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();
      final response = await ApiClient.get(
        Uri.parse('${AppConfig.baseUrl}/api/profile?employee_id=$employeeId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final model = EmployeeModel.fromJson(decoded);
          _selectedEmployee = model;

          final myId = await _getMyEmployeeId();
          final cleanMyId = myId != null ? myId.trim().replaceAll(RegExp('^0+'), '') : '';
          final cleanParamId = employeeId.trim().replaceAll(RegExp('^0+'), '');

          if (cleanMyId.isEmpty || cleanMyId == cleanParamId) {
            _employee = model;
          }
        }
      }
    } catch (e) {
      debugPrint('fetchEmployeeProfile error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAllEmployees() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();
      final response = await ApiClient.get(
        Uri.parse('${AppConfig.baseUrl}/api/employees'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          final seen = <String>{};
          final uniqueList = <EmployeeModel>[];
          for (var item in decoded) {
            if (item is Map<String, dynamic>) {
              try {
                final model = EmployeeModel.fromJson(item);
                final cleanId = model.employeeId.trim().replaceAll(RegExp('^0+'), '');
                if (cleanId.isNotEmpty && seen.add(cleanId)) {
                  uniqueList.add(model);
                }
              } catch (e) {
                debugPrint('Error parsing employee model item: $e');
              }
            }
          }
          _employees = uniqueList;
          rawEmployees = _employees.map((e) => e.toRawMap()).toList();
        } else {
          _employees = [];
          rawEmployees = [];
        }
      } else {
        _employees = [];
        rawEmployees = [];
      }
    } catch (e) {
      debugPrint('fetchAllEmployees error: $e');
      _employees = [];
      rawEmployees = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  void clear() {
    _employee = null;
    _employees = [];
    rawEmployees = [];
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? mobileNumber,
    String? address,
    String? emergencyContact,
  }) async {
    try {
      final token = await _getToken();
      final response = await ApiClient.post(
        Uri.parse('${AppConfig.baseUrl}/api/profile/update'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'mobile': mobileNumber ?? '',
          'email': _employee?.email ?? '',
        }),
      );
      if (response.statusCode == 200 && _employee != null) {
        _employee = _employee!.copyWith(
          mobileNumber: mobileNumber ?? _employee!.mobileNumber,
          address: address ?? _employee!.address,
          emergencyContact: emergencyContact ?? _employee!.emergencyContact,
        );
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
