import 'package:employee_management/modules/bottom_nav_bar/controller/bottom_nav_bar_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_widgets.dart';
import '../../auth/controller/auth_controller.dart';
import '../../leave/controller/leave_controller.dart';
import '../../notifications/controller/notification_controller.dart';
import '../../notifications/screen/notifications_screen.dart';
import '../../leave/screen/leave_screen.dart';
import '../../tour/screen/tour_screen.dart';
import '../../payslip/screen/payslip_screen.dart';
import '../../holiday/screen/holiday_screen.dart';
import '../../approval/screen/approval_screen.dart';
import '../../profile/screen/profile_screen.dart';
import '../../profile/screen/employee_directory_screen.dart';
import '../../../model/leave_model.dart';
import '../../profile/controller/profile_controller.dart';
import '../../../model/employee_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();
      if (auth.user != null) {
        context.read<ProfileController>().fetchEmployeeProfile(auth.user!.employeeId);
        context.read<LeaveController>().fetchLeaves(auth.user!.employeeId);
        context.read<LeaveController>().fetchBalances(auth.user!.employeeId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: GradientBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: _buildEmployeeDetailsCard(context)),
              SliverToBoxAdapter(child: _buildQuickStats(context)),
              SliverToBoxAdapter(child: _buildModuleGrid(context)),
              SliverToBoxAdapter(child: _buildRecentLeaves(context)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final notifController = context.watch<NotificationController>();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.name ?? 'Employee',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${user?.designation ?? ''} · ${user?.department ?? ''}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
            child: Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_outlined,
                    color: AppColors.primary,
                  ),
                ),
                if (notifController.unreadCount > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${notifController.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'N/A';
    try {
      final clean = dateStr.replaceAll('/', '-');
      final parsed = DateFormat('dd-MM-yyyy').parse(clean);
      return DateFormat('dd-MM-yyyy').format(parsed);
    } catch (_) {
      final parts = dateStr.split(RegExp(r'[-/]'));
      if (parts.length == 3) {
        String day = parts[0].padLeft(2, '0');
        String month = parts[1].padLeft(2, '0');
        String year = parts[2];
        if (day.length > 2) {
          final temp = day;
          day = year.padLeft(2, '0');
          year = temp;
        }
        return '$day-$month-$year';
      }
      return dateStr;
    }
  }

  Widget _buildEmployeeDetailsCard(BuildContext context) {
    final profileController = context.watch<ProfileController>();
    final employee = profileController.employee;

    if (profileController.isLoading || employee == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: GlassCard(
          child: const Center(
            child: SizedBox(
              height: 40,
              width: 40,
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Employee Information',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20, color: AppColors.cardBorder),
            LayoutBuilder(
              builder: (context, constraints) {
                final double itemWidth = constraints.maxWidth > 600
                    ? (constraints.maxWidth - 32) / 3
                    : (constraints.maxWidth - 16) / 2;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildInfoDetail('Employee No.', employee.employeeId, itemWidth),
                    _buildInfoDetail('Present Grade', employee.presentGrade, itemWidth),
                    _buildInfoDetail('Appointment Type', employee.appointmentType, itemWidth),
                    _buildInfoDetail('Place of Posting', employee.presentPlaceOfPosting, itemWidth),
                    _buildInfoDetail('Last Promotion Date', _formatDate(employee.lastPromotionDate), itemWidth),
                    _buildInfoDetail('Date of Joining', _formatDate(employee.joinDate), itemWidth),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoDetail(String label, String value, double width) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? 'N/A' : value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context) {
    final leaveController = context.watch<LeaveController>();
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 800;

    double el = 185.50;
    double cl = 10.50;
    double hpl = 107.00;
    double op = 2.00;

    String elDates = '';
    String clDates = '';
    String hplDates = '';
    String opDates = '';

    for (var b in leaveController.balances) {
      final name = b.timeAccount.toLowerCase();
      final dateRange = '${DateFormat('dd/MM/yyyy').format(b.deductionFrom)} to ${DateFormat('dd/MM/yyyy').format(b.deductionTo)}';
      if (name.contains('earned')) {
        el = b.entitlementMinusPlanned;
        elDates = dateRange;
      } else if (name.contains('casual')) {
        cl = b.entitlementMinusPlanned;
        clDates = dateRange;
      } else if (name.contains('hpl')) {
        hpl = b.entitlementMinusPlanned;
        hplDates = dateRange;
      } else if (name.contains('optional')) {
        op = b.entitlementMinusPlanned;
        opDates = dateRange;
      }
    }

    final cards = [
      _StatCard(
        title: 'Earned Leave',
        value: el % 1 == 0 ? '${el.toInt()}' : '$el',
        subtitle: elDates.isNotEmpty ? 'EL Balance\n($elDates)' : 'EL Balance',
        icon: Icons.event_available_rounded,
        color: AppColors.primary,
      ),
      _StatCard(
        title: 'Casual Leave',
        value: cl % 1 == 0 ? '${cl.toInt()}' : '$cl',
        subtitle: clDates.isNotEmpty ? 'CL Balance\n($clDates)' : 'CL Balance',
        icon: Icons.date_range_rounded,
        color: AppColors.warning,
      ),
      _StatCard(
        title: 'Half Pay Leave',
        value: hpl % 1 == 0 ? '${hpl.toInt()}' : '$hpl',
        subtitle: hplDates.isNotEmpty ? 'HPL Balance\n($hplDates)' : 'HPL Balance',
        icon: Icons.hourglass_bottom_rounded,
        color: AppColors.success,
      ),
      _StatCard(
        title: 'Optional Leave',
        value: op % 1 == 0 ? '${op.toInt()}' : '$op',
        subtitle: opDates.isNotEmpty ? 'OP Balance\n($opDates)' : 'OP Balance',
        icon: Icons.celebration_rounded,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    if (isWeb) {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Row(
          children: cards.map((c) => Expanded(child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: c,
          ))).toList(),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.25,
        children: cards,
      ),
    );
  }

  Widget _buildModuleGrid(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 800;

    final navBarController = context.read<BottomNavBarController>();
    final user = context.watch<AuthController>().user;
    final isEmployee = user?.role == 'Employee' || (user?.role != 'RO' && user?.role != 'RO1');

    final modules = [
      _ModuleItem(
        title: 'Leave',
        subtitle: 'Apply & Track',
        icon: Icons.event_note_rounded,
        color: AppColors.primary,
        onTap: () {
          if (isWeb) {
            navBarController.setSelectedIndex(1);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaveScreen()),
            );
          }
        },
      ),
      _ModuleItem(
        title: 'Tour',
        subtitle: 'Travel Requests',
        icon: Icons.flight_takeoff_rounded,
        color: const Color(0xFF06B6D4),
        onTap: () {
          if (isWeb) {
            navBarController.setSelectedIndex(2);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TourScreen()),
            );
          }
        },
      ),
      _ModuleItem(
        title: 'Payslip',
        subtitle: 'View & Download',
        icon: Icons.receipt_long_rounded,
        color: AppColors.success,
        onTap: () {
          if (isWeb) {
            navBarController.setSelectedIndex(5);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PayslipScreen()),
            );
          }
        },
      ),
      _ModuleItem(
        title: 'Holiday',
        subtitle: 'View Calendar',
        icon: Icons.celebration_rounded,
        color: AppColors.warning,
        onTap: () {
          if (isWeb) {
            navBarController.setSelectedIndex(6);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HolidayScreen()),
            );
          }
        },
      ),
      if (!isEmployee)
        _ModuleItem(
          title: 'Directory',
          subtitle: 'Employee List',
          icon: Icons.people_rounded,
          color: const Color(0xFF0F766E),
          onTap: () {
            if (isWeb) {
              navBarController.setSelectedIndex(4);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EmployeeDirectoryScreen()),
              );
            }
          },
        ),
      if (!isEmployee)
        _ModuleItem(
          title: 'Approvals',
          subtitle: 'Pending Actions',
          icon: Icons.approval_rounded,
          color: const Color(0xFF8B5CF6),
          onTap: () {
            if (isWeb) {
              navBarController.setSelectedIndex(7);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ApprovalScreen()),
              );
            }
          },
        ),
      _ModuleItem(
        title: 'Profile',
        subtitle: 'My Account',
        icon: Icons.person_rounded,
        color: const Color(0xFFEC4899),
        onTap: () {
          if (isWeb) {
            navBarController.setSelectedIndex(3);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          }
        },
      ),
      _ModuleItem(
        title: 'Alerts',
        subtitle: 'Notifications',
        icon: Icons.notifications_rounded,
        color: const Color(0xFFF59E0B),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
      ),
    ];

    final int crossAxisCount = isWeb ? 8 : 3;
    final double childAspectRatio = isWeb ? 1.05 : 0.95;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Access',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final m = modules[index];
              return GestureDetector(
                onTap: m.onTap,
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: isWeb ? 36 : 42,
                        height: isWeb ? 36 : 42,
                        decoration: BoxDecoration(
                          color: m.color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: m.color.withOpacity(0.15)),
                        ),
                        child: Icon(m.icon, color: m.color, size: isWeb ? 18 : 20),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        m.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        m.subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLeaves(BuildContext context) {
    final leaveController = context.watch<LeaveController>();
    final recentLeaves = leaveController.leaves.take(3).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Leaves',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LeaveScreen()),
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (recentLeaves.isEmpty)
            const GlassCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No recent leave records',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            ...recentLeaves.map((leave) => _LeaveListTile(leave: leave)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 9,
              ),
            ),
          ],
        ),
      );
    
  }
}

class _ModuleItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ModuleItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _LeaveListTile extends StatelessWidget {
  final LeaveModel leave;
  const _LeaveListTile({required this.leave});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.event_note_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leave.leaveType,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('dd/MM/yyyy').format(leave.startDate)} – ${DateFormat('dd/MM/yyyy').format(leave.endDate)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge(status: leave.status),
          ],
        ),
      ),
    );
  }
}
