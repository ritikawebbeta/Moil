// lib/modules/profile/screen/employee_detail_screen.dart
import 'package:employee_management/modules/profile/controller/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_widgets.dart';
import '../../../model/employee_model.dart';
import '../../leave/controller/leave_controller.dart';
import '../../tour/controller/tour_controller.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final EmployeeModel employee;
  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaveController>().fetchLeaves(widget.employee.employeeId);
      context.read<TourController>().fetchTours(widget.employee.employeeId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: widget.employee.name,
        showBack: true,
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
      final parts = raw.split(RegExp(r'[./-]'));
      if (parts.length == 3) {
        int month = int.parse(parts[0]);
        int day = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        if (year < 100) {
          year += (year > 30 ? 1900 : 2000);
        }
        final dt = DateTime(year, month, day);
        return DateFormat('dd/MM/yyyy').format(dt);
      }
    } catch (_) {}
    return raw;
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Official Placement Info Card
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Official Placement Info',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 12),
                InfoRow(label: 'Employee Number', value: data['empNo'] ?? ''),
                InfoRow(label: 'Employment Status', value: data['status'] ?? ''),
                InfoRow(label: 'Employee Group', value: data['group'] ?? ''),
                InfoRow(label: 'Employee Subgroup', value: data['subgroup'] ?? ''),
                InfoRow(label: 'Employee Subgroup Text', value: data['subgroupText'] ?? ''),
                InfoRow(label: 'Position Name', value: data['position'] ?? ''),
                InfoRow(label: 'Seniority Number', value: data['seniority'] ?? ''),
                InfoRow(label: 'Payscale', value: data['payscale'] ?? ''),
                InfoRow(label: 'Department', value: data['dept'] ?? ''),
                InfoRow(label: 'Personnel Subarea', value: data['subarea'] ?? ''),
                InfoRow(label: 'Emp Roll', value: data['empRoll'] ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Personal Details Card
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Personal Info',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),
                InfoRow(label: 'Gender', value: data['gender'] ?? ''),
                InfoRow(label: 'Date of Birth', value: data['dob'] ?? ''),
                InfoRow(label: 'Qualification', value: data['qual'] ?? ''),
                InfoRow(label: 'Basic Pay', value: 'Rs. ${data['basic'] ?? ''}'),
                InfoRow(label: 'Date of Appointment', value: data['apptDate'] ?? ''),
                InfoRow(label: 'DoSL', value: data['dosl'] ?? ''),
                InfoRow(label: 'DoPP', value: data['dopp'] ?? ''),
                InfoRow(label: 'Date Of Retirement', value: data['retireDate'] ?? ''),
                InfoRow(label: 'Caste', value: data['caste'] ?? ''),
                InfoRow(label: 'Marital Status', value: data['marital'] ?? ''),
                InfoRow(label: 'Blood Group', value: data['blood'] ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Identity & Insurance Card
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Identity & Insurance / Policies',
                  icon: Icons.card_membership_outlined,
                ),
                const SizedBox(height: 12),
                InfoRow(label: 'Voter ID', value: data['voter'] ?? ''),
                InfoRow(label: 'UAN', value: data['uan'] ?? ''),
                InfoRow(label: 'Pension ID', value: data['pension'] ?? ''),
                InfoRow(label: 'Passport Number', value: data['passport'] ?? ''),
                InfoRow(label: 'PAN Number', value: data['pan'] ?? ''),
                InfoRow(label: 'Gratuity Number', value: data['gratuity'] ?? ''),
                InfoRow(label: 'FB', value: data['fb'] ?? ''),
                InfoRow(label: 'Driving License Number', value: data['dl'] ?? ''),
                InfoRow(label: 'Aadhar Number', value: data['aadhar'] ?? ''),
                InfoRow(label: 'PRAAN No.', value: data['praan'] ?? ''),
                InfoRow(label: 'PPO No.', value: data['ppo'] ?? ''),
                InfoRow(label: 'New Medical Policy', value: data['newMed'] ?? ''),
                InfoRow(label: 'Old Medical Policy', value: data['oldMed'] ?? ''),
                InfoRow(label: 'EPF Trust ID', value: data['epf'] ?? ''),
                InfoRow(label: 'Employee PF Number', value: data['pfNo'] ?? ''),
                InfoRow(label: 'Employee Pension Number', value: data['pensionPf'] ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Financial / Bank Details Card
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Financial & Bank Details',
                  icon: Icons.account_balance_outlined,
                ),
                const SizedBox(height: 12),
                InfoRow(label: 'Bank Key', value: data['bankKey'] ?? ''),
                InfoRow(label: 'Bank Account Number', value: data['bankAcc'] ?? ''),
                InfoRow(label: 'Spouse Account No.', value: data['spouseAcc'] ?? ''),
                InfoRow(label: 'Purchase Price', value: data['purchasePrice'] ?? ''),
                InfoRow(label: 'File Number', value: data['fileNo'] ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Nominees Card
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Nomination Details',
                  icon: Icons.assignment_turned_in_outlined,
                ),
                const SizedBox(height: 12),
                InfoRow(label: 'Nomination Gratuity', value: data['nomGratuity'] ?? ''),
                InfoRow(label: 'Relation (Gratuity)', value: data['nomGratuityRel'] ?? ''),
                InfoRow(label: 'Nomination PF', value: data['nomPf'] ?? ''),
                InfoRow(label: 'Relation (PF)', value: data['nomPfRel'] ?? ''),
                InfoRow(label: 'Nomination Pension', value: data['nomPension'] ?? ''),
                InfoRow(label: 'Relation (Pension)', value: data['nomPensionRel'] ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Family Members Details Card
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Family Members Details',
                  icon: Icons.family_restroom_outlined,
                ),
                const SizedBox(height: 12),
                InfoRow(label: 'Spouse Name', value: data['spouse'] ?? ''),
                InfoRow(label: 'Spouse DOB', value: data['spouseDob'] ?? ''),
                InfoRow(label: 'Child 1 Name', value: data['child1'] ?? ''),
                InfoRow(label: 'Child 1 DOB', value: data['childDob1'] ?? ''),
                InfoRow(label: 'Child 2 Name', value: data['child2'] ?? ''),
                InfoRow(label: 'Child 2 DOB', value: data['childDob2'] ?? ''),
                InfoRow(label: 'Child 3 Name', value: data['child3'] ?? ''),
                InfoRow(label: 'Child 3 DOB', value: data['childDob3'] ?? ''),
                InfoRow(label: 'Mother Name', value: data['mother'] ?? ''),
                InfoRow(label: 'Mother DOB', value: data['motherDob'] ?? ''),
                InfoRow(label: 'Father Name', value: data['father'] ?? ''),
                InfoRow(label: 'Father DOB', value: data['fatherDob'] ?? ''),
                InfoRow(label: 'Other Member', value: data['other'] ?? ''),
                InfoRow(label: 'Other DOB', value: data['otherDob'] ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Contact & Addresses Card
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Contact Details & Addresses',
                  icon: Icons.home_outlined,
                ),
                const SizedBox(height: 12),
                InfoRow(label: 'Mobile Number', value: data['mobile'] ?? ''),
                InfoRow(label: 'Email ID', value: data['email'] ?? ''),
                InfoRow(label: 'Permanent Address', value: data['permAddress'] ?? ''),
                InfoRow(label: 'Temporary Address', value: data['tempAddress'] ?? ''),
                InfoRow(label: 'Emergency Address', value: data['emergAddress'] ?? ''),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Separation Details Card
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Separation & Other Details',
                  icon: Icons.exit_to_app_outlined,
                ),
                const SizedBox(height: 12),
                InfoRow(label: 'Date of Separation', value: data['sepDate'] ?? ''),
                InfoRow(label: 'Reason of Separation', value: data['sepReason'] ?? ''),
                InfoRow(label: 'Hire Action Reason', value: data['hireReason'] ?? ''),
                InfoRow(label: 'Penalty Awarded', value: data['penalty'] ?? ''),
              ],
            ),
          ),
        ],
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
                          '${DateFormat('dd/MM/yyyy').format(leave.startDate)} – ${DateFormat('dd/MM/yyyy').format(leave.endDate)}',
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
                          '${DateFormat('dd/MM/yyyy').format(tour.startDate)} – ${DateFormat('dd/MM/yyyy').format(tour.endDate)}',
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
}
