// lib/modules/profile/screen/employee_directory_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_widgets.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/profile_controller.dart';
import 'employee_detail_screen.dart';
import '../utils/profile_pdf_helper.dart';

class EmployeeDirectoryScreen extends StatefulWidget {
  const EmployeeDirectoryScreen({super.key});

  @override
  State<EmployeeDirectoryScreen> createState() => _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends State<EmployeeDirectoryScreen> {
  bool _isTableView = true; // Default to table view
  final Set<String> _selectedEmployeeIds = {};

  // Filters State
  String _filterId = '';
  String _filterName = '';
  String _filterRole = '';
  String _filterDept = '';
  String _filterStatus = '';

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileController>().fetchAllEmployees();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final currentUser = auth.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Employee Directory',
        showBack: Navigator.of(context).canPop(),
        // actions: [
        //   IconButton(
        //     icon: Icon(_isTableView ? Icons.grid_view_rounded : Icons.table_chart_rounded),
        //     tooltip: _isTableView ? 'Switch to Card List' : 'Switch to Table View',
        //     color: AppColors.primary,
        //     onPressed: () => setState(() => _isTableView = !_isTableView),
        //   ),
        //   const SizedBox(width: 8),
        // ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: Consumer<ProfileController>(
                  builder: (context, controller, _) {
                    if (controller.isLoading) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }

                    // 1. Strict Organization Hierarchy Filters (Show only subordinates under logged-in officer)
                    final List<Map<String, dynamic>> rawList = ProfileController.rawEmployees.where((m) {
                      final empNo = m['empNo']?.toString().trim().replaceAll(RegExp('^0+'), '') ?? '';
                      final cleanCurrentUserId = (currentUser?.employeeId ?? '').trim().replaceAll(RegExp('^0+'), '');
                      if (cleanCurrentUserId.isEmpty) return false;
                      if (empNo == cleanCurrentUserId) return false;
                      if (cleanCurrentUserId == '16194') return true; // Rakesh Tumane sees all
                      final ro = (m['reportingOfficer']?.toString() ?? '').trim().replaceAll(RegExp('^0+'), '');
                      final ro1 = (m['reportingOfficer1']?.toString() ?? '').trim().replaceAll(RegExp('^0+'), '');
                      return ro == cleanCurrentUserId || ro1 == cleanCurrentUserId;
                    }).toList();

                    final List<dynamic> modelList = controller.employees.where((e) {
                      final empNo = e.employeeId.trim().replaceAll(RegExp('^0+'), '');
                      final cleanCurrentUserId = (currentUser?.employeeId ?? '').trim().replaceAll(RegExp('^0+'), '');
                      if (cleanCurrentUserId.isEmpty) return false;
                      if (empNo == cleanCurrentUserId) return false;
                      if (cleanCurrentUserId == '16194') return true; // Rakesh Tumane sees all
                      final ro = e.reportingOfficer.trim().replaceAll(RegExp('^0+'), '');
                      final ro1 = e.reportingOfficer1.trim().replaceAll(RegExp('^0+'), '');
                      return ro == cleanCurrentUserId || ro1 == cleanCurrentUserId;
                    }).toList();

                    bool matchMultiTerm(String value, String filter) {
                      if (filter.isEmpty) return true;
                      final terms = filter.split(RegExp(r'[,;]')).map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty);
                      if (terms.isEmpty) return true;
                      final target = value.toLowerCase();
                      return terms.any((term) => target.contains(term));
                    }

                    // 2. Real-time Search Field Filters
                    final filteredRaw = rawList.where((m) {
                      final matchesId = matchMultiTerm((m['empNo'] ?? '').toString(), _filterId);
                      final matchesName = matchMultiTerm((m['name'] ?? '').toString(), _filterName);
                      final matchesRole = _filterRole.isEmpty || 
                          matchMultiTerm((m['position'] ?? '').toString(), _filterRole) || 
                          matchMultiTerm((m['empRoll'] ?? '').toString(), _filterRole) ||
                          matchMultiTerm((m['subgroupText'] ?? '').toString(), _filterRole);
                      final matchesDept = matchMultiTerm((m['dept'] ?? '').toString(), _filterDept);
                      final matchesStatus = matchMultiTerm((m['status'] ?? '').toString(), _filterStatus);

                      return matchesId && matchesName && matchesRole && matchesDept && matchesStatus;
                    }).toList();

                    final filteredModels = modelList.where((e) {
                      final matchesId = matchMultiTerm(e.employeeId, _filterId);
                      final matchesName = matchMultiTerm(e.name, _filterName);
                      final matchesRole = matchMultiTerm(e.designation, _filterRole);
                      final matchesDept = matchMultiTerm(e.department, _filterDept);
                      final matchesStatus = matchMultiTerm('active', _filterStatus);

                      return matchesId && matchesName && matchesRole && matchesDept && matchesStatus;
                    }).toList();

                    if (filteredModels.isEmpty) {
                      return const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No Matching Employees',
                        subtitle: 'Try adjusting your search criteria.',
                      );
                    }

                    if (_isTableView) {
                      return _buildTableView(filteredModels, filteredRaw);
                    }

                    return _buildListView(filteredModels);
                  },
                ),
              ),
            ],
          ),
          if (_selectedEmployeeIds.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Card(
                color: AppColors.primary,
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.people_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_selectedEmployeeIds.length} employee(s) selected',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        label: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          setState(() {
                            _selectedEmployeeIds.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return GlassCard(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_alt_outlined, color: AppColors.primary, size: 16),
              SizedBox(width: 6),
              Text(
                'Filter Directory',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWeb = constraints.maxWidth > 700;
              if (isWeb) {
                return Row(
                  children: [
                    Expanded(child: _buildFilterField('Employee ID', (v) => setState(() => _filterId = v))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFilterField('Name', (v) => setState(() => _filterName = v))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFilterField('Role / Roll', (v) => setState(() => _filterRole = v))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFilterField('Department', (v) => setState(() => _filterDept = v))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildFilterField('Status', (v) => setState(() => _filterStatus = v))),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildFilterField('Employee ID', (v) => setState(() => _filterId = v))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildFilterField('Name', (v) => setState(() => _filterName = v))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildFilterField('Role / Roll', (v) => setState(() => _filterRole = v))),
                        const SizedBox(width: 8),
                        Expanded(child: _buildFilterField('Department', (v) => setState(() => _filterDept = v))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildFilterField('Status', (v) => setState(() => _filterStatus = v)),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterField(String label, ValueChanged<String> onChanged) {
    return SizedBox(
      height: 36,
      child: TextField(
        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildListView(List<dynamic> employees) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: employees.length,
      itemBuilder: (context, index) {
        final emp = employees[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmployeeDetailScreen(employee: emp),
                ),
              );
            },
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                      ),
                      child: (() {
                        final id = emp.employeeId.trim().replaceAll(RegExp('^0+'), '');
                        if (id == '16194') {
                          return Image.asset('assets/images/rakesh_tumane.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter);
                        } else if (id == '17110') {
                          return Image.asset('assets/images/sameer_banerjee.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter);
                        } else if (id == '540') {
                          return Image.asset('assets/images/swapnil_manpe.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter);
                        } else if (id == '4410') {
                          return Image.asset('assets/images/ranjeet_chouhan.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter);
                        } else if (id == '4428') {
                          return Image.asset('assets/images/bcn_gautam.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter);
                        } else {
                          return const Icon(Icons.person_rounded, color: AppColors.primary, size: 24);
                        }
                      }()),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emp.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${emp.designation} · ${emp.department}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Emp Code: ${emp.employeeId}',
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                        tooltip: 'View Payslips',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EmployeeDetailScreen(employee: emp, initialTabIndex: 3),
                            ),
                          );
                        },
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableView(List<dynamic> employees, List<Map<String, dynamic>> filteredRaw) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Scrollbar(
            controller: _verticalScrollController,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              scrollDirection: Axis.vertical,
              child: Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                interactive: true,
                notificationPredicate: (notif) => notif.depth == 0,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                showCheckboxColumn: true,
                headingRowColor: WidgetStateProperty.all(AppColors.primary.withOpacity(0.06)),
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  fontSize: 12,
                ),
                dataTextStyle: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
                columns: const [
                  DataColumn(label: Text('Employee ID')),
                  DataColumn(label: Text('Employee Name')),
                  DataColumn(label: Text('Group')),
                  DataColumn(label: Text('Subgroup')),
                  DataColumn(label: Text('Position')),
                  DataColumn(label: Text('Department')),
                  DataColumn(label: Text('Date of Birth')),
                  DataColumn(label: Text('Date of Appointment')),
                  DataColumn(label: Text('Date of Present Posting')),
                  DataColumn(label: Text('Date of Retirement')),
                  DataColumn(label: Text('Mobile')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: filteredRaw.map((m) {
                  final isSelected = _selectedEmployeeIds.contains(m['empNo']);
                  final matches = employees.where((e) => e.employeeId == m['empNo']);
                  final empModel = matches.isNotEmpty ? matches.first : null;

                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedEmployeeIds.add(m['empNo']);
                        } else {
                          _selectedEmployeeIds.remove(m['empNo']);
                        }
                      });
                    },
                    cells: [
                      DataCell(Text(m['empNo'] ?? '')),
                      DataCell(
                        GestureDetector(
                          onTap: () {
                            if (empModel != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => EmployeeDetailScreen(employee: empModel)),
                              );
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: (() {
                                    final id = (m['empNo'] ?? '').toString().trim().replaceAll(RegExp('^0+'), '');
                                    if (id == '16194') {
                                      return Image.asset('assets/images/rakesh_tumane.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter);
                                    } else if (id == '17110') {
                                      return Image.asset('assets/images/sameer_banerjee.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter);
                                    } else if (id == '540') {
                                      return Image.asset('assets/images/swapnil_manpe.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter);
                                    } else if (id == '4410') {
                                      return Image.asset('assets/images/ranjeet_chouhan.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter);
                                    } else if (id == '4428') {
                                      return Image.asset('assets/images/bcn_gautam.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter);
                                    } else {
                                      return const Icon(Icons.person_rounded, color: AppColors.primary, size: 14);
                                    }
                                  }()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                m['name'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(Text(m['group'] ?? '')),
                      DataCell(Text(m['subgroup'] ?? '')),
                      DataCell(Text(m['position'] ?? '')),
                      DataCell(Text(m['dept'] ?? '')),
                      DataCell(Text(m['dob'] ?? '')),
                      DataCell(Text(m['apptDate'] ?? '')),
                      DataCell(Text(m['dopp'] ?? '')),
                      DataCell(Text(m['retireDate'] ?? '')),
                      DataCell(Text(m['mobile'] ?? '')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
                              tooltip: 'View Payslips',
                              onPressed: () {
                                if (empModel != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => EmployeeDetailScreen(employee: empModel, initialTabIndex: 3),
                                    ),
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.print_outlined, color: AppColors.primary, size: 18),
                              tooltip: 'Print HRIS Profile',
                              onPressed: () {
                                if (empModel != null) {
                                  ProfilePdfHelper.printEmployeeProfilePdf(empModel);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          ),
          ),
        ),
      ),
    );
  }
}
