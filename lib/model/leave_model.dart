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
  final String status;
  final double? absenceHours;
  final String? used;
  final String? reason;
  final String? remarks;
  final DateTime? appliedOn;

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
    required this.status,
    this.absenceHours,
    this.used,
    this.reason,
    this.remarks,
    this.appliedOn,
  });

  factory LeaveModel.fromJson(Map<String, dynamic> json) {
    return LeaveModel(
      id: json['id'] ?? '',
      employeeId: json['employeeId'] ?? '',
      leaveType: json['leaveType'] ?? '',
      startDate: DateTime.parse(json['startDate']),
      startTime: json['startTime'] ?? '00:00:00',
      endDate: DateTime.parse(json['endDate']),
      endTime: json['endTime'] ?? '00:00:00',
      duration: json['duration'] ?? 'Full-Day',
      processor: json['processor'],
      status: json['status'] ?? 'Pending',
      absenceHours: json['absenceHours']?.toDouble(),
      used: json['used'],
      reason: json['reason'],
      remarks: json['remarks'],
      appliedOn: json['appliedOn'] != null ? DateTime.parse(json['appliedOn']) : null,
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
      'status': status,
      'absenceHours': absenceHours,
      'used': used,
      'reason': reason,
      'remarks': remarks,
      'appliedOn': appliedOn?.toIso8601String(),
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
      timeAccount: json['timeAccount'] ?? '',
      deductionFrom: DateTime.parse(json['deductionFrom']),
      deductionTo: DateTime.parse(json['deductionTo']),
      entitlement: json['entitlement']?.toDouble() ?? 0.0,
      entitlementMinusPlanned: json['entitlementMinusPlanned']?.toDouble() ?? 0.0,
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
