// lib/model/user_model.dart

class UserModel {
  final String id;
  final String employeeId;
  final String name;
  final String email;
  final String department;
  final String designation;
  final String role;
  final String? reportingOfficer;
  final String? reportingOfficerName;
  final String? reportingOfficer1;
  final String? reportingOfficer1Name;
  final String? mobileNumber;
  final String? address;
  final String? emergencyContact;
  final String? profileImageUrl;
  final String token;
  final List<String> permissions;
  final bool mustChangePassword;

  const UserModel({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.department,
    required this.designation,
    required this.role,
    this.reportingOfficer,
    this.reportingOfficerName,
    this.reportingOfficer1,
    this.reportingOfficer1Name,
    this.mobileNumber,
    this.address,
    this.emergencyContact,
    this.profileImageUrl,
    required this.token,
    this.permissions = const [],
    this.mustChangePassword = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      designation: json['designation']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Employee',
      reportingOfficer: json['reportingOfficer']?.toString(),
      reportingOfficerName: json['reportingOfficerName']?.toString(),
      reportingOfficer1: json['reportingOfficer1']?.toString(),
      reportingOfficer1Name: json['reportingOfficer1Name']?.toString(),
      mobileNumber: json['mobileNumber']?.toString(),
      address: json['address']?.toString(),
      emergencyContact: json['emergencyContact']?.toString(),
      profileImageUrl: json['profileImageUrl']?.toString(),
      token: json['token']?.toString() ?? '',
      permissions: List<String>.from(json['permissions'] ?? []),
      mustChangePassword: json['mustChangePassword'] ?? json['must_change_password'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'name': name,
      'email': email,
      'department': department,
      'designation': designation,
      'role': role,
      'reportingOfficer': reportingOfficer,
      'reportingOfficerName': reportingOfficerName,
      'reportingOfficer1': reportingOfficer1,
      'reportingOfficer1Name': reportingOfficer1Name,
      'mobileNumber': mobileNumber,
      'address': address,
      'emergencyContact': emergencyContact,
      'profileImageUrl': profileImageUrl,
      'token': token,
      'permissions': permissions,
      'mustChangePassword': mustChangePassword,
    };
  }

  UserModel copyWith({
    String? mobileNumber,
    String? address,
    String? emergencyContact,
    String? profileImageUrl,
    bool? mustChangePassword,
  }) {
    return UserModel(
      id: id,
      employeeId: employeeId,
      name: name,
      email: email,
      department: department,
      designation: designation,
      role: role,
      reportingOfficer: reportingOfficer,
      reportingOfficerName: reportingOfficerName,
      reportingOfficer1: reportingOfficer1,
      reportingOfficer1Name: reportingOfficer1Name,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      token: token,
      permissions: permissions,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }
}
