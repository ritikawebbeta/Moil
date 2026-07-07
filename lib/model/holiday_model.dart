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
}
