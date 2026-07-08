// lib/modules/bottom_nav_bar/screen/bottom_nav_bar_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_widgets.dart';
import '../../notifications/controller/notification_controller.dart';
import '../../leave/controller/leave_controller.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/bottom_nav_bar_controller.dart';
import '../../home/screen/home_screen.dart';
import '../../leave/screen/leave_screen.dart';
import '../../leave/screen/leave_status_screen.dart';
import '../../leave/screen/leave_apply_screen.dart';
import '../../leave/screen/leave_encashment_screen.dart';
import '../../leave/screen/leave_calendar_screen.dart';
import '../../leave/screen/leave_balance_screen.dart';
import '../../tour/screen/tour_screen.dart';
import '../../profile/screen/profile_screen.dart';
import '../../profile/screen/employee_directory_screen.dart';
import '../../payslip/screen/payslip_screen.dart';
import '../../holiday/screen/holiday_screen.dart';
import '../../approval/screen/approval_screen.dart';

class BottomNavBarScreen extends StatefulWidget {
  const BottomNavBarScreen({super.key});

  @override
  State<BottomNavBarScreen> createState() => _BottomNavBarScreenState();
}

class _BottomNavBarScreenState extends State<BottomNavBarScreen> {
  bool _isSidebarCollapsed = false; // State for web sidebar size
  bool _isLeaveMenuExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();
      context.read<NotificationController>().fetchNotifications();
      if (auth.user != null) {
        context.read<LeaveController>().fetchLeaves(auth.user!.employeeId);
        context.read<LeaveController>().fetchBalances(auth.user!.employeeId);
      }

      // Auto-select tab index based on route name on startup/refresh
      final routeName = ModalRoute.of(context)?.settings.name;
      if (routeName != null) {
        final controller = context.read<BottomNavBarController>();
        switch (routeName) {
          case '/dashboard':
            controller.setSelectedIndex(0);
            break;
          case '/leave':
            controller.setSelectedIndex(1);
            break;
          case '/tour':
            controller.setSelectedIndex(2);
            break;
          case '/profile':
            controller.setSelectedIndex(3);
            break;
          case '/directory':
            controller.setSelectedIndex(4);
            break;
          case '/paysips':
          case '/payslips':
            controller.setSelectedIndex(5);
            break;
          case '/holidays':
            controller.setSelectedIndex(6);
            break;
          case '/approvals':
            controller.setSelectedIndex(7);
            break;
        }
      }
    });
  }

  void _showLogoutConfirmation(BuildContext context) {
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
                context.read<AuthController>().logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final navBarController = context.watch<BottomNavBarController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWeb = constraints.maxWidth > 800;

        // Prevent index out of bounds in case mobile tab controller is set past mobile range
        int selectedIndex = navBarController.selectedIndex;
        if (!isWeb && selectedIndex > 3) {
          selectedIndex = 0;
        }

        final pages = [
          const HomeScreen(),
          isWeb ? const LeaveStatusPage() : const LeaveScreen(),
          const TourScreen(),
          const ProfileScreen(),
          const EmployeeDirectoryScreen(),
          const PayslipScreen(),
          const HolidayScreen(),
          const ApprovalScreen(),
          // Separate Leave pages for Web
          const LeaveApplyPage(),
          const LeaveEncashmentPage(),
          const LeaveCalendarPage(),
          const LeaveQuotaPage(),
        ];

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            children: [
              if (isWeb) _buildSidebar(navBarController, selectedIndex),
              Expanded(
                child: IndexedStack(
                  index: selectedIndex,
                  children: pages,
                ),
              ),
            ],
          ),
          bottomNavigationBar: isWeb ? null : _buildBottomNav(navBarController, selectedIndex),
        );
      },
    );
  }

  Widget _buildSidebarTile({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        selected: isSelected,
        onTap: onTap,
        contentPadding: _isSidebarCollapsed ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16),
        title: _isSidebarCollapsed
            ? Center(
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? Colors.white : Colors.white70,
                  size: 20,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
        leading: _isSidebarCollapsed
            ? null
            : Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? Colors.white : Colors.white70,
                size: 20,
              ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selectedTileColor: Colors.white12,
        dense: true,
      ),
    );
  }

  Widget _buildSubmenuItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: ListTile(
        onTap: onTap,
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
        hoverColor: Colors.white10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildLeaveSubmenuTile(BottomNavBarController navBarController, int selectedIndex) {
    final isSelected = selectedIndex == 1 || selectedIndex == 8 || selectedIndex == 9 || selectedIndex == 10;

    if (_isSidebarCollapsed) {
      return _buildSidebarTile(
        icon: Icons.event_note_outlined,
        activeIcon: Icons.event_note_rounded,
        label: 'Leave request',
        isSelected: isSelected,
        onTap: () {
          navBarController.setSelectedIndex(1);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ListTile(
            selected: isSelected,
            onTap: () {
              setState(() {
                _isLeaveMenuExpanded = !_isLeaveMenuExpanded;
              });
              navBarController.setSelectedIndex(1);
            },
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: Row(
              children: [
                const Text(
                  'Leave request',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Icon(
                  _isLeaveMenuExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white54,
                  size: 16,
                ),
              ],
            ),
            leading: Icon(
              isSelected ? Icons.event_note_rounded : Icons.event_note_outlined,
              color: isSelected ? Colors.white : Colors.white70,
              size: 20,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            selectedTileColor: Colors.white12,
            dense: true,
          ),
        ),
        if (_isLeaveMenuExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 8),
            child: Column(
              children: [
                 _buildSubmenuItem(
                  label: 'Leave Status',
                  isSelected: selectedIndex == 1,
                  onTap: () {
                    navBarController.setSelectedIndex(1);
                  },
                ),
                _buildSubmenuItem(
                  label: 'Leave Quota',
                  isSelected: selectedIndex == 11,
                  onTap: () {
                    navBarController.setSelectedIndex(11);
                  },
                ),
                _buildSubmenuItem(
                  label: 'Leave Apply',
                  isSelected: selectedIndex == 8,
                  onTap: () {
                    navBarController.setSelectedIndex(8);
                  },
                ),
                _buildSubmenuItem(
                  label: 'Leave Encashment',
                  isSelected: selectedIndex == 9,
                  onTap: () {
                    navBarController.setSelectedIndex(9);
                  },
                ),
                _buildSubmenuItem(
                  label: 'Leave Calendar',
                  isSelected: selectedIndex == 10,
                  onTap: () {
                    navBarController.setSelectedIndex(10);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSidebar(BottomNavBarController navBarController, int selectedIndex) {
    final user = context.watch<AuthController>().user;
    final isEmployee = user?.role == 'Employee' || (user?.role != 'RO' && user?.role != 'RO1');

    return Container(
      width: _isSidebarCollapsed ? 70 : 250,
      color: AppColors.primary,
      child: Column(
        children: [
          // Sidebar Header
          Container(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: _isSidebarCollapsed ? 8 : 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.white10,
                  width: 1,
                ),
              ),
            ),
            child: _isSidebarCollapsed
                ? Column(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu_rounded, color: Colors.white),
                        onPressed: () => setState(() => _isSidebarCollapsed = false),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.business_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.business_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MOIL Limited',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              user?.name ?? 'Employee',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, color: Colors.white70),
                        onPressed: () => setState(() => _isSidebarCollapsed = true),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          // Sidebar menu items
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: _isSidebarCollapsed ? 6 : 12),
              children: [
                _buildSidebarTile(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  isSelected: selectedIndex == 0,
                  onTap: () => navBarController.setSelectedIndex(0),
                ),
                _buildLeaveSubmenuTile(navBarController, selectedIndex),
                _buildSidebarTile(
                  icon: Icons.flight_takeoff_outlined,
                  activeIcon: Icons.flight_takeoff_rounded,
                  label: 'Tour request',
                  isSelected: selectedIndex == 2,
                  onTap: () => navBarController.setSelectedIndex(2),
                ),
                if (!isEmployee)
                  _buildSidebarTile(
                    icon: Icons.people_outline_rounded,
                    activeIcon: Icons.people_rounded,
                    label: 'Employee Directory',
                    isSelected: selectedIndex == 4,
                    onTap: () => navBarController.setSelectedIndex(4),
                  ),
                _buildSidebarTile(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Payslips',
                  isSelected: selectedIndex == 5,
                  onTap: () => navBarController.setSelectedIndex(5),
                ),
                _buildSidebarTile(
                  icon: Icons.celebration_outlined,
                  activeIcon: Icons.celebration_rounded,
                  label: 'Holiday Calendar',
                  isSelected: selectedIndex == 6,
                  onTap: () => navBarController.setSelectedIndex(6),
                ),
                if (!isEmployee)
                  _buildSidebarTile(
                    icon: Icons.approval_rounded,
                    activeIcon: Icons.approval_rounded,
                    label: 'Pending Approvals',
                    isSelected: selectedIndex == 7,
                    onTap: () => navBarController.setSelectedIndex(7),
                  ),
                _buildSidebarTile(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'My Profile',
                  isSelected: selectedIndex == 3,
                  onTap: () => navBarController.setSelectedIndex(3),
                ),
              ],
            ),
          ),
          // Logout Button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _isSidebarCollapsed ? 6 : 12),
            child: ListTile(
              onTap: () {
                _showLogoutConfirmation(context);
              },
              contentPadding: _isSidebarCollapsed ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16),
              title: _isSidebarCollapsed
                  ? const Center(
                      child: Icon(
                        Icons.logout_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    )
                  : const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
              leading: _isSidebarCollapsed
                  ? null
                  : const Icon(
                      Icons.logout_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              hoverColor: Colors.white10,
              dense: true,
            ),
          ),
          const SizedBox(height: 8),
          // Footer
          if (!_isSidebarCollapsed)
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                'v2.0.0 · © MOIL Ltd.',
                style: TextStyle(color: Colors.white30, fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BottomNavBarController navBarController, int selectedIndex) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navBar,
        border: const Border(
          top: BorderSide(color: AppColors.cardBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) => navBarController.setSelectedIndex(index),
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined),
            activeIcon: Icon(Icons.event_note_rounded),
            label: 'Leave',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flight_takeoff_outlined),
            activeIcon: Icon(Icons.flight_takeoff_rounded),
            label: 'Tour',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;

  _SidebarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
  });
}

class LeaveStatusPage extends StatelessWidget {
  const LeaveStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Leave Status',
        showBack: Navigator.of(context).canPop(),
      ),
      body: const LeaveStatusScreen(),
    );
  }
}

class LeaveApplyPage extends StatelessWidget {
  const LeaveApplyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Leave Apply',
        showBack: Navigator.of(context).canPop(),
      ),
      body: const LeaveApplyScreen(),
    );
  }
}

class LeaveEncashmentPage extends StatelessWidget {
  const LeaveEncashmentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Leave Encashment',
        showBack: Navigator.of(context).canPop(),
      ),
      body: const LeaveEncashmentScreen(),
    );
  }
}

class LeaveCalendarPage extends StatelessWidget {
  const LeaveCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Leave Calendar',
        showBack: Navigator.of(context).canPop(),
      ),
      body: const LeaveCalendarScreen(),
    );
  }
}

class LeaveQuotaPage extends StatelessWidget {
  const LeaveQuotaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Leave Quota',
        showBack: Navigator.of(context).canPop(),
      ),
      body: const LeaveBalanceScreen(),
    );
  }
}
