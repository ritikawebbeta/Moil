import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../utils/app_config.dart';
import '../../../utils/api_client.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_widgets.dart';
import '../../auth/controller/auth_controller.dart';
import '../../profile/controller/profile_controller.dart';
import '../../../services/sms_direct_service.dart';

class LeaveEncashmentScreen extends StatefulWidget {
  const LeaveEncashmentScreen({super.key});

  @override
  State<LeaveEncashmentScreen> createState() => _LeaveEncashmentScreenState();
}

class _LeaveEncashmentScreenState extends State<LeaveEncashmentScreen> {
  int _serviceDays = 0;
  int _currentStep = 1; // 1 = Employee Search, 2 = Employee Details, 3 = Completed

  // Step 1 Controllers
  final _employeeCodeSearchCtrl = TextEditingController(text: '00000000');
  String _selectedYear = DateTime.now().year.toString();
  final List<String> _calendarYears = List.generate(7, (index) => (DateTime.now().year - 6 + index).toString());

  // Step 2 Controllers & Fields
  final _daysToEncashCtrl = TextEditingController(text: '00000');
  String _employeeCode = '';
  String _employeeName = '';
  String _docNumber = '';
  String _docStatus = '';
  String _createdOn = '';
  String _leaveBalance = '';
  String _approver = '';

  bool _isSearching = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _employeeCodeSearchCtrl.dispose();
    _daysToEncashCtrl.dispose();
    super.dispose();
  }

  void _handleSearch() async {
    setState(() {
      _isSearching = true;
    });

    final searchCode = _employeeCodeSearchCtrl.text.trim();
    if (searchCode.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter an Employee Number.'),
          backgroundColor: AppColors.error,
        ));
      }
      setState(() {
        _isSearching = false;
      });
      return;
    }

    final cleanSearchCode = searchCode.trim().replaceAll(RegExp('^0+'), '');

    try {
      // Fetch employee leave details from leave_quota table via API
      final prefs = await SharedPreferences.getInstance();
      final userJsonStr = prefs.getString('auth_user');
      String? token;
      if (userJsonStr != null) {
        token = jsonDecode(userJsonStr)['token'];
      }

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Session expired. Please login again.'),
            backgroundColor: AppColors.error,
          ));
        }
        setState(() => _isSearching = false);
        return;
      }

      final response = await ApiClient.get(
        Uri.parse('${AppConfig.baseUrl}/api/employee-leave-details/$cleanSearchCode'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Employee $cleanSearchCode not found in database.'),
            backgroundColor: AppColors.error,
          ));
        }
        setState(() => _isSearching = false);
        return;
      }

      final data = jsonDecode(response.body);

      // Extract employee name from database
      final empName = data['employeeName']?.toString() ?? 'Employee $cleanSearchCode';

      // Extract earned leave balance from leave_quota table
      final earnedLeaveBalance = double.tryParse(data['earnedLeaveBalance']?.toString() ?? '0') ?? 0.0;

      // Extract reporting officers
      String resolvedApprover = 'Please contact Head Office';
      final ro = data['reportingOfficer'];
      final ro1 = data['reportingOfficer1'];
      if (ro != null && ro1 != null) {
        resolvedApprover = '${ro1['name']} & ${ro['name']}';
      } else if (ro != null) {
        resolvedApprover = ro['name']?.toString() ?? '-';
      } else if (ro1 != null) {
        resolvedApprover = ro1['name']?.toString() ?? '-';
      }

      // Calculate service days from profile data
      final profileController = context.read<ProfileController>();
      if (profileController.employees.isEmpty) {
        await profileController.fetchAllEmployees();
      }
      final empList = profileController.employees;
      final hasMatch = empList.any((e) => e.employeeId == searchCode || e.employeeId == cleanSearchCode);
      final emp = hasMatch
          ? empList.firstWhere((e) => e.employeeId == searchCode || e.employeeId == cleanSearchCode)
          : null;

      DateTime joinDateParsed;
      final joinDateStr = emp?.joinDate ?? '22/06/2018';
      try {
        final cleanDoj = joinDateStr.replaceAll('/', '-');
        joinDateParsed = DateFormat('dd-MM-yyyy').parse(cleanDoj);
      } catch (_) {
        joinDateParsed = DateTime.now().subtract(const Duration(days: 365));
      }
      final serviceDays = DateTime.now().difference(joinDateParsed).inDays;

      setState(() {
        _employeeCode = cleanSearchCode;
        _employeeName = empName;
        _docNumber = '${22200 + cleanSearchCode.hashCode % 1000}';
        _createdOn = DateFormat('dd-MM-yyyy').format(DateTime.now());
        _leaveBalance = earnedLeaveBalance.toStringAsFixed(2);
        _approver = resolvedApprover;
        _docStatus = 'NEW';
        _serviceDays = serviceDays;
        _daysToEncashCtrl.text = '00000';
        _isSearching = false;
        _currentStep = 2;
      });
    } catch (e) {
      debugPrint('Error fetching employee leave details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error fetching details: $e'),
          backgroundColor: AppColors.error,
        ));
      }
      setState(() => _isSearching = false);
    }
  }

  void _handleSubmit() async {
    if (_serviceDays <= 30) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Not eligible: Service period is only $_serviceDays days (Up to 30 days is restricted).'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final days = int.tryParse(_daysToEncashCtrl.text) ?? 0;
    if (days <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a valid number of days to encash (greater than 0).'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final balance = double.tryParse(_leaveBalance) ?? 0.0;
    if (days > balance) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Requested days exceed current Earned Leave Balance of ${balance.toStringAsFixed(0)}.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final halfBalance = (balance * 0.5).toInt();
    final maxAllowed = halfBalance < 30 ? halfBalance : 30;

    if (days > maxAllowed) {
      if (halfBalance < 30) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Not eligible: You can only encash up to 50% of your total balance (Max: $halfBalance days for balance of ${balance.toStringAsFixed(0)}).'),
          backgroundColor: AppColors.error,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Not eligible: Maximum 30 days can be encashed in a financial year.'),
          backgroundColor: AppColors.error,
        ));
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    await Future.delayed(const Duration(milliseconds: 200));
    setState(() {
      _docNumber = 'ENC${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      _currentStep = 3; // Show success confirmation
      _isSubmitting = false;
    });

    // Trigger Direct MyVI SMS for Leave Encashment Application
    SmsDirectService.sendLeaveEncashAppliedSms(
      applicantName: _employeeName,
      days: _daysToEncashCtrl.text,
    );
  }

  void _resetForm() {
    setState(() {
      _employeeCodeSearchCtrl.text = '00000000';
      _selectedYear = DateTime.now().year.toString();
      _currentStep = 1;
    });
  }

  // ─── Custom SAP Layout Elements ──────────────────────────────────
  Widget _buildSapTitleBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.primary.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 12),
      child: const Text(
        'Leave Encashment',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStepHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStepCircle('1', 'Search', _currentStep >= 1),
            _buildConnector(_currentStep >= 2),
            _buildStepCircle('2', 'Apply Details', _currentStep >= 2),
            _buildConnector(_currentStep >= 3),
            _buildStepCircle('3', 'Completed', _currentStep >= 3),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCircle(String num, String label, bool isDone) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone ? AppColors.primary : Colors.grey.shade300,
          ),
          child: Center(
            child: Text(
              num,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: isDone ? AppColors.primary : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(bool active) {
    return Container(
      width: 20,
      height: 2,
      color: active ? AppColors.primary : Colors.grey.shade300,
      margin: const EdgeInsets.symmetric(horizontal: 6),
    );
  }

  // ─── Step 1: Employee Search ────────────────────────────────────
  Widget _buildSearchForm() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsible header imitation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppColors.primary.withOpacity(0.06),
            child: Row(
              children: [
                const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                const SizedBox(width: 4),
                const Text(
                  'Employee Search',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  color: AppColors.primary.withOpacity(0.04),
                  child: const Text(
                    'Search Criteria',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool useVertical = constraints.maxWidth < 420;
                    if (useVertical) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Employee Number:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _employeeCodeSearchCtrl,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 120,
                          child: Text(
                            'Employee Number:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                            textAlign: TextAlign.end,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _employeeCodeSearchCtrl,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool useVertical = constraints.maxWidth < 420;
                    if (useVertical) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Calendar Year:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedYear,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                items: _calendarYears.map((year) => DropdownMenuItem(
                                  value: year,
                                  child: Text(year),
                                )).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedYear = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 120,
                          child: Text(
                            'Calendar Year:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                            textAlign: TextAlign.end,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedYear,
                                isDense: true,
                                isExpanded: true,
                                style: const TextStyle(fontSize: 12, color: Colors.black87),
                                items: _calendarYears.map((year) => DropdownMenuItem(
                                  value: year,
                                  child: Text(year),
                                )).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedYear = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSearching ? null : _handleSearch,
                      icon: _isSearching
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.black54),
                            )
                          : const Icon(Icons.search, size: 14),
                      label: const Text('SEARCH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 2: Employee Details Form ──────────────────────────────
  Widget _buildDetailsForm() {
    return Column(
      children: [
        if (_serviceDays <= 30)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.error.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Not Eligible: Service period is up to 30 days (Current: $_serviceDays days). Leave encashment is not allowed.',
                    style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.person_outline, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Employee: $_employeeName ($_employeeCode)',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Earned Leave Days Balance: $_leaveBalance Days',
                      style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: AppColors.primary.withOpacity(0.06),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                    const SizedBox(width: 4),
                    const Text(
                      'Employee Details',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWide = constraints.maxWidth > 600;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildDetailsLeftColumn()),
                          const SizedBox(width: 24),
                          Expanded(child: _buildDetailsRightColumn()),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildDetailsLeftColumn(),
                          const Divider(height: 24),
                          _buildDetailsRightColumn(),
                        ],
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsLeftColumn() {
    return Column(
      children: [
        _buildStaticRow('* Employee Number:', _employeeCode),
        const SizedBox(height: 8),
        _buildStaticRow('* Document Number:', _docNumber),
        const SizedBox(height: 8),
        _buildStaticRow('* Created On:', _createdOn),
        const SizedBox(height: 8),
        _buildStaticRow('* Approver:', _approver),
      ],
    );
  }

  Widget _buildDetailsRightColumn() {
    final balance = double.tryParse(_leaveBalance) ?? 0.0;
    final halfBalance = (balance * 0.5).toInt();
    final maxAllowed = halfBalance < 30 ? halfBalance : 30;

    return Column(
      children: [
        _buildStaticRow('* Employee Name:', _employeeName),
        const SizedBox(height: 8),
        _buildStaticRow('* Document Status:', _docStatus),
        const SizedBox(height: 8),
        _buildStaticRow('* Earned Leave Balance:', _leaveBalance),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final bool useVertical = constraints.maxWidth < 420;
            if (useVertical) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '* No. of days to be Encashed:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _daysToEncashCtrl,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      helperText: 'Max eligible: $maxAllowed days (50% of balance up to max 30 days)',
                      helperStyle: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                    ),
                  ),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 140,
                  child: Text(
                    '* No. of days to be Encashed:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                    textAlign: TextAlign.end,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _daysToEncashCtrl,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      helperText: 'Max eligible: $maxAllowed days (50% of balance up to max 30 days)',
                      helperStyle: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: (_isSubmitting || _serviceDays <= 30) ? null : _handleSubmit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.black54),
                    )
                  : const Icon(Icons.save, size: 14),
              label: const Text('SUBMIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStaticRow(String label, String value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool useVertical = constraints.maxWidth < 420;
        if (useVertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 140,
              child: Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black87),
                textAlign: TextAlign.end,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Step 3: Success Confirmation Screen ─────────────────────────
  Widget _buildSuccessView() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 48),
          ),
          const SizedBox(height: 18),
          const Text(
            'Leave Encashment Submitted!',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The request for employee $_employeeName ($_employeeCode) to encash ${_daysToEncashCtrl.text} days has been successfully submitted.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _resetForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Process Another Encashment'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSapTitleBanner(),
          _buildStepHeader(),
          const SizedBox(height: 16),
          if (_currentStep == 1)
            _buildSearchForm()
          else if (_currentStep == 2)
            _buildDetailsForm()
          else if (_currentStep == 3)
            _buildSuccessView(),
        ],
      ),
    );
  }
}
