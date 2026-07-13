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
import '../../tour/controller/tour_controller.dart';
import '../../../model/tour_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _earnedLeaveDate = DateTime(2026, 1, 1);
  DateTime _casualLeaveDate = DateTime(2026, 1, 1);
  DateTime _hplDate = DateTime(2026, 1, 1);
  DateTime _optionalLeaveDate = DateTime(2026, 1, 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();
      if (auth.user != null) {
        context
            .read<ProfileController>()
            .fetchEmployeeProfile(auth.user!.employeeId);
        context.read<LeaveController>().fetchLeaves(auth.user!.employeeId);
        context.read<LeaveController>().fetchBalances(auth.user!.employeeId);
        context.read<TourController>().fetchTours(auth.user!.employeeId);
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
              SliverToBoxAdapter(child: _buildQuickStats(context)),
              SliverToBoxAdapter(child: _buildModuleGrid(context)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MediaQuery.of(context).size.width < 800
                      ? Column(
                          children: [
                            _buildRecentLeaves(context),
                            // const SizedBox(height: 12),
                            _buildRecentTours(context),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildRecentLeaves(context),
                            ),
                            // const SizedBox(width: 12),
                            Expanded(
                              child: _buildRecentTours(context),
                            ),
                          ],
                        ),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 24),
              ),
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
      final parts = clean.split('-');
      if (parts.length == 3) {
        String day = parts[0].padLeft(2, '0');
        String month = parts[1].padLeft(2, '0');
        String year = parts[2];
        if (day.length > 2) {
          final temp = day;
          day = year.padLeft(2, '0');
          year = temp;
        }
        return '$day/$month/$year';
      }
    } catch (_) {}
    return dateStr.replaceAll('-', '/');
  }

  Widget _buildQuickStats(BuildContext context) {
    final leaveController = context.watch<LeaveController>();
    final width = MediaQuery.of(context).size.width;
    double baseEl = 185.50;
    double baseCl = 10.50;
    double baseHpl = 107.00;
    double baseOp = 2.00;

    double baseElEnt = 215.50;
    double baseClEnt = 12.00;
    double baseHplEnt = 107.00;
    double baseOpEnt = 2.00;

    // Retrieve default base balances from controller
    for (var b in leaveController.balances) {
      final name = b.timeAccount.toLowerCase();
      if (name.contains('earned')) {
        baseEl = b.entitlementMinusPlanned;
        baseElEnt = b.entitlement;
      } else if (name.contains('casual')) {
        baseCl = b.entitlementMinusPlanned;
        baseClEnt = b.entitlement;
      } else if (name.contains('hpl')) {
        baseHpl = b.entitlementMinusPlanned;
        baseHplEnt = b.entitlement;
      } else if (name.contains('optional')) {
        baseOp = b.entitlementMinusPlanned;
        baseOpEnt = b.entitlement;
      }
    }

    int getDayOfYear(DateTime date) {
      return date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    }

    double calculateEarnedLeave() {
      final int year = _earnedLeaveDate.year;
      double val = baseEl;
      if (year == 2025) {
        val = 120.0;
      } else if (year == 2027) {
        val = 245.50;
      } else if (year > 2027) {
        val = 245.50 + (year - 2027) * 30.0;
      }
      return val;
    }

    double calculateEarnedLeaveEnt() {
      final int year = _earnedLeaveDate.year;
      double val = baseElEnt;
      if (year == 2025) {
        val = 150.0;
      } else if (year == 2027) {
        val = 275.50;
      } else if (year > 2027) {
        val = 275.50 + (year - 2027) * 30.0;
      }
      return val;
    }

    double calculateCasualLeave() {
      final int year = _casualLeaveDate.year;
      double val = baseCl;
      if (year == 2025) {
        val = 8.0;
      } else if (year >= 2027) {
        val = 12.0;
      }
      return val;
    }

    double calculateCasualLeaveEnt() {
      final int year = _casualLeaveDate.year;
      double val = baseClEnt;
      if (year == 2025) {
        val = 10.0;
      } else if (year >= 2027) {
        val = 12.0;
      }
      return val;
    }

    double calculateHPL() {
      final int year = _hplDate.year;
      double val = baseHpl;
      if (year == 2025) {
        val = 90.0;
      } else if (year == 2027) {
        val = 127.0;
      } else if (year > 2027) {
        val = 127.0 + (year - 2027) * 20.0;
      }
      return val;
    }

    double calculateHplEnt() {
      final int year = _hplDate.year;
      double val = baseHplEnt;
      if (year == 2025) {
        val = 110.0;
      } else if (year == 2027) {
        val = 127.0;
      } else if (year > 2027) {
        val = 127.0 + (year - 2027) * 20.0;
      }
      return val;
    }

    double calculateOptionalLeave() {
      final int year = _optionalLeaveDate.year;
      double val = baseOp;
      if (year == 2025) {
        val = 1.0;
      } else if (year >= 2027) {
        val = 2.0;
      }
      if (_optionalLeaveDate.month > 6) {
        val = (val - 1.0).clamp(0.0, 2.0);
      }
      return val;
    }

    double calculateOptionalLeaveEnt() {
      final int year = _optionalLeaveDate.year;
      double val = baseOpEnt;
      if (year == 2025) {
        val = 2.0;
      } else if (year >= 2027) {
        val = 2.0;
      }
      return val;
    }

    final double el = calculateEarnedLeave();
    final double cl = calculateCasualLeave();
    final double hpl = calculateHPL();
    final double op = calculateOptionalLeave();

    final double elEnt = calculateEarnedLeaveEnt();
    final double clEnt = calculateCasualLeaveEnt();
    final double hplEnt = calculateHplEnt();
    final double opEnt = calculateOptionalLeaveEnt();

    Widget buildCalendarPicker({
      required DateTime selectedDate,
      required ValueChanged<DateTime> onDateSelected,
    }) {
      return InkWell(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: selectedDate,
            firstDate: DateTime(2025, 1, 1),
            lastDate: DateTime(2030, 12, 31),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    onSurface: AppColors.textPrimary,
                  ),
                  dialogBackgroundColor: AppColors.backgroundSecondary,
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            onDateSelected(picked);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('dd-MM-yyyy').format(selectedDate),
                style: const TextStyle(fontSize: 10, color: AppColors.textHint, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 10),
            ],
          ),
        ),
      );
    }

    final cards = [
      _StatCard(
        title: 'Earned Leave',
        value: el % 1 == 0 ? '${el.toInt()}' : el.toStringAsFixed(1),
        entitlement: elEnt % 1 == 0 ? '${elEnt.toInt()}' : elEnt.toStringAsFixed(1),
        subtitleWidget: buildCalendarPicker(
          selectedDate: _earnedLeaveDate,
          onDateSelected: (date) {
            setState(() {
              _earnedLeaveDate = date;
            });
          },
        ),
        icon: Icons.event_available_rounded,
        color: AppColors.primary,
      ),
      _StatCard(
        title: 'Casual Leave',
        value: cl % 1 == 0 ? '${cl.toInt()}' : cl.toStringAsFixed(1),
        entitlement: clEnt % 1 == 0 ? '${clEnt.toInt()}' : clEnt.toStringAsFixed(1),
        subtitleWidget: buildCalendarPicker(
          selectedDate: _casualLeaveDate,
          onDateSelected: (date) {
            setState(() {
              _casualLeaveDate = date;
            });
          },
        ),
        icon: Icons.date_range_rounded,
        color: AppColors.warning,
      ),
      _StatCard(
        title: 'Half Pay Leave',
        value: hpl % 1 == 0 ? '${hpl.toInt()}' : hpl.toStringAsFixed(1),
        entitlement: hplEnt % 1 == 0 ? '${hplEnt.toInt()}' : hplEnt.toStringAsFixed(1),
        subtitleWidget: buildCalendarPicker(
          selectedDate: _hplDate,
          onDateSelected: (date) {
            setState(() {
              _hplDate = date;
            });
          },
        ),
        icon: Icons.hourglass_bottom_rounded,
        color: AppColors.success,
      ),
      _StatCard(
        title: 'Optional Leave',
        value: op % 1 == 0 ? '${op.toInt()}' : op.toStringAsFixed(1),
        entitlement: opEnt % 1 == 0 ? '${opEnt.toInt()}' : opEnt.toStringAsFixed(1),
        subtitleWidget: buildCalendarPicker(
          selectedDate: _optionalLeaveDate,
          onDateSelected: (date) {
            setState(() {
              _optionalLeaveDate = date;
            });
          },
        ),
        icon: Icons.celebration_rounded,
        color: const Color(0xFF8B5CF6),
      ),
    ];


    Widget buildCardsLayout() {
      if (width > 1200) {
        return Row(
          children: cards.map((c) => Expanded(child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: c,
          ))).toList(),
        );
      } else if (width > 700) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: cards[0],
                )),
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: cards[1],
                )),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: cards[2],
                )),
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: cards[3],
                )),
              ],
            ),
          ],
        );
      }

      return Column(
        children: cards.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: c,
        )).toList(),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leave Balance',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          buildCardsLayout(),
        ],
      ),
    );
  }

  Widget _buildModuleGrid(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWeb = width > 800;

    final navBarController = context.read<BottomNavBarController>();
    final user = context.watch<AuthController>().user;
    final loggedInEmpNo = user?.employeeId;
    final isReportingOfficer = ProfileController.rawEmployees.any((emp) =>
        emp['reportingOfficer'] == loggedInEmpNo ||
        emp['reportingOfficer1'] == loggedInEmpNo);

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
      if (isReportingOfficer)
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
                MaterialPageRoute(
                    builder: (_) => const EmployeeDirectoryScreen()),
              );
            }
          },
        ),
      if (isReportingOfficer)
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

    final int crossAxisCount;
    final double childAspectRatio;

    if (width > 1200) {
      crossAxisCount = 8;
      childAspectRatio = 1.1;
    } else if (width > 700) {
      crossAxisCount = 4;
      childAspectRatio = 1.25;
    } else {
      crossAxisCount = 3;
      childAspectRatio = 0.95;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                        child:
                            Icon(m.icon, color: m.color, size: isWeb ? 18 : 20),
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
    final recentLeaves = leaveController.leaves;
    final double width = MediaQuery.of(context).size.width;
    final bool isWeb = width > 800;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leaves Till Date',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (recentLeaves.isEmpty)
            const GlassCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No leave records found',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ),
            ),
          // else if (isWeb)
          //   Wrap(
          //     spacing: 12,
          //     runSpacing: 12,
          //     children: recentLeaves.map((leave) {
          //       return SizedBox(
          //         width: width > 1200 ? (width - 80) / 3 : (width - 60) / 2,
          //         child: _LeaveListTile(leave: leave),
          //       );
          //     }).toList(),
          //   )
          // else
          Column(
            children: recentLeaves
                .map((leave) => _LeaveListTile(leave: leave))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTours(BuildContext context) {
    final tourController = context.watch<TourController>();
    final tours = tourController.tours;
    final double width = MediaQuery.of(context).size.width;
    final bool isWeb = width > 800;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tours Till Date',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (tours.isEmpty)
            const GlassCard(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No tour records found',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ),
            ),
          // else if (isWeb)
          //   Wrap(
          //     spacing: 12,
          //     runSpacing: 12,
          //     children: tours.map((tour) {
          //       return SizedBox(
          //         width: width > 1200 ? (width - 80) / 3 : (width - 60) / 2,
          //         child: _TourListTile(tour: tour),
          //       );
          //     }).toList(),
          //   )
          // else
          Column(
            children: tours.map((tour) => _TourListTile(tour: tour)).toList(),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String entitlement;
  final Widget subtitleWidget;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.entitlement,
    required this.subtitleWidget,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isWeb = width > 800;

    Widget buildValueRow(double fontSize, double entFontSize) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '/ $entitlement Ent.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: entFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: isWeb
          ? Row(
              children: [
                Icon(icon, color: color, size: 50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      buildValueRow(20, 11),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitleWidget,
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 40),
                const SizedBox(height: 8),
                buildValueRow(20, 11),
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
                subtitleWidget,
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
                    '${DateFormat('dd-MM-yyyy').format(leave.startDate)} to ${DateFormat('dd-MM-yyyy').format(leave.endDate)}',
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

class _TourListTile extends StatelessWidget {
  final TourModel tour;
  const _TourListTile({required this.tour});

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
                color: const Color(0xFF8B5CF6).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.flight_takeoff_rounded,
                color: Color(0xFF8B5CF6),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${tour.tourType} to ${tour.destination}',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('dd-MM-yyyy').format(tour.startDate)} to ${DateFormat('dd-MM-yyyy').format(tour.endDate)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge(status: tour.status),
          ],
        ),
      ),
    );
  }
}
