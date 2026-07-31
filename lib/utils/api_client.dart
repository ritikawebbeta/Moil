import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/sms_direct_service.dart';

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

  /// Call MyVI SMS Gateway API directly from Frontend (without backend endpoint)
  static Future<bool> sendSms({
    required String action,
    String? mobileNumber,
    String? applicantName,
    String? approverName,
    String? leaveType,
    String? startDate,
    String? endDate,
    int? days,
    int stage = 1,
    String? script,
    String? dltTemplateId,
  }) async {
    switch (action) {
      case 'leave_applied':
      case 'applied':
        return await SmsDirectService.sendLeaveAppliedSms(
          applicantName: applicantName ?? 'Mr. Employee',
          leaveType: leaveType ?? 'LEAVE',
          startDate: startDate ?? '',
          endDate: endDate ?? '',
          mobileNumber: mobileNumber,
        );

      case 'leave_approved':
      case 'approved':
        return await SmsDirectService.sendLeaveApprovedSms(
          approverName: approverName ?? 'Officer',
          leaveType: leaveType ?? 'LEAVE',
          startDate: startDate ?? '',
          endDate: endDate ?? '',
          mobileNumber: mobileNumber,
        );

      case 'leave_rejected':
      case 'rejected':
        return await SmsDirectService.sendLeaveRejectedSms(
          approverName: approverName ?? 'Officer',
          leaveType: leaveType ?? 'LEAVE',
          startDate: startDate ?? '',
          endDate: endDate ?? '',
          stage: stage,
          mobileNumber: mobileNumber,
        );

      case 'encash_applied':
        return await SmsDirectService.sendLeaveEncashAppliedSms(
          applicantName: applicantName ?? 'Mr. Employee',
          days: days ?? 0,
          mobileNumber: mobileNumber,
        );

      case 'encash_approved':
        return await SmsDirectService.sendLeaveEncashApprovedSms(
          applicantName: applicantName ?? 'Mr. Employee',
          approverName: approverName ?? 'Officer',
          days: days ?? 0,
          mobileNumber: mobileNumber,
        );

      case 'encash_rejected':
        return await SmsDirectService.sendLeaveEncashRejectedSms(
          applicantName: applicantName ?? 'Mr. Employee',
          approverName: approverName ?? 'Officer',
          days: days ?? 0,
          mobileNumber: mobileNumber,
        );

      default:
        if (script != null && dltTemplateId != null) {
          return await SmsDirectService.sendSms(
            script: script,
            dltTemplateId: dltTemplateId,
            mobileNumber: mobileNumber,
          );
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
