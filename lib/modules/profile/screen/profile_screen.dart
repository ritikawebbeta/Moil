// lib/modules/profile/screen/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/profile_pdf_helper.dart';
import '../../../utils/app_colors.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/profile_controller.dart';
import '../../../widgets/app_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  final _mobileCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emergencyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();
      final user = auth.user;
      if (user != null) {
        context
            .read<ProfileController>()
            .fetchEmployeeProfile(user.employeeId);
      }
    });
  }

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _addressCtrl.dispose();
    _emergencyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer2<ProfileController, AuthController>(
        builder: (context, profileController, authController, _) {
          if (profileController.isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          final emp = profileController.employee;

          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: CustomAppBar(
              title: 'My Profile',
              showBack: false,
              actions: [
                if (emp != null)
                  IconButton(
                    icon: const Icon(Icons.print_outlined, color: Colors.white),
                    tooltip: 'Print HRIS Profile',
                    onPressed: () {
                      ProfilePdfHelper.printEmployeeProfilePdf(emp);
                    },
                  ),
                const SizedBox(width: 8),
              ],
            ),
            body: emp == null
                ? const Center(
                    child: Text(
                      'No profile data available.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : _isEditing
                    ? _buildEditForm()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildEmployeeInfo(emp),
                            const SizedBox(height: 16),
                            _buildActions(authController),
                          ],
                        ),
                      ),
          );
        },
      ),
    );
  }

  Widget _buildEmployeeInfo(dynamic emp) {
    if (emp == null) return const SizedBox.shrink();
    final rawList = ProfileController.rawEmployees;
    final Map<String, dynamic> raw = rawList.firstWhere(
      (e) => e['empNo'] == emp.employeeId,
      orElse: () => <String, dynamic>{},
    );

    final Map<String, dynamic> data = {
      'empNo': raw['empNo'] ?? emp.employeeId,
      'name': raw['name'] ?? emp.name,
      'status': raw['status'] ?? 'Active',
      'group': raw['group'] ?? emp.appointmentType,
      'subgroup': raw['subgroup'] ?? emp.presentGrade,
      'subgroupText': raw['subgroupText'] ?? emp.presentGrade,
      'position': raw['position'] ?? emp.designation,
      'seniority': raw['seniority'] ?? 'N/A',
      'payscale': raw['payscale'] ?? 'N/A',
      'dept': raw['dept'] ?? emp.department,
      'subarea': raw['subarea'] ?? emp.presentPlaceOfPosting,
      'gender': raw['gender'] ?? emp.gender,
      'dob': _formatRawDate(raw['dob'] ?? emp.dateOfBirth),
      'qual': raw['qual'] ?? 'N/A',
      'basic': raw['basic'] ?? emp.basicSalary,
      'apptDate': _formatRawDate(raw['apptDate'] ?? emp.joinDate),
      'dosl': _formatRawDate(raw['dosl']),
      'dopp': _formatRawDate(raw['dopp']),
      'retireDate': _formatRawDate(raw['retireDate'] ?? emp.retirementDate),
      'caste': raw['caste'] ?? emp.category,
      'marital': raw['marital'] ?? emp.maritalStatus,
      'mobile': raw['mobile'] ?? emp.mobileNumber,
      'email': raw['email'] ?? emp.email,
      'voter': raw['voter'] ?? 'N/A',
      'uan': raw['uan'] ?? emp.uanNo,
      'pension': raw['pension'] ?? emp.pensionNo,
      'passport': raw['passport'] ?? 'N/A',
      'pan': raw['pan'] ?? emp.panNo,
      'gratuity': raw['gratuity'] ?? 'N/A',
      'fb': raw['fb'] ?? 'N/A',
      'dl': raw['dl'] ?? 'N/A',
      'aadhar': raw['aadhar'] ?? emp.aadhaarNo,
      'blood': raw['blood'] ?? emp.bloodGroup,
      'praan': raw['praan'] ?? emp.pranNo,
      'ppo': raw['ppo'] ?? 'N/A',
      'newMed': raw['newMed'] ?? 'N/A',
      'oldMed': raw['oldMed'] ?? 'N/A',
      'penalty': raw['penalty'] ?? 'N/A',
      'epf': raw['epf'] ?? 'N/A',
      'pfNo': raw['pfNo'] ?? emp.pfNo,
      'pensionPf': raw['pensionPf'] ?? 'N/A',
      'purchasePrice': raw['purchasePrice'] ?? 'N/A',
      'fileNo': raw['fileNo'] ?? 'N/A',
      'bankKey': raw['bankKey'] ?? 'N/A',
      'bankAcc': raw['bankAcc'] ?? 'N/A',
      'nomGratuity': raw['nomGratuity'] ?? 'N/A',
      'nomGratuityRel': raw['nomGratuityRel'] ?? 'N/A',
      'nomPf': raw['nomPf'] ?? 'N/A',
      'nomPfRel': raw['nomPfRel'] ?? 'N/A',
      'nomPension': raw['nomPension'] ?? 'N/A',
      'nomPensionRel': raw['nomPensionRel'] ?? 'N/A',
      'permAddress': raw['permAddress'] ?? emp.address,
      'tempAddress': raw['tempAddress'] ?? 'N/A',
      'emergAddress': raw['emergAddress'] ?? 'N/A',
      'spouse': raw['spouse'] ?? emp.fatherSpouseName,
      'spouseDob': _formatRawDate(raw['spouseDob']),
      'child1': raw['child1'] ?? 'N/A',
      'childDob1': _formatRawDate(raw['childDob1']),
      'child2': raw['child2'] ?? 'N/A',
      'childDob2': _formatRawDate(raw['childDob2']),
      'child3': raw['child3'] ?? 'N/A',
      'childDob3': _formatRawDate(raw['childDob3']),
      'mother': raw['mother'] ?? 'N/A',
      'motherDob': _formatRawDate(raw['motherDob']),
      'father': raw['father'] ?? 'N/A',
      'fatherDob': _formatRawDate(raw['fatherDob']),
      'other': raw['other'] ?? 'N/A',
      'otherDob': _formatRawDate(raw['otherDob']),
      'sepDate': _formatRawDate(raw['sepDate']),
      'sepReason': raw['sepReason'] ?? 'N/A',
      'hireReason': raw['hireReason'] ?? 'N/A',
      'spouseAcc': raw['spouseAcc'] ?? 'N/A',
      'empRoll': raw['empRoll'] ?? emp.reportingOfficer,
    };

    final List<Map<String, String>> familyList = [];
    if (emp.familyMembers.isNotEmpty) {
      for (var f in emp.familyMembers) {
        familyList.add({
          'name': f['name']?.toString() ?? '',
          'relation': f['relation']?.toString() ?? '',
          'dob': f['dob']?.toString() ?? '',
          'gender': f['gender']?.toString() ?? '',
        });
      }
    } else {
      if (data['spouse'] != 'N/A' && data['spouse'].toString().isNotEmpty) {
        familyList.add({
          'name': data['spouse'],
          'relation': 'Spouse',
          'dob': data['spouseDob'],
          'gender': 'Female',
        });
      }
      if (data['father'] != 'N/A' && data['father'].toString().isNotEmpty) {
        familyList.add({
          'name': data['father'],
          'relation': 'Father',
          'dob': data['fatherDob'],
          'gender': 'Male',
        });
      }
      if (data['mother'] != 'N/A' && data['mother'].toString().isNotEmpty) {
        familyList.add({
          'name': data['mother'],
          'relation': 'Mother',
          'dob': data['motherDob'],
          'gender': 'Female',
        });
      }
      if (data['child1'] != 'N/A' && data['child1'].toString().isNotEmpty) {
        familyList.add({
          'name': data['child1'],
          'relation': 'Child',
          'dob': data['childDob1'],
          'gender': 'Female',
        });
      }
      if (data['child2'] != 'N/A' && data['child2'].toString().isNotEmpty) {
        familyList.add({
          'name': data['child2'],
          'relation': 'Child',
          'dob': data['childDob2'],
          'gender': 'Male',
        });
      }
    }

    Widget cellText(String text, {bool bold = false, TextAlign align = TextAlign.left, Color? bgColor}) {
      return Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        alignment: align == TextAlign.center ? Alignment.center : Alignment.centerLeft,
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontSize: 10,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: Colors.black87,
          ),
        ),
      );
    }

    Widget sectionHeader(String title) {
      return Container(
        width: double.infinity,
        color: Colors.grey.shade200,
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            letterSpacing: 0.5,
          ),
        ),
      );
    }

    final bool isMobile = MediaQuery.of(context).size.width < 800;

    Widget responsiveTable({required Widget child, double? minWidth}) {
      if (isMobile) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: minWidth ?? 600,
            child: child,
          ),
        );
      }
      return child;
    }

    Widget buildMainDetailsTable() {
      if (isMobile) {
        return Table(
          border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
          columnWidths: const {
            0: FixedColumnWidth(150),
            1: FlexColumnWidth(),
          },
          children: [
            TableRow(children: [
              cellText('NAME', bold: true),
              cellText(': ${data['name']}'),
            ]),
            TableRow(children: [
              cellText('EMP.NO / FORM B', bold: true),
              cellText(': ${data['empNo'].toString().padLeft(8, '0')}'),
            ]),
            TableRow(children: [
              cellText('FATHER / SPOUSE NAME', bold: true),
              cellText(': ${data['spouse']}'),
            ]),
            TableRow(children: [
              cellText('BASIC (RS)', bold: true),
              cellText(': ${data['basic']}'),
            ]),
            TableRow(children: [
              cellText('DESIGNATION', bold: true),
              cellText(': ${data['position']}'),
            ]),
            TableRow(children: [
              cellText('PRESENT PLACE OF POSTING', bold: true),
              cellText(': ${data['subarea']}'),
            ]),
            TableRow(children: [
              cellText('DEPARTMENT', bold: true),
              cellText(': ${data['dept']}'),
            ]),
            TableRow(children: [
              cellText('DATE OF PRESENT POSTING', bold: true),
              cellText(': ${data['dopp']}'),
            ]),
            TableRow(children: [
              cellText('PRESENT SUBGROUP', bold: true),
              cellText(': ${data['subgroup']}'),
            ]),
            TableRow(children: [
              cellText('DATE OF RETIREMENT', bold: true),
              cellText(': ${data['retireDate']}'),
            ]),
            TableRow(children: [
              cellText('DATE OF BIRTH', bold: true),
              cellText(': ${data['dob']}'),
            ]),
            TableRow(children: [
              cellText('MOBLIE NO', bold: true),
              cellText(': ${data['mobile']}'),
            ]),
            TableRow(children: [
              cellText('DATE OF JOINING IN MOIL', bold: true),
              cellText(': ${data['apptDate']}'),
            ]),
            TableRow(children: [
              cellText('E-MAIL', bold: true),
              cellText(': ${data['email']}'),
            ]),
            TableRow(children: [
              cellText('DATE OF LAST PROMOTION', bold: true),
              cellText(': ${data['dosl']}'),
            ]),
            TableRow(children: [
              cellText('UAN NO', bold: true),
              cellText(': ${data['uan']}'),
            ]),
            TableRow(children: [
              cellText('APPOINTMENT TYPE', bold: true),
              cellText(': ${data['group']}'),
            ]),
            TableRow(children: [
              cellText('PAN NO', bold: true),
              cellText(': ${data['pan']}'),
            ]),
            TableRow(children: [
              cellText('CATEGORY', bold: true),
              cellText(': ${data['caste']}'),
            ]),
            TableRow(children: [
              cellText('AADHAR NO', bold: true),
              cellText(': ${data['aadhar']}'),
            ]),
            TableRow(children: [
              cellText('BLOOD GROUP', bold: true),
              cellText(': ${data['blood']}'),
            ]),
            TableRow(children: [
              cellText('PRAN NO', bold: true),
              cellText(': ${data['praan']}'),
            ]),
            TableRow(children: [
              cellText('GENDER', bold: true),
              cellText(': ${data['gender']}'),
            ]),
            TableRow(children: [
              cellText('PF NO/SSPF NO', bold: true),
              cellText(': ${data['pfNo']}'),
            ]),
            TableRow(children: [
              cellText('MARITAL STATUS', bold: true),
              cellText(': ${data['marital']}'),
            ]),
            TableRow(children: [
              cellText('PENSION NO', bold: true),
              cellText(': ${data['pensionPf']}'),
            ]),
          ],
        );
      } else {
        return Table(
          border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
          columnWidths: const {
            0: FixedColumnWidth(180),
            1: FlexColumnWidth(),
            2: FixedColumnWidth(180),
            3: FlexColumnWidth(),
          },
          children: [
            TableRow(children: [
              cellText('NAME', bold: true),
              cellText(': ${data['name']}'),
              cellText('EMP.NO / FORM B', bold: true),
              cellText(': ${data['empNo'].toString().padLeft(8, '0')}'),
            ]),
            TableRow(children: [
              cellText('FATHER / SPOUSE NAME', bold: true),
              cellText(': ${data['spouse']}'),
              cellText('BASIC (RS)', bold: true),
              cellText(': ${data['basic']}'),
            ]),
            TableRow(children: [
              cellText('DESIGNATION', bold: true),
              cellText(': ${data['position']}'),
              cellText('PRESENT PLACE OF POSTING', bold: true),
              cellText(': ${data['subarea']}'),
            ]),
            TableRow(children: [
              cellText('DEPARTMENT', bold: true),
              cellText(': ${data['dept']}'),
              cellText('DATE OF PRESENT POSTING', bold: true),
              cellText(': ${data['dopp']}'),
            ]),
            TableRow(children: [
              cellText('PRESENT SUBGROUP', bold: true),
              cellText(': ${data['subgroup']}'),
              cellText('DATE OF RETIREMENT', bold: true),
              cellText(': ${data['retireDate']}'),
            ]),
            TableRow(children: [
              cellText('DATE OF BIRTH', bold: true),
              cellText(': ${data['dob']}'),
              cellText('MOBLIE NO', bold: true),
              cellText(': ${data['mobile']}'),
            ]),
            TableRow(children: [
              cellText('DATE OF JOINING IN MOIL', bold: true),
              cellText(': ${data['apptDate']}'),
              cellText('E-MAIL', bold: true),
              cellText(': ${data['email']}'),
            ]),
            TableRow(children: [
              cellText('DATE OF LAST PROMOTION', bold: true),
              cellText(': ${data['dosl']}'),
              cellText('UAN NO', bold: true),
              cellText(': ${data['uan']}'),
            ]),
            TableRow(children: [
              cellText('APPOINTMENT TYPE', bold: true),
              cellText(': ${data['group']}'),
              cellText('PAN NO', bold: true),
              cellText(': ${data['pan']}'),
            ]),
            TableRow(children: [
              cellText('CATEGORY', bold: true),
              cellText(': ${data['caste']}'),
              cellText('AADHAR NO', bold: true),
              cellText(': ${data['aadhar']}'),
            ]),
            TableRow(children: [
              cellText('BLOOD GROUP', bold: true),
              cellText(': ${data['blood']}'),
              cellText('PRAN NO', bold: true),
              cellText(': ${data['praan']}'),
            ]),
            TableRow(children: [
              cellText('GENDER', bold: true),
              cellText(': ${data['gender']}'),
              cellText('PF NO/SSPF NO', bold: true),
              cellText(': ${data['pfNo']}'),
            ]),
            TableRow(children: [
              cellText('MARITAL STATUS', bold: true),
              cellText(': ${data['marital']}'),
              cellText('PENSION NO', bold: true),
              cellText(': ${data['pensionPf']}'),
            ]),
          ],
        );
      }
    }

    Widget contentCard = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Block
          isMobile
              ? Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'मॉयल\nMOIL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 6.5,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'MOIL LIMITED',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Human Resource Information System',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '( EMPLOYEE PROFILE )',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'मॉयल\nMOIL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 6.5,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'MOIL LIMITED',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Human Resource Information System',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '( EMPLOYEE PROFILE )',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 50),
                  ],
                ),
          const SizedBox(height: 12),
          const Divider(thickness: 1.5, color: Colors.black87),
          const SizedBox(height: 12),

          // Employee Grid Block
          buildMainDetailsTable(),
          const SizedBox(height: 16),

          // Centered Avatar Photo Frame
          Center(
            child: Container(
              width: 100,
              height: 110,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400, width: 1),
              ),
              child: (() {
                final id = emp.employeeId.trim().replaceAll(RegExp('^0+'), '');
                if (id == '16194') {
                  return Image.asset('assets/images/rakesh_tumane.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter);
                } else if (id == '17110') {
                  return Image.asset('assets/images/sameer_banerjee.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter);
                } else if (id == '540') {
                  return Image.asset('assets/images/swapnil_manpe.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter);
                } else if (id == '4410') {
                  return Image.asset('assets/images/ranjeet_chouhan.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter);
                } else if (id == '4428') {
                  return Image.asset('assets/images/bcn_gautam.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter);
                } else {
                  return Container(
                    color: Colors.grey.shade100,
                    child: const Center(
                      child: Text(
                        'Passport Size\nPhoto',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 8, color: Colors.grey),
                      ),
                    ),
                  );
                }
              }()),
            ),
          ),
          const SizedBox(height: 16),

          // Qualification Header & Table
          sectionHeader('QUALIFICATION PROFILE'),
          const SizedBox(height: 4),
          responsiveTable(
            minWidth: 400,
            child: Table(
              border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
              columnWidths: const {
                0: FixedColumnWidth(50),
                1: FlexColumnWidth(),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: [
                    cellText('SL NO', bold: true),
                    cellText('QUALIFICATION', bold: true),
                  ],
                ),
                TableRow(
                  children: [
                    cellText('1'),
                    cellText(data['qual'] ?? ''),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Family Particulars
          sectionHeader('FAMILY PARTICULARS'),
          const SizedBox(height: 4),
          responsiveTable(
            minWidth: 600,
            child: Table(
              border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
              columnWidths: const {
                0: FixedColumnWidth(50),
                1: FlexColumnWidth(2.5),
                2: FlexColumnWidth(2.5),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(1.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: [
                    cellText('SL NO', bold: true),
                    cellText('NAME OF THE MEMBER', bold: true),
                    cellText('RELATIONSHIP WITH THE EMPLOYEE', bold: true),
                    cellText('DATE OF BIRTH', bold: true),
                    cellText('GENDER', bold: true),
                  ],
                ),
                if (familyList.isNotEmpty)
                  ...familyList.asMap().entries.map((e) {
                    final idx = e.key + 1;
                    final member = e.value;
                    return TableRow(children: [
                      cellText('$idx'),
                      cellText(member['name'] ?? ''),
                      cellText(member['relation'] ?? ''),
                      cellText(member['dob'] ?? ''),
                      cellText(member['gender'] ?? ''),
                    ]);
                  }).toList()
                else
                  TableRow(children: [
                    cellText('1'),
                    cellText('N/A'),
                    cellText('N/A'),
                    cellText('N/A'),
                    cellText('N/A'),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Nominees of Employee
          sectionHeader('NOMINEES OF EMPLOYEE'),
          const SizedBox(height: 4),
          responsiveTable(
            minWidth: 600,
            child: Table(
              border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
              columnWidths: const {
                0: FixedColumnWidth(50),
                1: FlexColumnWidth(2.5),
                2: FlexColumnWidth(2.5),
                3: FlexColumnWidth(2),
                4: FlexColumnWidth(1.8),
                5: FixedColumnWidth(55),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: [
                    cellText('SL.NO', bold: true),
                    cellText('BENEFIT TYPE', bold: true),
                    cellText('NOMINEE NAME', bold: true),
                    cellText('RELATIONSHIP WITH EMPLOYEE', bold: true),
                    cellText('DATE OF BIRTH', bold: true),
                    cellText('%AGE', bold: true),
                  ],
                ),
                if (emp.nominees.isNotEmpty)
                  ...emp.nominees.asMap().entries.map((e) {
                    final idx = e.key + 1;
                    final nom = e.value;
                    return TableRow(children: [
                      cellText('$idx'),
                      cellText(nom['benefit'] ?? ''),
                      cellText(nom['name'] ?? ''),
                      cellText(nom['relation'] ?? ''),
                      cellText(nom['dob'] ?? ''),
                      cellText('${nom['percentage']}%'),
                    ]);
                  }).toList()
                else
                  TableRow(children: [
                    cellText('1'),
                    cellText('N/A'),
                    cellText('N/A'),
                    cellText('N/A'),
                    cellText('N/A'),
                    cellText('N/A'),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Address Block
          sectionHeader('ADDRESS'),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 0.5),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'PERMANENT ADDRESS: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87)),
                      TextSpan(text: '${data['permAddress']}\n', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                      const TextSpan(text: 'LOCAL ADDRESS: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87)),
                      TextSpan(text: '${data['tempAddress']}\n', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                      const TextSpan(text: 'EMERGENCY ADDRESS: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87)),
                      TextSpan(text: '${data['emergAddress']}', style: const TextStyle(fontSize: 10, color: Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Service Particulars
          sectionHeader('SERVICE PARTICULARS'),
          const SizedBox(height: 4),
          responsiveTable(
            minWidth: 700,
            child: Table(
              border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
              columnWidths: const {
                0: FixedColumnWidth(40),
                1: FlexColumnWidth(2.5),
                2: FixedColumnWidth(50),
                3: FlexColumnWidth(1.8),
                4: FlexColumnWidth(1.5),
                5: FlexColumnWidth(1.5),
                6: FlexColumnWidth(2.2),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.shade50),
                  children: [
                    cellText('SL NO', bold: true),
                    cellText('DESIGNATION', bold: true),
                    cellText('GRADE', bold: true),
                    cellText('LOCATION', bold: true),
                    cellText('FROM', bold: true),
                    cellText('TO', bold: true),
                    cellText('PAYSCALE', bold: true),
                  ],
                ),
                if (emp.serviceHistory.isNotEmpty)
                  ...emp.serviceHistory.asMap().entries.map((e) {
                    final idx = e.key + 1;
                    final sh = e.value;
                    return TableRow(children: [
                      cellText('$idx'),
                      cellText(sh['designation'] ?? ''),
                      cellText(sh['grade'] ?? ''),
                      cellText(sh['location'] ?? ''),
                      cellText(sh['from'] ?? ''),
                      cellText(sh['to'] ?? ''),
                      cellText(sh['payscale'] ?? ''),
                    ]);
                  }).toList()
                else
                  TableRow(children: [
                    cellText('1'),
                    cellText(emp.designation),
                    cellText(emp.presentGrade),
                    cellText(emp.presentPlaceOfPosting),
                    cellText(emp.joinDate),
                    cellText('Till Date'),
                    cellText(emp.basicSalary),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );

    if (isMobile) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: contentCard,
      );
    } else {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 850,
            child: contentCard,
          ),
        ),
      );
    }
  }

  Widget _buildEditForm() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const SectionHeader(title: 'Edit Profile', icon: Icons.edit_outlined),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  controller: _mobileCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    prefixIcon:
                        Icon(Icons.phone_outlined, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _addressCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on_outlined,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emergencyCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Contact',
                    prefixIcon: Icon(Icons.emergency_outlined,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Save Changes',
                  icon: Icons.save_outlined,
                  onPressed: _saveProfile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildRolePermissions(String role) {
  //   const permissions = ['View Leave', 'Apply Leave', 'View Tour', 'Apply Tour', 'View Payslip', 'View Holiday', 'Update Profile'];

  //   return GlassCard(
  //     padding: EdgeInsets.zero,
  //     child: Column(
  //       children: [
  //         const SectionHeader(title: 'Role & Permissions', icon: Icons.security_outlined),
  //         Padding(
  //           padding: const EdgeInsets.all(16),
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Container(
  //                 padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
  //                 decoration: BoxDecoration(
  //                   color: AppColors.primary,
  //                   borderRadius: BorderRadius.circular(10),
  //                 ),
  //                 child: Text('Role: $role', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
  //               ),
  //               const SizedBox(height: 14),
  //               Wrap(
  //                 spacing: 8,
  //                 runSpacing: 8,
  //                 children: permissions.map((p) => Container(
  //                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  //                   decoration: BoxDecoration(
  //                     color: AppColors.success.withOpacity(0.08),
  //                     borderRadius: BorderRadius.circular(6),
  //                     border: Border.all(color: AppColors.success.withOpacity(0.2)),
  //                   ),
  //                   child: Row(
  //                     mainAxisSize: MainAxisSize.min,
  //                     children: [
  //                       const Icon(Icons.check_circle_outline, color: AppColors.success, size: 14),
  //                       const SizedBox(width: 4),
  //                       Text(p, style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w600)),
  //                     ],
  //                   ),
  //                 )).toList(),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildActions(AuthController authController) {
    return Column(
      children: [
        _ActionTile(
          icon: Icons.lock_reset_rounded,
          label: 'Change Password',
          color: AppColors.warning,
          onTap: _showChangePassword,
        ),
        const SizedBox(height: 10),
        _ActionTile(
          icon: Icons.logout_rounded,
          label: 'Logout',
          color: AppColors.error,
          onTap: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  backgroundColor: AppColors.cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Confirm Logout',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  content: const Text(
                    'Are you sure you want to log out of MOIL LMS?',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // Close dialog
                        authController.logout();
                        Navigator.pushReplacementNamed(context, '/login');
                      },
                      child: const Text('Logout'),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _saveProfile() async {
    final success = await context.read<ProfileController>().updateProfile(
          mobileNumber: _mobileCtrl.text,
          address: _addressCtrl.text,
          emergencyContact: _emergencyCtrl.text,
        );
    if (mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success
            ? 'Profile updated successfully!'
            : 'Failed to update profile.'),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _showChangePassword() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CompulsoryPasswordChangeDialog(
        dismissible: true,
        onSuccess: () {},
      ),
    );
  }

  String _formatRawDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'N/A') return 'N/A';
    try {
      final clean = raw.replaceAll('/', '-');
      final parts = clean.split('-');
      if (parts.length == 3) {
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        if (year < 100) {
          year += (year > 30 ? 1900 : 2000);
        }
        final dt = DateTime(year, month, day);
        return DateFormat('dd-MM-yyyy').format(dt);
      }
    } catch (_) {}
    return raw.replaceAll('/', '-');
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
