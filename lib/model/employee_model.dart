// lib/model/employee_model.dart

class EmployeeModel {
  final String id;
  final String name;
  final String fatherSpouseName;
  final String designation;
  final String department;
  final String presentGrade;
  final String dateOfBirth;
  final String joinDate;
  final String lastPromotionDate;
  final String appointmentType;
  final String category;
  final String bloodGroup;
  final String gender;
  final String maritalStatus;
  final String employeeId;
  final String basicSalary;
  final String presentPlaceOfPosting;
  final String presentPostingDate;
  final String retirementDate;
  final String mobileNumber;
  final String email;
  final String uanNo;
  final String panNo;
  final String aadhaarNo;
  final String pranNo;
  final String pfNo;
  final String pensionNo;

  // Additional Fields
  final String reportingOfficer;
  final String reportingOfficer1;
  final String reportingOfficerName;
  final String reportingOfficer1Name;
  final String address;
  final String emergencyContact;
  final List<Map<String, dynamic>> nominees;
  final List<Map<String, dynamic>> serviceHistory;
  final List<Map<String, dynamic>> familyMembers;

  // New address & DB fields
  final String permanentAddress;
  final String temporaryAddress;
  final String emergencyAddress;
  final String employeeGroup;
  final String employeeSubgroup;
  final String dopp;

  // Bank & Payslip Info
  final String bankAcc;
  final String bankKey;
  final String payscale;
  final String fb;

  const EmployeeModel({
    required this.id,
    required this.name,
    required this.fatherSpouseName,
    required this.designation,
    required this.department,
    required this.presentGrade,
    required this.dateOfBirth,
    required this.joinDate,
    required this.lastPromotionDate,
    required this.appointmentType,
    required this.category,
    required this.bloodGroup,
    required this.gender,
    required this.maritalStatus,
    required this.employeeId,
    required this.basicSalary,
    required this.presentPlaceOfPosting,
    required this.presentPostingDate,
    required this.retirementDate,
    required this.mobileNumber,
    required this.email,
    required this.uanNo,
    required this.panNo,
    required this.aadhaarNo,
    required this.pranNo,
    required this.pfNo,
    required this.pensionNo,
    required this.reportingOfficer,
    required this.reportingOfficer1,
    this.reportingOfficerName = '',
    this.reportingOfficer1Name = '',
    required this.address,
    required this.emergencyContact,
    required this.nominees,
    required this.serviceHistory,
    this.familyMembers = const [],
    this.bankAcc = 'N/A',
    this.bankKey = 'N/A',
    this.payscale = 'N/A',
    this.fb = 'N/A',
    this.permanentAddress = 'N/A',
    this.temporaryAddress = 'N/A',
    this.emergencyAddress = 'N/A',
    this.employeeGroup = 'N/A',
    this.employeeSubgroup = 'N/A',
    this.dopp = 'N/A',
  });

  static EmployeeModel fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      fatherSpouseName: json['fatherSpouseName']?.toString() ?? 'N/A',
      designation: json['designation']?.toString() ?? '',
      department: json['department']?.toString() ?? '',
      presentGrade: json['presentGrade']?.toString() ?? '',
      dateOfBirth: json['dateOfBirth']?.toString() ?? '',
      joinDate: json['joinDate']?.toString() ?? '',
      lastPromotionDate: json['lastPromotionDate']?.toString() ?? '',
      appointmentType: json['appointmentType']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      bloodGroup: json['bloodGroup']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
      maritalStatus: json['maritalStatus']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? json['employee_number']?.toString() ?? json['id']?.toString() ?? '',
      basicSalary: json['basicSalary']?.toString() ?? '0.00',
      presentPlaceOfPosting: json['presentPlaceOfPosting']?.toString() ?? '',
      presentPostingDate: json['presentPostingDate']?.toString() ?? '',
      retirementDate: json['retirementDate']?.toString() ?? '',
      mobileNumber: json['mobileNumber']?.toString() ?? json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      uanNo: json['uanNo']?.toString() ?? '',
      panNo: json['panNo']?.toString() ?? json['pan_number']?.toString() ?? '',
      aadhaarNo: json['aadhaarNo']?.toString() ?? '',
      pranNo: json['pranNo']?.toString() ?? '',
      pfNo: json['pfNo']?.toString() ?? '',
      pensionNo: json['pensionNo']?.toString() ?? '',
      reportingOfficer: json['reportingOfficer']?.toString() ?? '',
      reportingOfficer1: json['reportingOfficer1']?.toString() ?? '',
      reportingOfficerName: json['reportingOfficerName']?.toString() ?? '',
      reportingOfficer1Name: json['reportingOfficer1Name']?.toString() ?? '',
      address: json['address']?.toString() ?? json['permanentAddress']?.toString() ?? json['permanent_address']?.toString() ?? '',
      emergencyContact: json['emergencyContact']?.toString() ?? '',
      nominees: (json['nominees'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
      serviceHistory: (json['serviceHistory'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
      familyMembers: (json['familyMembers'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
      bankAcc: json['bankAcc']?.toString() ?? 'N/A',
      bankKey: json['bankKey']?.toString() ?? 'N/A',
      payscale: json['payscale']?.toString() ?? 'N/A',
      fb: json['fb']?.toString() ?? 'N/A',
      permanentAddress: json['permanentAddress']?.toString() ?? json['permanent_address']?.toString() ?? 'N/A',
      temporaryAddress: json['temporaryAddress']?.toString() ?? json['temporary_address']?.toString() ?? 'N/A',
      emergencyAddress: json['currentAddress']?.toString() ?? json['emergencyAddress']?.toString() ?? json['emergency_address']?.toString() ?? 'N/A',
      employeeGroup: json['employeeGroup']?.toString() ?? json['employee_group']?.toString() ?? 'N/A',
      employeeSubgroup: json['employeeSubgroup']?.toString() ?? json['employee_subgroup']?.toString() ?? 'N/A',
      dopp: json['dopp']?.toString() ?? 'N/A',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fatherSpouseName': fatherSpouseName,
      'designation': designation,
      'department': department,
      'presentGrade': presentGrade,
      'dateOfBirth': dateOfBirth,
      'joinDate': joinDate,
      'lastPromotionDate': lastPromotionDate,
      'appointmentType': appointmentType,
      'category': category,
      'bloodGroup': bloodGroup,
      'gender': gender,
      'maritalStatus': maritalStatus,
      'employeeId': employeeId,
      'basicSalary': basicSalary,
      'presentPlaceOfPosting': presentPlaceOfPosting,
      'presentPostingDate': presentPostingDate,
      'retirementDate': retirementDate,
      'mobileNumber': mobileNumber,
      'email': email,
      'uanNo': uanNo,
      'panNo': panNo,
      'aadhaarNo': aadhaarNo,
      'pranNo': pranNo,
      'pfNo': pfNo,
      'pensionNo': pensionNo,
      'reportingOfficer': reportingOfficer,
      'reportingOfficer1': reportingOfficer1,
      'reportingOfficerName': reportingOfficerName,
      'reportingOfficer1Name': reportingOfficer1Name,
      'address': address,
      'emergencyContact': emergencyContact,
      'nominees': nominees,
      'serviceHistory': serviceHistory,
      'familyMembers': familyMembers,
      'bankAcc': bankAcc,
      'bankKey': bankKey,
      'payscale': payscale,
      'fb': fb,
      'permanentAddress': permanentAddress,
      'temporaryAddress': temporaryAddress,
      'emergencyAddress': emergencyAddress,
      'employeeGroup': employeeGroup,
      'employeeSubgroup': employeeSubgroup,
      'dopp': dopp,
    };
  }

  Map<String, dynamic> toRawMap() {
    return {
      'empNo': employeeId,
      'name': name,
      'position': designation,
      'dept': department,
      'subgroupText': presentGrade,
      'dob': dateOfBirth,
      'apptDate': joinDate,
      'latPromo': lastPromotionDate,
      'group': employeeGroup != 'N/A' ? employeeGroup : appointmentType,
      'subgroup': employeeSubgroup,
      'caste': category,
      'blood': bloodGroup,
      'gender': gender,
      'marital': maritalStatus,
      'basic': basicSalary,
      'subarea': presentPlaceOfPosting,
      'actDoj': presentPostingDate,
      'retireDate': retirementDate,
      'mobile': mobileNumber,
      'email': email,
      'uan': uanNo,
      'pan': panNo,
      'aadhar': aadhaarNo,
      'praan': pranNo,
      'pfNo': pfNo,
      'pension': pensionNo,
      'reportingOfficer': reportingOfficer,
      'reportingOfficer1': reportingOfficer1,
      'reportingOfficerName': reportingOfficerName,
      'reportingOfficer1Name': reportingOfficer1Name,
      'permAddress': permanentAddress != 'N/A' ? permanentAddress : address,
      'tempAddress': temporaryAddress,
      'emergAddress': emergencyAddress,
      'dopp': dopp,
      'nominees': nominees,
      'serviceHistory': serviceHistory,
      'familyMembers': familyMembers,
      'bankAcc': bankAcc,
      'bankKey': bankKey,
      'payscale': payscale,
      'fb': fb,
    };
  }

  EmployeeModel copyWith({
    String? mobileNumber,
    String? address,
    String? emergencyContact,
    String? permanentAddress,
    String? temporaryAddress,
    String? emergencyAddress,
  }) {
    return EmployeeModel(
      id: id,
      name: name,
      fatherSpouseName: fatherSpouseName,
      designation: designation,
      department: department,
      presentGrade: presentGrade,
      dateOfBirth: dateOfBirth,
      joinDate: joinDate,
      lastPromotionDate: lastPromotionDate,
      appointmentType: appointmentType,
      category: category,
      bloodGroup: bloodGroup,
      gender: gender,
      maritalStatus: maritalStatus,
      employeeId: employeeId,
      basicSalary: basicSalary,
      presentPlaceOfPosting: presentPlaceOfPosting,
      presentPostingDate: presentPostingDate,
      retirementDate: retirementDate,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      email: email,
      uanNo: uanNo,
      panNo: panNo,
      aadhaarNo: aadhaarNo,
      pranNo: pranNo,
      pfNo: pfNo,
      pensionNo: pensionNo,
      reportingOfficer: reportingOfficer,
      reportingOfficer1: reportingOfficer1,
      reportingOfficerName: reportingOfficerName,
      reportingOfficer1Name: reportingOfficer1Name,
      address: address ?? this.address,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      nominees: nominees,
      serviceHistory: serviceHistory,
      familyMembers: familyMembers,
      bankAcc: bankAcc,
      bankKey: bankKey,
      payscale: payscale,
      fb: fb,
      permanentAddress: permanentAddress ?? this.permanentAddress,
      temporaryAddress: temporaryAddress ?? this.temporaryAddress,
      emergencyAddress: emergencyAddress ?? this.emergencyAddress,
      employeeGroup: employeeGroup,
      employeeSubgroup: employeeSubgroup,
      dopp: dopp,
    );
  }
}