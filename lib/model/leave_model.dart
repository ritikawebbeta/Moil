// lib/model/leave_model.dart

class LeaveModel {
  final String id;
  final String employeeId;
  final String leaveType;
  final DateTime startDate;
  final String startTime;
  final DateTime endDate;
  final String endTime;
  final String duration;
  final String? processor;
  final String? processor1;
  final String status;
  final double? absenceHours;
  final String? used;
  final String? reason;
  final String? remarks;
  final DateTime? appliedOn;
  final DateTime? approvedOn;

  const LeaveModel({
    required this.id,
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.startTime,
    required this.endDate,
    required this.endTime,
    required this.duration,
    this.processor,
    this.processor1,
    required this.status,
    this.absenceHours,
    this.used,
    this.reason,
    this.remarks,
    this.appliedOn,
    this.approvedOn,
  });

  factory LeaveModel.fromJson(Map<String, dynamic> json) {
    DateTime parseSingle(dynamic val) {
      if (val == null || val.toString().trim().isEmpty || val.toString() == 'null') return DateTime(2026, 1, 1);
      final str = val.toString().trim().replaceAll(' ', 'T');
      final parsed = DateTime.tryParse(str);
      if (parsed != null) return parsed;

      final parts = str.split(RegExp(r'[-./]'));
      if (parts.length >= 3) {
        if (parts[0].length <= 2 && parts[2].length == 4) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);
          if (day != null && month != null && year != null) {
            return DateTime(year, month, day);
          }
        }
      }
      return DateTime(2026, 1, 1);
    }

    DateTime parseDate(dynamic val, {dynamic fallbackVal}) {
      final primary = parseSingle(val);
      if (primary.year != 2026 || primary.month != 1 || primary.day != 1) return primary;
      return parseSingle(fallbackVal);
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null || val.toString().trim().isEmpty || val.toString() == 'null') return null;
      final str = val.toString().trim().replaceAll(' ', 'T');
      return DateTime.tryParse(str);
    }

    final startDate = parseDate(json['startDate'], fallbackVal: json['appliedOn']);
    final endDate = parseDate(json['endDate'], fallbackVal: json['startDate'] ?? json['appliedOn']);

    return LeaveModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      leaveType: json['leaveType']?.toString() ?? '',
      startDate: startDate,
      startTime: json['startTime']?.toString() ?? '00:00:00',
      endDate: endDate,
      endTime: json['endTime']?.toString() ?? '00:00:00',
      duration: json['duration']?.toString() ?? 'Full-Day',
      processor: json['processor']?.toString(),
      processor1: json['processor1']?.toString(),
      status: json['status']?.toString() ?? 'Pending',
      absenceHours: (json['absenceHours'] as num?)?.toDouble(),
      used: json['used']?.toString(),
      reason: json['reason']?.toString(),
      remarks: json['remarks']?.toString(),
      appliedOn: parseNullableDate(json['appliedOn']),
      approvedOn: parseNullableDate(json['approvedOn']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'leaveType': leaveType,
      'startDate': startDate.toIso8601String(),
      'startTime': startTime,
      'endDate': endDate.toIso8601String(),
      'endTime': endTime,
      'duration': duration,
      'processor': processor,
      'processor1': processor1,
      'status': status,
      'absenceHours': absenceHours,
      'used': used,
      'reason': reason,
      'remarks': remarks,
      'appliedOn': appliedOn?.toIso8601String(),
      'approvedOn': approvedOn?.toIso8601String(),
    };
  }
}

class LeaveBalanceModel {
  final String timeAccount;
  final DateTime deductionFrom;
  final DateTime deductionTo;
  final double entitlement;
  final double taken;
  final double entitlementMinusPlanned;

  const LeaveBalanceModel({
    required this.timeAccount,
    required this.deductionFrom,
    required this.deductionTo,
    required this.entitlement,
    required this.taken,
    required this.entitlementMinusPlanned,
  });

  factory LeaveBalanceModel.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceModel(
      timeAccount: json['timeAccount']?.toString() ?? '',
      deductionFrom: DateTime.tryParse(json['deductionFrom']?.toString() ?? '') ?? DateTime(2026, 1, 1),
      deductionTo: DateTime.tryParse(json['deductionTo']?.toString() ?? '') ?? DateTime(2026, 12, 31),
      entitlement: (json['entitlement'] as num?)?.toDouble() ?? 0.0,
      taken: (json['taken'] as num?)?.toDouble() ?? 0.0,
      entitlementMinusPlanned: (json['entitlementMinusPlanned'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class LeaveApplicationRequest {
  final String employeeId;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String beginTime;
  final String endTime;
  final String duration;
  final String processor;
  final String? note;

  const LeaveApplicationRequest({
    required this.employeeId,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.beginTime,
    required this.endTime,
    required this.duration,
    required this.processor,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'leaveType': leaveType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'beginTime': beginTime,
      'endTime': endTime,
      'duration': duration,
      'processor': processor,
      'note': note,
    };
  }
}
