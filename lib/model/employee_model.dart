// lib/model/employee_model.dart

class EmployeeModel {
  final String id;

  // 1. NAME
  final String name;

  // 2. FATHER / SPOUSE NAME
  final String fatherSpouseName;

  // 3. DESIGNATION
  final String designation;

  // 4. DEPARTMENT
  final String department;

  // 5. PRESENT GRADE
  final String presentGrade;

  // 6. DATE OF BIRTH
  final String dateOfBirth;

  // 7. DATE OF JOINING IN MOIL
  final String joinDate;

  // 8. DATE OF LAST PROMOTION
  final String lastPromotionDate;

  // 9. APPOINTMENT TYPE
  final String appointmentType;

  // 10. CATEGORY
  final String category;

  // 11. BLOOD GROUP
  final String bloodGroup;

  // 12. GENDER
  final String gender;

  // 13. MARITAL STATUS
  final String maritalStatus;

  // 14. EMP.NO / FORM B
  final String employeeId;

  // 15. BASIC (RS)
  final String basicSalary;

  // 16. PRESENT PLACE OF POSTING
  final String presentPlaceOfPosting;

  // 17. DATE OF PRESENT POSTING
  final String presentPostingDate;

  // 18. DATE OF RETIREMENT
  final String retirementDate;

  // 19. MOBILE NO
  final String mobileNumber;

  // 20. E-MAIL
  final String email;

  // 21. UAN NO
  final String uanNo;

  // 22. PAN NO
  final String panNo;

  // 23. AADHAAR NO
  final String aadhaarNo;

  // 24. PRAN NO
  final String pranNo;

  // 25. PF NO / SSPF NO
  final String pfNo;

  // 26. PENSION NO
  final String pensionNo;

  // Additional Fields
  final String reportingOfficer;
  final String address;
  final String emergencyContact;

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
    required this.address,
    required this.emergencyContact,
  });
}