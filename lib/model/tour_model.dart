// lib/model/tour_model.dart

class TourModel {
  final String id;
  final String employeeId;
  final String tourType;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final String travelPurpose;
  final String transportMode;
  final String? processor;
  final String status;
  final String? remarks;
  final DateTime? appliedOn;
  final DateTime? approvedOn;

  // New columns from SAP travel request
  final String countryRegion;
  final String activity;
  final double advances;
  final String costAssignment;
  final bool airways;
  final bool selfScooter;
  final bool bus;
  final bool selfCar;
  final bool railways;
  final bool privateCar;

  const TourModel({
    required this.id,
    required this.employeeId,
    required this.tourType,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.travelPurpose,
    required this.transportMode,
    this.processor,
    required this.status,
    this.remarks,
    this.appliedOn,
    this.approvedOn,
    this.countryRegion = 'India',
    this.activity = 'Official Tour',
    this.advances = 0.0,
    this.costAssignment = '100.00 % Cost Center 100511 (100511), Company Code 1000 (MOIL LIMITED)',
    this.airways = true,
    this.selfScooter = false,
    this.bus = false,
    this.selfCar = false,
    this.railways = false,
    this.privateCar = false,
  });

  factory TourModel.fromJson(Map<String, dynamic> json) {
    return TourModel(
      id: json['id'] ?? '',
      employeeId: json['employeeId'] ?? '',
      tourType: json['tourType'] ?? '',
      destination: json['destination'] ?? '',
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      travelPurpose: json['travelPurpose'] ?? '',
      transportMode: json['transportMode'] ?? '',
      processor: json['processor'],
      status: json['status'] ?? 'Pending',
      remarks: json['remarks'],
      appliedOn: json['appliedOn'] != null ? DateTime.parse(json['appliedOn']) : null,
      approvedOn: json['approvedOn'] != null ? DateTime.parse(json['approvedOn']) : null,
      countryRegion: json['countryRegion'] ?? 'India',
      activity: json['activity'] ?? 'Official Tour',
      advances: (json['advances'] as num?)?.toDouble() ?? 0.0,
      costAssignment: json['costAssignment'] ?? '100.00 % Cost Center 100511 (100511), Company Code 1000 (MOIL LIMITED)',
      airways: json['airways'] ?? true,
      selfScooter: json['selfScooter'] ?? false,
      bus: json['bus'] ?? false,
      selfCar: json['selfCar'] ?? false,
      railways: json['railways'] ?? false,
      privateCar: json['privateCar'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'tourType': tourType,
      'destination': destination,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'travelPurpose': travelPurpose,
      'transportMode': transportMode,
      'processor': processor,
      'status': status,
      'remarks': remarks,
      'appliedOn': appliedOn?.toIso8601String(),
      'approvedOn': approvedOn?.toIso8601String(),
      'countryRegion': countryRegion,
      'activity': activity,
      'advances': advances,
      'costAssignment': costAssignment,
      'airways': airways,
      'selfScooter': selfScooter,
      'bus': bus,
      'selfCar': selfCar,
      'railways': railways,
      'privateCar': privateCar,
    };
  }

  TourModel copyWith({
    String? id,
    String? employeeId,
    String? tourType,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String? travelPurpose,
    String? transportMode,
    String? processor,
    String? status,
    String? remarks,
    DateTime? appliedOn,
    DateTime? approvedOn,
    String? countryRegion,
    String? activity,
    double? advances,
    String? costAssignment,
    bool? airways,
    bool? selfScooter,
    bool? bus,
    bool? selfCar,
    bool? railways,
    bool? privateCar,
  }) {
    return TourModel(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      tourType: tourType ?? this.tourType,
      destination: destination ?? this.destination,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      travelPurpose: travelPurpose ?? this.travelPurpose,
      transportMode: transportMode ?? this.transportMode,
      processor: processor ?? this.processor,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      appliedOn: appliedOn ?? this.appliedOn,
      approvedOn: approvedOn ?? this.approvedOn,
      countryRegion: countryRegion ?? this.countryRegion,
      activity: activity ?? this.activity,
      advances: advances ?? this.advances,
      costAssignment: costAssignment ?? this.costAssignment,
      airways: airways ?? this.airways,
      selfScooter: selfScooter ?? this.selfScooter,
      bus: bus ?? this.bus,
      selfCar: selfCar ?? this.selfCar,
      railways: railways ?? this.railways,
      privateCar: privateCar ?? this.privateCar,
    );
  }
}
