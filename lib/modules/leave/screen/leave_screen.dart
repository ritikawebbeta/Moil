// lib/modules/leave/screen/leave_screen.dart
// Main Leave screen with 4 tabs: Status, Balance, Apply, Calendar

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_colors.dart';
import '../../auth/controller/auth_controller.dart';
import '../../leave/controller/leave_controller.dart';
import '../../../widgets/app_widgets.dart';
import 'leave_status_screen.dart';
import 'leave_balance_screen.dart';
import 'leave_apply_screen.dart';
import 'leave_encashment_screen.dart';
import 'leave_calendar_screen.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();
      if (auth.user != null) {
        context.read<LeaveController>().fetchLeaves(auth.user!.employeeId);
        context.read<LeaveController>().fetchBalances(auth.user!.employeeId);
      }

      final leaveController = context.read<LeaveController>();
      _tabController.index = leaveController.activeTabIndex;
      leaveController.addListener(_onLeaveControllerChanged);
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    try {
      context.read<LeaveController>().removeListener(_onLeaveControllerChanged);
    } catch (_) {}
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    final controller = context.read<LeaveController>();
    if (controller.activeTabIndex != _tabController.index) {
      controller.setActiveTabIndex(_tabController.index);
    }
  }

  void _onLeaveControllerChanged() {
    final controller = context.read<LeaveController>();
    if (controller.activeTabIndex != _tabController.index) {
      _tabController.animateTo(controller.activeTabIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Leave Management',
        showBack: Navigator.of(context).canPop(),
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                LeaveStatusScreen(),
                LeaveApplyScreen(),
                LeaveEncashmentScreen(),
                LeaveCalendarScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.backgroundSecondary,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        dividerColor: AppColors.cardBorder,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tabs: const [
          Tab(text: 'Leave Status'),
          Tab(text: 'Quarterly Leave Apply'),
          Tab(text: 'Leave Encashment'),
          Tab(text: 'Leave Calendar'),
        ],
      ),
    );
  }
}
