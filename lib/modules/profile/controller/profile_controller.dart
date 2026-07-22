// lib/modules/profile/controller/profile_controller.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../model/employee_model.dart';
import '../../../utils/app_config.dart';

class ProfileController extends ChangeNotifier {
  bool _isLoading = false;
  EmployeeModel? _employee;
  List<EmployeeModel> _employees = [];

  static List<Map<String, dynamic>> rawEmployees = [];

  bool get isLoading => _isLoading;
  EmployeeModel? get employee => _employee;
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

  Future<void> fetchEmployeeProfile(String employeeId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/profile?employee_id=$employeeId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        _employee = EmployeeModel.fromJson(data);
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchAllEmployees() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/employees'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _employees = data.map((e) => EmployeeModel.fromJson(e)).toList();
        rawEmployees = _employees.map((e) => e.toRawMap()).toList();
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateProfile({
    String? mobileNumber,
    String? address,
    String? emergencyContact,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
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
