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

class _LeaveScreenState extends State<LeaveScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();
      if (auth.user != null) {
        context.read<LeaveController>().fetchLeaves(auth.user!.employeeId);
        context.read<LeaveController>().fetchBalances(auth.user!.employeeId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar(
          title: 'Leave Management',
          showBack: Navigator.of(context).canPop(),
          // actions: [
          //   IconButton(
          //     icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          //     onPressed: () {
          //       final auth = context.read<AuthController>();
          //       if (auth.user != null) {
          //         context.read<LeaveController>().fetchLeaves(auth.user!.employeeId);
          //       }
          //     },
          //   ),
          // ],
        ),
        body: Column(
          children: [
            _buildTabBar(),
            const Expanded(
              child: TabBarView(
                children: [
                  LeaveStatusScreen(),
                  LeaveBalanceScreen(),
                  LeaveApplyScreen(),
                  LeaveEncashmentScreen(),
                  LeaveCalendarScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.backgroundSecondary,
      child: TabBar(
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
          Tab(text: 'Status'),
          Tab(text: 'Balance'),
          Tab(text: 'Apply'),
          Tab(text: 'Encashment'),
          Tab(text: 'Calendar'),
        ],
      ),
    );
  }
}
