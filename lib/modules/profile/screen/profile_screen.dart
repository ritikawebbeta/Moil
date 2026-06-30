// lib/modules/profile/screen/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      if (auth.user != null) {
        context
            .read<ProfileController>()
            .fetchEmployeeProfile(auth.user!.employeeId);
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
      appBar: CustomAppBar(
        title: 'My Profile',
        showBack: Navigator.of(context).canPop(),
        leading:
            Navigator.of(context).canPop() ? null : const SizedBox.shrink(),
      ),
      body: Consumer2<ProfileController, AuthController>(
        builder: (context, profileController, authController, _) {
          if (profileController.isLoading) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          final emp = profileController.employee;
          final auth = authController.user;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildProfileHeader(auth?.name ?? emp?.name ?? 'Employee',
                    auth?.designation ?? emp?.designation ?? ''),
                const SizedBox(height: 16),
                _buildEmployeeInfo(emp),
                const SizedBox(height: 16),
                _buildActions(authController),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(String name, String designation) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2)
                  ],
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'E',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700),
          ),
          Text(designation,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Active Employee',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeInfo(dynamic emp) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const SectionHeader(
            title: 'Employee Information',
            icon: Icons.badge_outlined,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                
                InfoRow(label: 'Name', value: emp?.name ?? ''),
                InfoRow(
                    label: 'Father / Spouse Name',
                    value: emp?.fatherSpouseName ?? ''),
                InfoRow(label: 'Designation', value: emp?.designation ?? ''),
                InfoRow(label: 'Department', value: emp?.department ?? ''),
                InfoRow(label: 'Present Grade', value: emp?.presentGrade ?? ''),
                InfoRow(label: 'Date of Birth', value: emp?.dateOfBirth ?? ''),
                InfoRow(
                    label: 'Date of Joining in MOIL',
                    value: emp?.joinDate ?? ''),
                InfoRow(
                    label: 'Date of Last Promotion',
                    value: emp?.lastPromotionDate ?? ''),
                InfoRow(
                    label: 'Appointment Type',
                    value: emp?.appointmentType ?? ''),
                InfoRow(label: 'Category', value: emp?.category ?? ''),
                InfoRow(label: 'Blood Group', value: emp?.bloodGroup ?? ''),
                InfoRow(label: 'Gender', value: emp?.gender ?? ''),
                InfoRow(
                    label: 'Marital Status', value: emp?.maritalStatus ?? ''),
                InfoRow(label: 'EMP.NO / FORM B', value: emp?.employeeId ?? ''),
                InfoRow(label: 'Basic (Rs)', value: emp?.basicSalary ?? ''),
                InfoRow(
                    label: 'Present Place of Posting',
                    value: emp?.presentPlaceOfPosting ?? ''),
                InfoRow(
                    label: 'Date of Present Posting',
                    value: emp?.presentPostingDate ?? ''),
                InfoRow(
                    label: 'Date of Retirement',
                    value: emp?.retirementDate ?? ''),
                InfoRow(label: 'Mobile No', value: emp?.mobileNumber ?? ''),
                InfoRow(label: 'E-Mail', value: emp?.email ?? ''),
                InfoRow(label: 'UAN No', value: emp?.uanNo ?? ''),
                InfoRow(label: 'PAN No', value: emp?.panNo ?? ''),
                InfoRow(label: 'Aadhaar No', value: emp?.aadhaarNo ?? ''),
                InfoRow(label: 'PRAN No', value: emp?.pranNo ?? ''),
                InfoRow(label: 'PF No / SSPF No', value: emp?.pfNo ?? ''),
                InfoRow(label: 'Pension No', value: emp?.pensionNo ?? ''),
              ],
            ),
          ),
        ],
      ),
    );
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
                    'Are you sure you want to log out of MOIL EMS?',
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
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Change Password',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const TextField(
              obscureText: true,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                  labelText: 'Current Password',
                  prefixIcon:
                      Icon(Icons.lock_outline, color: AppColors.primary)),
            ),
            const SizedBox(height: 12),
            const TextField(
              obscureText: true,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                  labelText: 'New Password',
                  prefixIcon:
                      Icon(Icons.lock_reset_rounded, color: AppColors.primary)),
            ),
            const SizedBox(height: 12),
            const TextField(
              obscureText: true,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon:
                      Icon(Icons.lock_rounded, color: AppColors.primary)),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Update Password',
              icon: Icons.save_rounded,
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Password updated successfully!'),
                  backgroundColor: AppColors.success,
                ));
              },
            ),
          ],
        ),
      ),
    );
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
