import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/app_config.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_widgets.dart';
import '../../auth/controller/auth_controller.dart';
import '../../profile/controller/profile_controller.dart';

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

  // Mock employee database
  final Map<String, Map<String, dynamic>> _mockEmployees = {
  
    '00000463': {
      'name': 'Asim Md.Iqbal Shaikh',
      'docNo': '22283',
      'createdOn': '14.02.2026',
      'balance': '00199',
      'approver': 'Manish M Malewar',
      'status': 'UPDATED',
    },
  
  };

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

    // Simulate search delay
    await Future.delayed(const Duration(milliseconds: 800));

    final searchCode = _employeeCodeSearchCtrl.text.trim();
    if (searchCode.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please enter an Employee Code.'),
          backgroundColor: AppColors.error,
        ));
      }
      setState(() {
        _isSearching = false;
      });
      return;
    }

    final currentUserId = context.read<AuthController>().user?.employeeId;
    final profileController = context.read<ProfileController>();
    if (profileController.employees.isEmpty) {
      await profileController.fetchAllEmployees();
    }
    final empList = profileController.employees;
    
    // Find matching employee or fallback
    final hasMatch = empList.any((e) => e.employeeId == searchCode);
    final emp = hasMatch 
        ? empList.firstWhere((e) => e.employeeId == searchCode)
        : null;

    final cleanSearchCode = searchCode.trim().replaceAll(RegExp('^0+'), '');

    // Check if employee is in Organization Hierarchy (reports to current user)
    final empMap = ProfileController.rawEmployees.firstWhere(
      (e) => e['empNo'] == cleanSearchCode,
      orElse: () => <String, dynamic>{},
    );

    final roId = empMap['reportingOfficer']?.toString() ?? '';
    final ro1Id = empMap['reportingOfficer1']?.toString() ?? '';
    
    final cleanRoId = roId.trim().replaceAll(RegExp('^0+'), '');
    final cleanRo1Id = ro1Id.trim().replaceAll(RegExp('^0+'), '');
    final cleanCurrentUserId = (currentUserId ?? '').trim().replaceAll(RegExp('^0+'), '');
    
    final isTeamMember = (cleanRoId == cleanCurrentUserId || cleanRo1Id == cleanCurrentUserId);

    double dbBalance = 0.0;
    bool fetchSuccess = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJsonStr = prefs.getString('auth_user');
      String? token;
      if (userJsonStr != null) {
        token = jsonDecode(userJsonStr)['token'];
      }
      if (token != null) {
        final response = await http.get(
          Uri.parse('${AppConfig.baseUrl}/api/leave-balances?employee_id=$cleanSearchCode'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final List<dynamic> balancesList = jsonDecode(response.body);
          final elBalanceObj = balancesList.firstWhere(
            (b) => b['timeAccount']?.toString().toLowerCase().contains('earned') == true || b['typeId']?.toString() == '1000',
            orElse: () => null,
          );
          if (elBalanceObj != null) {
            dbBalance = double.tryParse(elBalanceObj['entitlementMinusPlanned']?.toString() ?? '0') ?? 0.0;
            fetchSuccess = true;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching actual leave balance: $e');
    }

    if (!fetchSuccess && isTeamMember) {
      dbBalance = 120.00;
      fetchSuccess = true;
    }

    final data = _mockEmployees[searchCode] ?? {
      'name': empMap['name'] ?? emp?.name ?? 'Employee $searchCode',
      'docNo': '${22200 + searchCode.hashCode % 1000}',
      'createdOn': DateFormat('dd-MM-yyyy').format(DateTime.now()),
      'balance': fetchSuccess ? dbBalance.toStringAsFixed(2) : '0.00',
      'approver': 'Rakesh Tumane',
      'status': 'NEW',
    };

    DateTime joinDateParsed;
    if (searchCode == '00000467') {
      // Mock Vaishali Taksande as new hire (15 days service)
      joinDateParsed = DateTime.now().subtract(const Duration(days: 15));
    } else {
      final joinDateStr = emp?.joinDate ?? '22/06/2018';
      try {
        final cleanDoj = joinDateStr.replaceAll('/', '-');
        joinDateParsed = DateFormat('dd-MM-yyyy').parse(cleanDoj);
      } catch (_) {
        joinDateParsed = DateTime.now().subtract(const Duration(days: 365));
      }
    }
    final serviceDays = DateTime.now().difference(joinDateParsed).inDays;

    String resolvedApprover = '-';
    if (empMap.isNotEmpty) {
      final roId = empMap['reportingOfficer']?.toString() ?? '';
      final ro1Id = empMap['reportingOfficer1']?.toString() ?? '';
      final roName = empMap['reportingOfficerName']?.toString() ?? '';
      final ro1Name = empMap['reportingOfficer1Name']?.toString() ?? '';
      
      final cleanRoId = roId.trim().replaceAll(RegExp('^0+'), '');
      final cleanRo1Id = ro1Id.trim().replaceAll(RegExp('^0+'), '');

      bool hasRo = roId.isNotEmpty && roId != '0' && roId != 'N/A';
      bool hasRo1 = ro1Id.isNotEmpty && ro1Id != '0' && ro1Id != 'N/A';

      String rName = '';
      String r1Name = '';

      if (hasRo) {
        if (roName.isNotEmpty && roName != roId && roName.toLowerCase() != 'n/a') {
          rName = roName;
        } else {
          final roMap = ProfileController.rawEmployees.firstWhere(
            (e) => e['empNo'] == cleanRoId,
            orElse: () => <String, dynamic>{},
          );
          rName = (roMap.isNotEmpty && roMap['name'] != null && roMap['name'].toString().isNotEmpty) 
              ? roMap['name'] 
              : "Please contact Head Office";
        }
      }

      if (hasRo1) {
        if (ro1Name.isNotEmpty && ro1Name != ro1Id && ro1Name.toLowerCase() != 'n/a') {
          r1Name = ro1Name;
        } else {
          final ro1Map = ProfileController.rawEmployees.firstWhere(
            (e) => e['empNo'] == cleanRo1Id,
            orElse: () => <String, dynamic>{},
          );
          r1Name = (ro1Map.isNotEmpty && ro1Map['name'] != null && ro1Map['name'].toString().isNotEmpty) 
              ? ro1Map['name'] 
              : "Please contact Head Office";
        }
      }

      if (rName.isNotEmpty && r1Name.isNotEmpty) {
        resolvedApprover = '$r1Name & $rName';
      } else if (rName.isNotEmpty) {
        resolvedApprover = rName;
      } else if (r1Name.isNotEmpty) {
        resolvedApprover = r1Name;
      } else {
        resolvedApprover = 'Please contact Head Office';
      }
    } else {
      resolvedApprover = 'Please contact Head Office';
    }

    setState(() {
      _employeeCode = searchCode;
      _employeeName = data['name'];
      _docNumber = data['docNo'];
      _createdOn = data['createdOn'];
      _leaveBalance = data['balance'];
      _approver = resolvedApprover;
      _docStatus = data['status'];
      _serviceDays = serviceDays;
      _daysToEncashCtrl.text = '00000';
      _isSearching = false;
      _currentStep = 2; // Proceed to details form
    });
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
        content: Text('Requested days exceed current Earned Leave Balance of $balance.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    final maxEligibleDays = (balance * 0.5).toInt();
    if (days > maxEligibleDays) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Not eligible: You can only encash up to 50% of your total balance (Max: $maxEligibleDays days).'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final finalDays = days > 30 ? 30 : days;
    if (days > 30) {
      _daysToEncashCtrl.text = '30';
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Note: Encashment request has been capped to the maximum of 30 days.'),
        backgroundColor: Colors.blueAccent,
      ));
    }

    await Future.delayed(const Duration(milliseconds: 200));
    setState(() {
      _docNumber = 'ENC${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      _currentStep = 3; // Show success confirmation
      _isSubmitting = false;
    });
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
                            'Employee Code:',
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
                            'Employee Code:',
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
        _buildStaticRow('* Employee Code:', _employeeCode),
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
