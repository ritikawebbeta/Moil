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
    return LeaveModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      leaveType: json['leaveType']?.toString() ?? '',
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? '') ?? DateTime.now(),
      startTime: json['startTime']?.toString() ?? '00:00:00',
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? '') ?? DateTime.now(),
      endTime: json['endTime']?.toString() ?? '00:00:00',
      duration: json['duration']?.toString() ?? 'Full-Day',
      processor: json['processor']?.toString(),
      processor1: json['processor1']?.toString(),
      status: json['status']?.toString() ?? 'Pending',
      absenceHours: (json['absenceHours'] as num?)?.toDouble(),
      used: json['used']?.toString(),
      reason: json['reason']?.toString(),
      remarks: json['remarks']?.toString(),
      appliedOn: json['appliedOn'] != null ? DateTime.tryParse(json['appliedOn'].toString()) : null,
      approvedOn: json['approvedOn'] != null ? DateTime.tryParse(json['approvedOn'].toString()) : null,
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
  final double entitlementMinusPlanned;

  const LeaveBalanceModel({
    required this.timeAccount,
    required this.deductionFrom,
    required this.deductionTo,
    required this.entitlement,
    required this.entitlementMinusPlanned,
  });

  factory LeaveBalanceModel.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceModel(
      timeAccount: json['timeAccount']?.toString() ?? '',
      deductionFrom: DateTime.tryParse(json['deductionFrom']?.toString() ?? '') ?? DateTime(2026, 1, 1),
      deductionTo: DateTime.tryParse(json['deductionTo']?.toString() ?? '') ?? DateTime(2026, 12, 31),
      entitlement: (json['entitlement'] as num?)?.toDouble() ?? 0.0,
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
