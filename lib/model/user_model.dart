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
  final String? mobileNumber;
  final String? address;
  final String? emergencyContact;
  final String? profileImageUrl;
  final String token;
  final List<String> permissions;

  const UserModel({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.department,
    required this.designation,
    required this.role,
    this.reportingOfficer,
    this.mobileNumber,
    this.address,
    this.emergencyContact,
    this.profileImageUrl,
    required this.token,
    this.permissions = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      employeeId: json['employeeId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      department: json['department'] ?? '',
      designation: json['designation'] ?? '',
      role: json['role'] ?? 'Employee',
      reportingOfficer: json['reportingOfficer'],
      mobileNumber: json['mobileNumber'],
      address: json['address'],
      emergencyContact: json['emergencyContact'],
      profileImageUrl: json['profileImageUrl'],
      token: json['token'] ?? '',
      permissions: List<String>.from(json['permissions'] ?? []),
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
      'mobileNumber': mobileNumber,
      'address': address,
      'emergencyContact': emergencyContact,
      'profileImageUrl': profileImageUrl,
      'token': token,
      'permissions': permissions,
    };
  }

  UserModel copyWith({
    String? mobileNumber,
    String? address,
    String? emergencyContact,
    String? profileImageUrl,
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
      mobileNumber: mobileNumber ?? this.mobileNumber,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      token: token,
      permissions: permissions,
    );
  }
}
