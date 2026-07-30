// lib/modules/profile/screen/employee_directory_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_widgets.dart';
import '../../auth/controller/auth_controller.dart';
import '../../../model/employee_model.dart';
import '../controller/profile_controller.dart';
import 'employee_detail_screen.dart';
import '../../../widgets/employee_avatar_widget.dart';
import '../utils/profile_pdf_helper.dart';

class EmployeeDirectoryScreen extends StatefulWidget {
  const EmployeeDirectoryScreen({super.key});

  @override
  State<EmployeeDirectoryScreen> createState() => _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends State<EmployeeDirectoryScreen> {
  bool _isTableView = true; // Default to table view
  final Set<String> _selectedEmployeeIds = {};
  int _currentPage = 1;
  int _pageSize = 15;

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

                    // 1. Employee Directory List (Unique employees cleanly loaded)
                    final seenRawIds = <String>{};
                    final List<Map<String, dynamic>> rawList = [];
                    for (final m in ProfileController.rawEmployees) {
                      final empNo = m['empNo']?.toString().trim().replaceAll(RegExp('^0+'), '') ?? '';
                      if (empNo.isNotEmpty && seenRawIds.add(empNo)) {
                        rawList.add(m);
                      }
                    }

                    final seenModelIds = <String>{};
                    final List<EmployeeModel> modelList = [];
                    for (final e in controller.employees) {
                      final empNo = e.employeeId.trim().replaceAll(RegExp('^0+'), '');
                      if (empNo.isNotEmpty && seenModelIds.add(empNo)) {
                        modelList.add(e);
                      }
                    }

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
                      return _buildTableView(filteredModels.cast<EmployeeModel>(), filteredRaw);
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Consumer<ProfileController>(
                builder: (context, controller, _) {
                  final totalCount = controller.employees.length;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Total Employees: $totalCount',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  );
                },
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
        onChanged: (val) {
          setState(() {
            _currentPage = 1;
          });
          onChanged(val);
        },
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
                          'Group: ${emp.employeeGroup} · Subgroup: ${emp.employeeSubgroup}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Present Posting: ${emp.dopp}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
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

  Widget _buildTableView(List<EmployeeModel> employees, List<Map<String, dynamic>> filteredRaw) {
    final uniqueEmployees = <EmployeeModel>[];
    final seenIds = <String>{};
    for (final e in employees) {
      final cleanId = e.employeeId.trim().replaceAll(RegExp('^0+'), '');
      if (cleanId.isNotEmpty && seenIds.add(cleanId)) {
        uniqueEmployees.add(e);
      }
    }

    final totalItems = uniqueEmployees.length;
    final totalPages = (totalItems / _pageSize).ceil();
    final safePage = _currentPage.clamp(1, totalPages > 0 ? totalPages : 1);
    final startIndex = (safePage - 1) * _pageSize;
    final displayedEmployees = uniqueEmployees.skip(startIndex).take(_pageSize).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: GlassCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  interactive: true,
                  notificationPredicate: (notif) => notif.depth == 0,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Scrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      interactive: true,
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          columnSpacing: 24,
                          horizontalMargin: 16,
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
                          rows: displayedEmployees.map<DataRow>((EmployeeModel emp) {
                            final isSelected = _selectedEmployeeIds.contains(emp.employeeId);

                            return DataRow(
                              selected: isSelected,
                              onSelectChanged: (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedEmployeeIds.add(emp.employeeId);
                                  } else {
                                    _selectedEmployeeIds.remove(emp.employeeId);
                                  }
                                });
                              },
                              cells: [
                                DataCell(Text(emp.employeeId)),
                                DataCell(
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => EmployeeDetailScreen(employee: emp)),
                                      );
                                    },
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        EmployeeAvatarWidget(
                                          empNo: emp.employeeId,
                                          width: 26,
                                          height: 26,
                                          borderRadius: BorderRadius.circular(13),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          emp.name,
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
                                DataCell(Text(emp.employeeGroup != 'N/A' ? emp.employeeGroup : emp.appointmentType)),
                                DataCell(Text(emp.employeeSubgroup)),
                                DataCell(Text(emp.designation)),
                                DataCell(Text(emp.department)),
                                DataCell(Text(emp.dateOfBirth)),
                                DataCell(Text(emp.joinDate)),
                                DataCell(Text(emp.presentPostingDate)),
                                DataCell(Text(emp.retirementDate)),
                                DataCell(Text(emp.mobileNumber)),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility_rounded, color: AppColors.primary, size: 18),
                                        tooltip: 'View Profile',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => EmployeeDetailScreen(employee: emp)),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
                                        tooltip: 'View Payslips',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => EmployeeDetailScreen(employee: emp, initialTabIndex: 3)),
                                          );
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
          ),
          if (totalItems > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${startIndex + 1}–${startIndex + displayedEmployees.length} of $totalItems employees',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  Row(
                    children: [
                      if (startIndex + displayedEmployees.length < totalItems) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 14),
                          label: const Text('Show More (+15)'),
                          onPressed: () {
                            setState(() {
                              _pageSize += 15;
                            });
                          },
                        ),
                        const SizedBox(width: 12),
                      ],
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, size: 22),
                        color: safePage > 1 ? AppColors.primary : AppColors.textHint,
                        onPressed: safePage > 1 ? () => setState(() => _currentPage--) : null,
                      ),
                      Text(
                        'Page $safePage of $totalPages',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, size: 22),
                        color: safePage < totalPages ? AppColors.primary : AppColors.textHint,
                        onPressed: safePage < totalPages ? () => setState(() => _currentPage++) : null,
                      ),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: [15, 30, 50, 100].contains(_pageSize) ? _pageSize : 15,
                        underline: const SizedBox(),
                        style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(value: 15, child: Text('15 / page')),
                          DropdownMenuItem(value: 30, child: Text('30 / page')),
                          DropdownMenuItem(value: 50, child: Text('50 / page')),
                          DropdownMenuItem(value: 100, child: Text('100 / page')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _pageSize = val;
                              _currentPage = 1;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
