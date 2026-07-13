// lib/modules/approval/screen/approval_screen.dart
// Multi-level approval screen for HOD, Reporting Officer, CMD

import 'package:employee_management/modules/auth/controller/auth_controller.dart';
import 'package:employee_management/modules/profile/controller/profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_colors.dart';
import '../../leave/controller/leave_controller.dart';
import '../../tour/controller/tour_controller.dart';
import '../../../model/leave_model.dart';
import '../../../model/tour_model.dart';
import '../../../widgets/app_widgets.dart';

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: 'Pending Approvals',
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.warning.withOpacity(0.2)),
            ),
           
          ),
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
              dividerColor: AppColors.cardBorder,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tabs: const [
                Tab(text: 'Leave Approvals'),
                Tab(text: 'Tour Approvals'),
                // Tab(text: 'System Approvals'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _LeaveApprovalList(),
                _TourApprovalList(),
                _SystemApprovalList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveApprovalList extends StatefulWidget {
  @override
  State<_LeaveApprovalList> createState() => _LeaveApprovalListState();
}

class _LeaveApprovalListState extends State<_LeaveApprovalList> {
  late List<LeaveModel> _pendingLeaves;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    final currentUser = auth.user;

    final allLeaves = [
      LeaveModel(
        id: 'l4',
        employeeId: '540 (Swapnil Kanthiram Manpe)',
        leaveType: 'Casual Leave',
        startDate: DateTime(2026, 7, 15),
        startTime: '09:00:00',
        endDate: DateTime(2026, 7, 16),
        endTime: '17:30:00',
        duration: 'Full-Day',
        status: 'Pending',
        reason: 'Personal home shifting work',
      ),
    ];

    final currentUserId = currentUser?.employeeId;
    _pendingLeaves = allLeaves.where((l) {
      final parts = l.employeeId.split(' ');
      final empId = parts.first.replaceAll('(', '').replaceAll(')', '').trim();
      final empMap = ProfileController.rawEmployees.firstWhere(
        (e) => e['empNo'] == empId,
        orElse: () => <String, dynamic>{},
      );
      if (empMap.isEmpty) return false;
      final ro = empMap['reportingOfficer'] ?? '';
      final ro1 = empMap['reportingOfficer1'] ?? '';
      return ro == currentUserId || ro1 == currentUserId;
    }).toList();
  }

  void _handleAction(String id, String action) {
    setState(() {
      _pendingLeaves.removeWhere((l) => l.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Leave request $action successfully!'),
      backgroundColor: action == 'approved' ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingLeaves.isEmpty) {
      return const EmptyState(
        icon: Icons.done_all_rounded,
        title: 'All Clear!',
        subtitle: 'No pending leave approvals at this time.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingLeaves.length,
      itemBuilder: (context, index) {
        return _LeaveApprovalCard(
          leave: _pendingLeaves[index],
          onApprove: (id) => _handleAction(id, 'approved'),
          onReject: (id) => _handleAction(id, 'rejected'),
        );
      },
    );
  }
}

class _LeaveApprovalCard extends StatelessWidget {
  final LeaveModel leave;
  final Function(String) onApprove;
  final Function(String) onReject;

  const _LeaveApprovalCard({
    required this.leave,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LeaveTypeBadge(type: leave.leaveType),
              const Spacer(),
              StatusBadge(status: leave.status),
            ],
          ),
          const SizedBox(height: 12),
          InfoRow(label: 'Employee', value: leave.employeeId),
          InfoRow(
            label: 'Duration',
            value: '${DateFormat('dd-MM-yyyy').format(leave.startDate)} – ${DateFormat('dd-MM-yyyy').format(leave.endDate)}',
          ),
          InfoRow(label: 'Type', value: leave.duration),
          if (leave.reason != null) InfoRow(label: 'Reason', value: leave.reason!),
          const SizedBox(height: 14),
          const Divider(color: AppColors.cardBorder),
          const SizedBox(height: 10),
          const TextField(
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Add remarks (optional)...',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ApproveBtn(
                  label: 'Approve',
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                  onTap: () => onApprove(leave.id),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ApproveBtn(
                  label: 'Reject',
                  color: AppColors.error,
                  icon: Icons.cancel_outlined,
                  onTap: () => onReject(leave.id),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TourApprovalList extends StatefulWidget {
  @override
  State<_TourApprovalList> createState() => _TourApprovalListState();
}

class _TourApprovalListState extends State<_TourApprovalList> {
  late List<TourModel> _pendingTours;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    final currentUser = auth.user;

    final allTours = [
      TourModel(
        id: 't1',
        employeeId: '540 (Swapnil Kanthiram Manpe)',
        tourType: 'Official Tour',
        destination: 'Mumbai',
        startDate: DateTime(2026, 7, 15),
        endDate: DateTime(2026, 7, 18),
        travelPurpose: 'System Audit at Regional Office',
        transportMode: 'Air Travel',
        status: 'Pending',
      ),
      TourModel(
        id: 't2',
        employeeId: '4428 (B.C.N. Gautam)',
        tourType: 'Official Tour',
        destination: 'New Delhi',
        startDate: DateTime(2026, 7, 22),
        endDate: DateTime(2026, 7, 25),
        travelPurpose: 'Joint System Integration Meeting',
        transportMode: 'Air Travel',
        status: 'Pending',
      ),
      TourModel(
        id: 't3',
        employeeId: '4410 (Nitin Kajarekar)',
        tourType: 'Official Tour',
        destination: 'Kolkata',
        startDate: DateTime(2026, 7, 28),
        endDate: DateTime(2026, 7, 31),
        travelPurpose: 'Strategic Financial Audit',
        transportMode: 'Air Travel',
        status: 'Pending',
      ),
      TourModel(
        id: 't4',
        employeeId: '17110 (Sameer Banerjee)',
        tourType: 'Official Tour',
        destination: 'Pune',
        startDate: DateTime(2026, 8, 2),
        endDate: DateTime(2026, 8, 5),
        travelPurpose: 'Tax compliance meeting',
        transportMode: 'Train',
        status: 'Pending',
      ),
    ];

    final currentUserId = currentUser?.employeeId;
    _pendingTours = allTours.where((t) {
      final parts = t.employeeId.split(' ');
      final empId = parts.first.replaceAll('(', '').replaceAll(')', '').trim();
      final empMap = ProfileController.rawEmployees.firstWhere(
        (e) => e['empNo'] == empId,
        orElse: () => <String, dynamic>{},
      );
      if (empMap.isEmpty) return false;
      final ro = empMap['reportingOfficer'] ?? '';
      final ro1 = empMap['reportingOfficer1'] ?? '';
      return ro == currentUserId || ro1 == currentUserId;
    }).toList();
  }

  void _handleAction(String id, String action) {
    setState(() {
      _pendingTours.removeWhere((t) => t.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Tour request $action successfully!'),
      backgroundColor: action == 'approved' ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingTours.isEmpty) {
      return const EmptyState(
        icon: Icons.done_all_rounded,
        title: 'All Clear!',
        subtitle: 'No pending tour approvals at this time.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingTours.length,
      itemBuilder: (context, index) {
        return _TourApprovalCard(
          tour: _pendingTours[index],
          onApprove: (id) => _handleAction(id, 'approved'),
          onReject: (id) => _handleAction(id, 'rejected'),
        );
      },
    );
  }
}

class _TourApprovalCard extends StatelessWidget {
  final TourModel tour;
  final Function(String) onApprove;
  final Function(String) onReject;

  const _TourApprovalCard({
    required this.tour,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Text(tour.tourType, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              StatusBadge(status: tour.status),
            ],
          ),
          const SizedBox(height: 12),
          InfoRow(label: 'Employee', value: tour.employeeId),
          InfoRow(label: 'Destination', value: tour.destination),
          InfoRow(
            label: 'Duration',
            value: '${DateFormat('dd-MM-yyyy').format(tour.startDate)} – ${DateFormat('dd-MM-yyyy').format(tour.endDate)}',
          ),
          InfoRow(label: 'Purpose', value: tour.travelPurpose),
          InfoRow(label: 'Transport', value: tour.transportMode),
          const SizedBox(height: 14),
          const Divider(color: AppColors.cardBorder),
          const SizedBox(height: 10),
          const TextField(
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Add remarks (optional)...',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _ApproveBtn(
                label: 'Approve', color: AppColors.success, icon: Icons.check_circle_outline,
                onTap: () => onApprove(tour.id),
              )),
              const SizedBox(width: 12),
              Expanded(child: _ApproveBtn(
                label: 'Reject', color: AppColors.error, icon: Icons.cancel_outlined,
                onTap: () => onReject(tour.id),
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApproveBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ApproveBtn({required this.label, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _SystemApprovalList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row(
              //   children: [
              //     // Container(
              //     //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              //     //   decoration: BoxDecoration(
              //     //     color: AppColors.error.withOpacity(0.08),
              //     //     borderRadius: BorderRadius.circular(6),
              //     //     border: Border.all(color: AppColors.error.withOpacity(0.2)),
              //     //   ),
              //     //   child: const Text('Password Change Required',
              //     //       style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
              //     // ),
              //     const Spacer(),
              //     const StatusBadge(status: 'Pending'),
              //   ],
              // ),
              const SizedBox(height: 12),
              const InfoRow(label: 'Employee', value: 'Nitin Kajarekar (283)'),
              const InfoRow(label: 'Reason', value: 'Compulsory system reset requirement'),
              const SizedBox(height: 14),
              const Divider(color: AppColors.cardBorder),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ApproveBtn(
                      label: 'Open Change Dialog',
                      color: AppColors.primary,
                      icon: Icons.security_rounded,
                      onTap: () {
                        showDialog(
                          context: context,
                          barrierDismissible: true,
                          builder: (ctx) => CompulsoryPasswordChangeDialog(
                            dismissible: true,
                            onSuccess: () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('System approval completed!'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ));
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
