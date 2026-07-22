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
import 'approval_history_screen.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.primary),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ApprovalHistoryScreen(),
                ),
              );
            },
            tooltip: 'Approval History',
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
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _LeaveApprovalList(),
                _TourApprovalList(),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaveController>().fetchPendingApprovals();
    });
  }

  void _handleAction(String id, String action, String remarks) async {
    final controller = context.read<LeaveController>();
    bool success = false;
    if (action == 'approved') {
      success = await controller.approveLeave(id, remarks);
    } else {
      success = await controller.rejectLeave(id, remarks);
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Leave request $action successfully!' : 'Failed to process request.'),
        backgroundColor: success && action == 'approved' ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaveController = context.watch<LeaveController>();
    final leavesToShow = leaveController.pendingApprovals;

    if (leaveController.status == LeaveStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (leavesToShow.isEmpty) {
      return const EmptyState(
        icon: Icons.done_all_rounded,
        title: 'All Clear!',
        subtitle: 'No pending leave approvals at this time.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: leavesToShow.length,
      itemBuilder: (context, index) {
        return _LeaveApprovalCard(
          leave: leavesToShow[index],
          onApprove: (id, remarks) => _handleAction(id, 'approved', remarks),
          onReject: (id, remarks) => _handleAction(id, 'rejected', remarks),
        );
      },
    );
  }
}

class _LeaveApprovalCard extends StatefulWidget {
  final LeaveModel leave;
  final Function(String, String) onApprove;
  final Function(String, String) onReject;

  const _LeaveApprovalCard({
    required this.leave,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_LeaveApprovalCard> createState() => _LeaveApprovalCardState();
}

class _LeaveApprovalCardState extends State<_LeaveApprovalCard> {
  late TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

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
              LeaveTypeBadge(type: widget.leave.leaveType),
              const Spacer(),
              StatusBadge(status: widget.leave.status),
            ],
          ),
          const SizedBox(height: 12),
          InfoRow(label: 'Employee', value: widget.leave.employeeId),
          InfoRow(
            label: 'Duration',
            value: '${DateFormat('dd-MM-yyyy').format(widget.leave.startDate)} – ${DateFormat('dd-MM-yyyy').format(widget.leave.endDate)}',
          ),
          InfoRow(label: 'Type', value: widget.leave.duration),
          if (widget.leave.reason != null) InfoRow(label: 'Reason', value: widget.leave.reason!),
          const SizedBox(height: 14),
          const Divider(color: AppColors.cardBorder),
          const SizedBox(height: 10),
          TextField(
            controller: _remarksController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
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
                  onTap: () => widget.onApprove(widget.leave.id, _remarksController.text),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ApproveBtn(
                  label: 'Reject',
                  color: AppColors.error,
                  icon: Icons.cancel_outlined,
                  onTap: () => widget.onReject(widget.leave.id, _remarksController.text),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TourController>().fetchPendingApprovals();
    });
  }

  void _handleAction(String id, String action, String remarks) async {
    final controller = context.read<TourController>();
    bool success = false;
    if (action == 'approved') {
      success = await controller.approveTour(id, remarks);
    } else {
      success = await controller.rejectTour(id, remarks);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Tour request $action successfully!' : 'Failed to process request.'),
        backgroundColor: success && action == 'approved' ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      if (success) {
        controller.fetchPendingApprovals();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tourController = context.watch<TourController>();
    final toursToShow = tourController.pendingApprovals;

    if (tourController.status == TourStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (toursToShow.isEmpty) {
      return const EmptyState(
        icon: Icons.done_all_rounded,
        title: 'All Clear!',
        subtitle: 'No pending tour approvals at this time.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: toursToShow.length,
      itemBuilder: (context, index) {
        return _TourApprovalCard(
          tour: toursToShow[index],
          onApprove: (id, remarks) => _handleAction(id, 'approved', remarks),
          onReject: (id, remarks) => _handleAction(id, 'rejected', remarks),
        );
      },
    );
  }
}

class _TourApprovalCard extends StatefulWidget {
  final TourModel tour;
  final Function(String, String) onApprove;
  final Function(String, String) onReject;

  const _TourApprovalCard({
    required this.tour,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_TourApprovalCard> createState() => _TourApprovalCardState();
}

class _TourApprovalCardState extends State<_TourApprovalCard> {
  late TextEditingController _remarksController;

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

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
                child: Text(widget.tour.tourType, style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              StatusBadge(status: widget.tour.status),
            ],
          ),
          const SizedBox(height: 12),
          InfoRow(label: 'Employee', value: widget.tour.employeeId),
          InfoRow(label: 'Destination', value: widget.tour.destination),
          InfoRow(
            label: 'Duration',
            value: '${DateFormat('dd-MM-yyyy').format(widget.tour.startDate)} – ${DateFormat('dd-MM-yyyy').format(widget.tour.endDate)}',
          ),
          InfoRow(label: 'Purpose', value: widget.tour.travelPurpose),
          InfoRow(label: 'Transport', value: widget.tour.transportMode),
          const SizedBox(height: 14),
          const Divider(color: AppColors.cardBorder),
          const SizedBox(height: 10),
          TextField(
            controller: _remarksController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
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
                onTap: () => widget.onApprove(widget.tour.id, _remarksController.text),
              )),
              const SizedBox(width: 12),
              Expanded(child: _ApproveBtn(
                label: 'Reject', color: AppColors.error, icon: Icons.cancel_outlined,
                onTap: () => widget.onReject(widget.tour.id, _remarksController.text),
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

// _SystemApprovalList removed.
