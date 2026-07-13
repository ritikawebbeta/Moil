// lib/modules/profile/screen/employee_detail_screen.dart
import 'package:employee_management/modules/profile/controller/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../utils/profile_pdf_helper.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_widgets.dart';
import '../../../model/employee_model.dart';
import '../../leave/controller/leave_controller.dart';
import '../../tour/controller/tour_controller.dart';
import '../../auth/controller/auth_controller.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../payslip/utils/payslip_pdf_helper.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final EmployeeModel employee;
  final int initialTabIndex;
  const EmployeeDetailScreen({super.key, required this.employee, this.initialTabIndex = 0});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedMonth;
  String _historyFilterYear = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaveController>().fetchLeaves(widget.employee.employeeId);
      context.read<TourController>().fetchTours(widget.employee.employeeId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    try {
      final leaveController = context.read<LeaveController>();
      final tourController = context.read<TourController>();
      final authController = context.read<AuthController>();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (authController.user != null) {
          final empId = authController.user!.employeeId;
          leaveController.fetchLeaves(empId);
          leaveController.fetchBalances(empId);
          tourController.fetchTours(empId);
        }
      });
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: widget.employee.name,
        showBack: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined, color: Colors.white),
            tooltip: 'Print HRIS Profile',
            onPressed: () {
              ProfilePdfHelper.printEmployeeProfilePdf(widget.employee);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.backgroundSecondary,
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              dividerColor: AppColors.cardBorder,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tabs: const [
                Tab(text: 'Profile'),
                Tab(text: 'Leaves'),
                Tab(text: 'Tours'),
                Tab(text: 'Payslips'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(),
                _buildLeavesTab(),
                _buildToursTab(),
                _buildPayslipsTab(),
              ],
            ),
          ),
        ],
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

  Widget _buildProfileTab() {
    final emp = widget.employee;
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
              cellText('', bold: true),
              cellText(''),
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
              cellText('PF NO/SSPF NO', bold: true),
              cellText(': ${data['pfNo']}'),
              cellText('', bold: true),
              cellText(''),
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
              child: (emp.employeeId.trim().replaceAll(RegExp('^0+'), '') == '446')
                  ? Image.asset(
                      'assets/images/raja_talathoti.jpg',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    )
                  : (emp.employeeId.trim().replaceAll(RegExp('^0+'), '') == '16194')
                      ? Image.asset(
                          'assets/images/rakesh_tumane.jpg',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        )
                      : (emp.employeeId.trim().replaceAll(RegExp('^0+'), '') == '17110')
                          ? Image.asset(
                              'assets/images/sameer_banerjee.jpg',
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                            )
                          : Container(
                              color: Colors.grey.shade100,
                              child: const Center(
                                child: Text(
                                  'Passport Size\nPhoto',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 8, color: Colors.grey),
                                ),
                              ),
                            ),
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: isMobile ? 650 : 850,
              child: contentCard,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeavesTab() {
    return Consumer<LeaveController>(
      builder: (context, controller, _) {
        if (controller.status == LeaveStatus.loading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final leaves = controller.leaves;
        if (leaves.isEmpty) {
          return const EmptyState(
            icon: Icons.event_note_outlined,
            title: 'No Leave Records',
            subtitle: 'This employee has no leave records.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: leaves.length,
          itemBuilder: (context, index) {
            final leave = leaves[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        LeaveTypeBadge(type: leave.leaveType),
                        StatusBadge(status: leave.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.date_range_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${DateFormat('dd-MM-yyyy').format(leave.startDate)} – ${DateFormat('dd-MM-yyyy').format(leave.endDate)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${leave.startTime} – ${leave.endTime} (${leave.duration})',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    if (leave.absenceHours != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Absence Hours: ${leave.absenceHours!.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildToursTab() {
    return Consumer<TourController>(
      builder: (context, controller, _) {
        if (controller.status == TourStatus.loading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final tours = controller.tours;
        if (tours.isEmpty) {
          return const EmptyState(
            icon: Icons.flight_takeoff_rounded,
            title: 'No Tour Records',
            subtitle: 'This employee has no tour records.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tours.length,
          itemBuilder: (context, index) {
            final tour = tours[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tour.tourType,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                        ),
                        StatusBadge(status: tour.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          tour.destination,
                          style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${DateFormat('dd-MM-yyyy').format(tour.startDate)} – ${DateFormat('dd-MM-yyyy').format(tour.endDate)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    if (tour.travelPurpose.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        tour.travelPurpose,
                        style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPayslipsTab() {
    final double basic = double.tryParse(widget.employee.basicSalary.replaceAll(',', '')) ?? 100000.00;
    
    final List<Map<String, dynamic>> payslips = [
      {'month': 'May 2026', 'gross': basic * 1.85, 'deductions': basic * 0.46, 'status': 'Available'},
      {'month': 'April 2026', 'gross': basic * 1.85, 'deductions': basic * 0.46, 'status': 'Available'},
      {'month': 'March 2026', 'gross': basic * 1.85, 'deductions': basic * 0.45, 'status': 'Available'},
      {'month': 'February 2026', 'gross': basic * 1.85, 'deductions': basic * 0.46, 'status': 'Available'},
      {'month': 'January 2026', 'gross': basic * 1.85, 'deductions': basic * 0.46, 'status': 'Available'},
      {'month': 'December 2025', 'gross': basic * 1.80, 'deductions': basic * 0.44, 'status': 'Available'},
      {'month': 'November 2025', 'gross': basic * 1.80, 'deductions': basic * 0.44, 'status': 'Available'},
      {'month': 'October 2025', 'gross': basic * 1.80, 'deductions': basic * 0.44, 'status': 'Available'},
      {'month': 'September 2025', 'gross': basic * 1.80, 'deductions': basic * 0.44, 'status': 'Available'},
      {'month': 'August 2025', 'gross': basic * 1.80, 'deductions': basic * 0.44, 'status': 'Available'},
      {'month': 'July 2025', 'gross': basic * 1.80, 'deductions': basic * 0.44, 'status': 'Available'},
      {'month': 'June 2025', 'gross': basic * 1.80, 'deductions': basic * 0.44, 'status': 'Available'},
      {'month': 'May 2025', 'gross': basic * 1.80, 'deductions': basic * 0.44, 'status': 'Available'},
      {'month': 'April 2025', 'gross': basic * 1.80, 'deductions': basic * 0.44, 'status': 'Available'},
      {'month': 'March 2025', 'gross': basic * 1.80, 'deductions': basic * 0.44, 'status': 'Available'},
      {'month': 'February 2025', 'gross': basic * 1.80, 'deductions': basic * 0.44, 'status': 'Available'},
      {'month': 'January 2025', 'gross': basic * 1.80, 'deductions': basic * 0.44, 'status': 'Available'},
      {'month': 'December 2024', 'gross': basic * 1.75, 'deductions': basic * 0.42, 'status': 'Available'},
      {'month': 'November 2024', 'gross': basic * 1.75, 'deductions': basic * 0.42, 'status': 'Available'},
      {'month': 'October 2024', 'gross': basic * 1.75, 'deductions': basic * 0.42, 'status': 'Available'},
      {'month': 'September 2024', 'gross': basic * 1.75, 'deductions': basic * 0.42, 'status': 'Available'},
      {'month': 'August 2024', 'gross': basic * 1.75, 'deductions': basic * 0.42, 'status': 'Available'},
      {'month': 'July 2024', 'gross': basic * 1.75, 'deductions': basic * 0.42, 'status': 'Available'},
      {'month': 'June 2024', 'gross': basic * 1.75, 'deductions': basic * 0.42, 'status': 'Available'},
      {'month': 'May 2024', 'gross': basic * 1.75, 'deductions': basic * 0.42, 'status': 'Available'},
      {'month': 'April 2024', 'gross': basic * 1.75, 'deductions': basic * 0.42, 'status': 'Available'},
      {'month': 'March 2024', 'gross': basic * 1.75, 'deductions': basic * 0.42, 'status': 'Available'},
      {'month': 'February 2024', 'gross': basic * 1.75, 'deductions': basic * 0.42, 'status': 'Available'},
      {'month': 'January 2024', 'gross': basic * 1.75, 'deductions': basic * 0.42, 'status': 'Available'},
    ];

    if (_selectedMonth == null || !payslips.any((p) => p['month'] == _selectedMonth)) {
      _selectedMonth = payslips.first['month'];
    }

    final currentPayslip = payslips.firstWhere((p) => p['month'] == _selectedMonth);
    final double grossVal = currentPayslip['gross'];
    final double deductionsVal = currentPayslip['deductions'];
    final double netVal = grossVal - deductionsVal;

    // Breakdown
    final double basicPart = basic;
    final double daPart = basic * 0.50;
    final double hraPart = basic * 0.15;
    final double otherPerksPart = grossVal - basicPart - daPart - hraPart;

    final double pfPart = deductionsVal * 0.35;
    final double itPart = deductionsVal * 0.45;
    final double otherDeductionsPart = deductionsVal - pfPart - itPart;

    final format = NumberFormat.currency(locale: 'HI', symbol: '₹', decimalDigits: 2);
    final formatSimple = NumberFormat.currency(locale: 'HI', symbol: '₹', decimalDigits: 0);

    Widget buildBreakdownRow(String label, String value, {bool isDeduction = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            Text(
              value,
              style: TextStyle(
                color: isDeduction ? AppColors.error : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    Widget buildSalaryCard(String label, String amount, Color color, IconData icon) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(amount, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final double width = MediaQuery.of(context).size.width;
    final bool isMobileLayout = width < 600;

    final filteredHistory = payslips.where((p) {
      if (_historyFilterYear == 'All') return true;
      return p['month'].contains(_historyFilterYear);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Salary Summary Card
          GlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Salary Summary',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedMonth,
                          dropdownColor: AppColors.cardBg,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                          items: payslips.map((p) {
                            return DropdownMenuItem<String>(
                              value: p['month'],
                              child: Text(p['month']),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedMonth = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                isMobileLayout
                    ? Column(
                        children: [
                          buildSalaryCard('Gross Salary', formatSimple.format(grossVal), AppColors.success, Icons.account_balance_wallet_outlined),
                          const SizedBox(height: 12),
                          buildSalaryCard('Deductions', formatSimple.format(deductionsVal), AppColors.error, Icons.remove_circle_outline),
                          const SizedBox(height: 12),
                          buildSalaryCard('Net Pay', formatSimple.format(netVal), AppColors.primary, Icons.payments_outlined),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: buildSalaryCard('Gross Salary', formatSimple.format(grossVal), AppColors.success, Icons.account_balance_wallet_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: buildSalaryCard('Deductions', formatSimple.format(deductionsVal), AppColors.error, Icons.remove_circle_outline)),
                          const SizedBox(width: 12),
                          Expanded(child: buildSalaryCard('Net Pay', formatSimple.format(netVal), AppColors.primary, Icons.payments_outlined)),
                        ],
                      ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.cardBorder),
                const SizedBox(height: 12),
                buildBreakdownRow('Basic Pay - Exe & NE', format.format(basicPart)),
                buildBreakdownRow('Dearness Allow - Exe & NE', format.format(daPart)),
                buildBreakdownRow('House Rent Allow E&NE', format.format(hraPart)),
                buildBreakdownRow('Other Perks', format.format(otherPerksPart)),
                buildBreakdownRow('Ee PF contribution', '-${format.format(pfPart)}', isDeduction: true),
                buildBreakdownRow('Income Tax', '-${format.format(itPart)}', isDeduction: true),
                buildBreakdownRow('Other Deductions', '-${format.format(otherDeductionsPart)}', isDeduction: true),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Payslip History Card
          GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: SectionHeader(title: 'Payslip History', icon: Icons.receipt_long_outlined),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _historyFilterYear,
                            dropdownColor: AppColors.cardBg,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Years')),
                              DropdownMenuItem(value: '2026', child: Text('2026')),
                              DropdownMenuItem(value: '2025', child: Text('2025')),
                              DropdownMenuItem(value: '2024', child: Text('2024')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _historyFilterYear = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (filteredHistory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No payslips available for the selected year',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  )
                else
                  ...filteredHistory.asMap().entries.map((entry) {
                    final p = entry.value;
                    final isEven = entry.key.isEven;
                    final double g = p['gross'];
                    final double d = p['deductions'];
                    final double n = g - d;
                    return Column(
                      children: [
                        Container(
                          color: isEven ? AppColors.background.withOpacity(0.3) : Colors.transparent,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p['month'],
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Net: ${format.format(n)}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Gross: ${format.format(g)}',
                                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined, color: AppColors.primary, size: 20),
                                    onPressed: () {
                                      _viewEmployeePayslip(p['month'], g, d, n);
                                    },
                                    tooltip: 'View Payslip',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.download_outlined, color: AppColors.textSecondary, size: 20),
                                    onPressed: () {
                                      PayslipPdfHelper.printPayslipPdf(
                                        p['month'],
                                        employeeId: widget.employee.employeeId,
                                        gross: g,
                                        deductions: d,
                                      );
                                    },
                                    tooltip: 'Download PDF',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.cardBorder),
                      ],
                    );
                  }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _viewEmployeePayslip(String month, double gross, double deductions, double net) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('View Payslip - $month', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: PdfPreview(
                    build: (format) => PayslipPdfHelper.generatePayslipPdfBytes(
                      month,
                      employeeId: widget.employee.employeeId,
                      gross: gross,
                      deductions: deductions,
                    ),
                    allowPrinting: true,
                    allowSharing: true,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    initialPageFormat: PdfPageFormat.a4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
