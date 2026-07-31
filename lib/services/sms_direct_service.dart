import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Direct MyVI Gateway SMS Service called entirely from Frontend
class SmsDirectService {
  static const String authUrl = 'https://cts.myvi.in:8443/ManageSms/api/AuthJwt/Authenticate';
  static const String sendSmsUrl = 'https://cts.myvi.in:8443/ManageSms/api/sms/Createsms/json/apikey=ng6q1u';

  static const String authUsername = 'managesms';
  static const String authPassword = 'f9e5f1dbcbd155c505be2b925b32ac9237a3e8d';

  static const String defaultMobile = '9689941705';
  static const String senderId = 'MOILHO';

  static String? _cachedToken;
  static DateTime? _tokenExpiry;

  /// Obtain JWT Auth Token directly from MyVI Auth API
  static Future<String?> getAuthToken() async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }

    try {
      final response = await http.post(
        Uri.parse(authUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': authUsername,
          'password': authPassword,
        }),
      );

      if (response.statusCode == 200) {
        final token = response.body.trim().replaceAll('"', '');
        if (token.isNotEmpty) {
          _cachedToken = token;
          _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
          if (kDebugMode) {
            debugPrint('[SMS Direct Auth] JWT Token obtained successfully.');
          }
          return token;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SMS Direct Auth Error] $e');
      }
    }
    return null;
  }

  /// Core Direct SMS dispatch to MyVI API
  static Future<bool> sendSms({
    required String script,
    required String dltTemplateId,
    String? mobileNumber,
  }) async {
    try {
      final phone = (mobileNumber != null && mobileNumber.trim().isNotEmpty)
          ? mobileNumber.replaceAll(RegExp(r'[^\d]'), '')
          : defaultMobile;

      final targetPhone = (phone.length >= 10) ? phone.substring(phone.length - 10) : defaultMobile;
      final token = await getAuthToken();

      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final payload = {
        'msisdn': targetPhone,
        'script': script,
        'unicode': '0',
        'senderid': senderId,
        'pingbackurl': '',
        'DLTTemplateid': dltTemplateId,
      };

      if (kDebugMode) {
        debugPrint('[SMS Direct Request] URL: $sendSmsUrl | Target: $targetPhone | Template: $dltTemplateId');
      }

      final response = await http.post(
        Uri.parse(sendSmsUrl),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (kDebugMode) {
        debugPrint('[SMS Direct Response] Code: ${response.statusCode} | Body: ${response.body}');
      }

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SMS Direct Error] $e');
      }
      return false;
    }
  }

  // Format Helper: Name with Salutation (e.g. Mr. Raja Talathoti)
  static String formatName(String? name) {
    if (name == null || name.trim().isEmpty) return 'Mr. Employee';
    final trimmed = name.trim();
    if (RegExp(r'^(Mr|Ms|Mrs|Dr)\b', caseSensitive: false).hasMatch(trimmed)) {
      return trimmed;
    }
    return 'Mr. $trimmed';
  }

  // Format Helper: Date as DD.MM.YYYY
  static String formatDate(dynamic dateInput) {
    if (dateInput == null) return '01.01.2026';
    final str = dateInput.toString().trim();
    if (RegExp(r'^\d{2}\.\d{2}\.\d{4}$').hasMatch(str)) return str;
    if (RegExp(r'^\d{4}[-/]\d{2}[-/]\d{2}').hasMatch(str)) {
      final parts = str.split('T')[0].split(' ')[0].split(RegExp(r'[-/]'));
      return '${parts[2]}.${parts[1]}.${parts[0]}';
    }
    if (RegExp(r'^\d{2}[-/]\d{2}[-/]\d{4}').hasMatch(str)) {
      final parts = str.split('T')[0].split(' ')[0].split(RegExp(r'[-/]'));
      return '${parts[0]}.${parts[1]}.${parts[2]}';
    }
    final d = DateTime.tryParse(str);
    if (d == null) return str;
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day.$month.${d.year}';
  }

  // Format Helper: 5-digit zero padded days (00030)
  static String formatDays(dynamic days) {
    final num = int.tryParse(days.toString()) ?? 0;
    return num.toString().padLeft(5, '0');
  }

  // 1. Leave Applied SMS
  static Future<bool> sendLeaveAppliedSms({
    required String applicantName,
    required String leaveType,
    required String startDate,
    required String endDate,
    String? mobileNumber,
  }) async {
    final name = formatName(applicantName);
    final sDate = formatDate(startDate);
    final eDate = formatDate(endDate);
    final script = '$name has applied for $leaveType from $sDate to $eDate through ESS. Kindly take necessary action in this regard. MOIL Limited';
    const dltTemplateId = '1107163177301320100';

    return await sendSms(script: script, dltTemplateId: dltTemplateId, mobileNumber: mobileNumber);
  }

  // 2. Leave Approved SMS
  static Future<bool> sendLeaveApprovedSms({
    required String approverName,
    required String leaveType,
    required String startDate,
    required String endDate,
    String? mobileNumber,
  }) async {
    final name = formatName(approverName);
    final sDate = formatDate(startDate);
    final eDate = formatDate(endDate);
    final script = '$name has approved your application of $leaveType from $sDate to $eDate through ESS. This is for your information. MOIL Limited';
    const dltTemplateId = '1107163177311020000';

    return await sendSms(script: script, dltTemplateId: dltTemplateId, mobileNumber: mobileNumber);
  }

  // 3. Leave Rejected SMS
  static Future<bool> sendLeaveRejectedSms({
    required String approverName,
    required String leaveType,
    required String startDate,
    required String endDate,
    int stage = 1,
    String? mobileNumber,
  }) async {
    final name = formatName(approverName);
    final sDate = formatDate(startDate);
    final eDate = formatDate(endDate);
    final rejectWord = (stage == 2) ? 'rejected2' : 'rejected1';
    final script = '$name has $rejectWord your application of $leaveType from $sDate to $eDate through ESS. This is for your information. MOIL Limited';
    const dltTemplateId = '1107163177318770000';

    return await sendSms(script: script, dltTemplateId: dltTemplateId, mobileNumber: mobileNumber);
  }

  // 4. Leave Encashment Applied SMS
  static Future<bool> sendLeaveEncashAppliedSms({
    required String applicantName,
    required dynamic days,
    String? mobileNumber,
  }) async {
    final name = formatName(applicantName);
    final paddedDays = formatDays(days);
    final script = '$name has applied for $paddedDays days encashment of leave through ESS. This is for your needful. MOIL Limited';
    const dltTemplateId = '1107165901001500000';

    return await sendSms(script: script, dltTemplateId: dltTemplateId, mobileNumber: mobileNumber);
  }

  // 5. Leave Encashment Approved SMS
  static Future<bool> sendLeaveEncashApprovedSms({
    required String applicantName,
    required String approverName,
    required dynamic days,
    String? mobileNumber,
  }) async {
    final appName = formatName(applicantName);
    final apprName = formatName(approverName);
    final paddedDays = formatDays(days);
    final script = '$appName encashment request for $paddedDays days has been approved by $apprName. Kindly process. MOIL Limited';
    const dltTemplateId = '1107165717011040000';

    return await sendSms(script: script, dltTemplateId: dltTemplateId, mobileNumber: mobileNumber);
  }

  // 6. Leave Encashment Rejected SMS
  static Future<bool> sendLeaveEncashRejectedSms({
    required String applicantName,
    required String approverName,
    required dynamic days,
    String? mobileNumber,
  }) async {
    final appName = formatName(applicantName);
    final apprName = formatName(approverName);
    final paddedDays = formatDays(days);
    final script = '$appName encashment request for $paddedDays days has been rejected by $apprName. Kindly process. MOIL Limited';
    const dltTemplateId = '1107165717016330000';

    return await sendSms(script: script, dltTemplateId: dltTemplateId, mobileNumber: mobileNumber);
  }
}
