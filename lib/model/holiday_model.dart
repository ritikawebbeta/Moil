// lib/model/holiday_model.dart

class HolidayModel {
  final String id;
  final String name;
  final DateTime date;
  final String type;
  final String? department;
  final bool isNational;

  const HolidayModel({
    required this.id,
    required this.name,
    required this.date,
    required this.type,
    this.department,
    this.isNational = false,
  });

  factory HolidayModel.fromJson(Map<String, dynamic> json) {
    return HolidayModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      type: json['type'] ?? 'Optional',
      department: json['department'],
      isNational: json['isNational'] ?? false,
    );
  }
}
