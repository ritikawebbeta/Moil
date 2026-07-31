import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Custom HTTP Client wrapper that logs API requests & responses ONLY in debug mode.
class ApiClient {
  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final combinedHeaders = <String, String>{
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
      'Expires': '0',
    };
    if (headers != null) {
      combinedHeaders.addAll(headers);
    }
    _logRequest('GET', url, headers: combinedHeaders);
    try {
      final response = await http.get(url, headers: combinedHeaders);
      _logResponse(url, response);
      return response;
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 500));
      final response = await http.get(url, headers: combinedHeaders);
      _logResponse(url, response);
      return response;
    }
  }

  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    _logRequest('POST', url, headers: headers, body: body);
    try {
      final response = await http.post(url, headers: headers, body: body, encoding: encoding);
      _logResponse(url, response);
      return response;
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 500));
      final response = await http.post(url, headers: headers, body: body, encoding: encoding);
      _logResponse(url, response);
      return response;
    }
  }

  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    _logRequest('PUT', url, headers: headers, body: body);
    try {
      final response = await http.put(url, headers: headers, body: body, encoding: encoding);
      _logResponse(url, response);
      return response;
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 500));
      final response = await http.put(url, headers: headers, body: body, encoding: encoding);
      _logResponse(url, response);
      return response;
    }
  }

  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    _logRequest('DELETE', url, headers: headers, body: body);
    try {
      final response = await http.delete(url, headers: headers, body: body, encoding: encoding);
      _logResponse(url, response);
      return response;
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 500));
      final response = await http.delete(url, headers: headers, body: body, encoding: encoding);
      _logResponse(url, response);
      return response;
    }
  }

  /// Call backend SMS service directly from Frontend
  static Future<bool> sendSms({
    required String action,
    String? mobileNumber,
    String? applicantName,
    String? approverName,
    String? leaveType,
    String? startDate,
    String? endDate,
    int? days,
    int? stage,
    String? script,
    String? dltTemplateId,
  }) async {
    try {
      final url = Uri.parse('https://acubeai.com/test/moil_hr_app/api/send-sms');
      final payload = {
        'action': action,
        if (mobileNumber != null) 'mobileNumber': mobileNumber,
        if (applicantName != null) 'applicantName': applicantName,
        if (approverName != null) 'approverName': approverName,
        if (leaveType != null) 'leaveType': leaveType,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (days != null) 'days': days,
        if (stage != null) 'stage': stage,
        if (script != null) 'script': script,
        if (dltTemplateId != null) 'dltTemplateId': dltTemplateId,
      };

      final response = await post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ApiClient SMS Exception] $e');
      }
      return false;
    }
  }

  static void _logRequest(String method, Uri url, {Map<String, String>? headers, Object? body}) {
    if (kDebugMode) {
      debugPrint('==================== [API REQUEST] ====================');
      debugPrint('🌐 Method: $method');
      debugPrint('🔗 URL: $url');
      if (headers != null && headers.isNotEmpty) {
        debugPrint('📋 Headers: $headers');
      }
      if (body != null) {
        debugPrint('📦 Request Body: $body');
      }
      debugPrint('======================================================');
    }
  }

  static void _logResponse(Uri url, http.Response response) {
    if (kDebugMode) {
      debugPrint('==================== [API RESPONSE] ====================');
      debugPrint('🔗 URL: $url');
      debugPrint('📊 Status Code: ${response.statusCode}');
      debugPrint('📄 Response Body: ${response.body}');
      debugPrint('=======================================================');
    }
  }
}
