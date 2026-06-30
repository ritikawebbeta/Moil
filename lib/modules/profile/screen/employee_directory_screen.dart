// lib/modules/profile/screen/employee_directory_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_widgets.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/profile_controller.dart';
import 'employee_detail_screen.dart';

class EmployeeDirectoryScreen extends StatefulWidget {
  const EmployeeDirectoryScreen({super.key});

  @override
  State<EmployeeDirectoryScreen> createState() => _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends State<EmployeeDirectoryScreen> {
  bool _isTableView = true; // Default to table view

  // Filters State
  String _filterId = '';
  String _filterName = '';
  String _filterRole = '';
  String _filterDept = '';
  String _filterStatus = '';

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
        actions: [
          IconButton(
            icon: Icon(_isTableView ? Icons.grid_view_rounded : Icons.table_chart_rounded),
            tooltip: _isTableView ? 'Switch to Card List' : 'Switch to Table View',
            color: AppColors.primary,
            onPressed: () => setState(() => _isTableView = !_isTableView),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: Consumer<ProfileController>(
              builder: (context, controller, _) {
                if (controller.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }

                // 1. Strict Organization Hierarchy Filters
                final List<Map<String, dynamic>> rawList = ProfileController.rawEmployees.where((m) {
                  final empNo = m['empNo'];
                  if (currentUser?.employeeId == '16194') {
                    return empNo != '16194';
                  } else if (currentUser?.employeeId == '283') {
                    return empNo == '422' || empNo == '431';
                  } else if (currentUser?.employeeId == '446') {
                    return empNo == '491' || empNo == '540';
                  }
                  return false;
                }).toList();

                final List<dynamic> modelList = controller.employees.where((e) {
                  if (currentUser?.employeeId == '16194') {
                    return e.employeeId != '16194';
                  } else if (currentUser?.employeeId == '283') {
                    return e.employeeId == '422' || e.employeeId == '431';
                  } else if (currentUser?.employeeId == '446') {
                    return e.employeeId == '491' || e.employeeId == '540';
                  }
                  return false;
                }).toList();

                // 2. Real-time Search Field Filters
                final filteredRaw = rawList.where((m) {
                  final matchesId = _filterId.isEmpty || (m['empNo'] ?? '').toString().toLowerCase().contains(_filterId.toLowerCase());
                  final matchesName = _filterName.isEmpty || (m['name'] ?? '').toString().toLowerCase().contains(_filterName.toLowerCase());
                  final matchesRole = _filterRole.isEmpty || 
                      (m['position'] ?? '').toString().toLowerCase().contains(_filterRole.toLowerCase()) || 
                      (m['empRoll'] ?? '').toString().toLowerCase().contains(_filterRole.toLowerCase()) ||
                      (m['subgroupText'] ?? '').toString().toLowerCase().contains(_filterRole.toLowerCase());
                  final matchesDept = _filterDept.isEmpty || (m['dept'] ?? '').toString().toLowerCase().contains(_filterDept.toLowerCase());
                  final matchesStatus = _filterStatus.isEmpty || (m['status'] ?? '').toString().toLowerCase().contains(_filterStatus.toLowerCase());

                  return matchesId && matchesName && matchesRole && matchesDept && matchesStatus;
                }).toList();

                final filteredModels = modelList.where((e) {
                  final matchesId = _filterId.isEmpty || e.employeeId.toLowerCase().contains(_filterId.toLowerCase());
                  final matchesName = _filterName.isEmpty || e.name.toLowerCase().contains(_filterName.toLowerCase());
                  final matchesRole = _filterRole.isEmpty || e.designation.toLowerCase().contains(_filterRole.toLowerCase());
                  final matchesDept = _filterDept.isEmpty || e.department.toLowerCase().contains(_filterDept.toLowerCase());
                  final matchesStatus = _filterStatus.isEmpty || 'active'.contains(_filterStatus.toLowerCase());

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
                    Expanded(child: _buildFilterField('Emp ID', (v) => setState(() => _filterId = v))),
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
                        Expanded(child: _buildFilterField('Emp ID', (v) => setState(() => _filterId = v))),
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
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                    ),
                    child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 24),
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
                  const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
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
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                showCheckboxColumn: false,
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
                  DataColumn(label: Text('Emp No')),
                  DataColumn(label: Text('Employee Name')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Group')),
                  DataColumn(label: Text('Grade')),
                  DataColumn(label: Text('Position')),
                  DataColumn(label: Text('Department')),
                  DataColumn(label: Text('Basic Pay')),
                  DataColumn(label: Text('DOB')),
                  DataColumn(label: Text('Gender')),
                  DataColumn(label: Text('Mobile')),
                ],
                rows: filteredRaw.map((m) {
                  return DataRow(
                    onSelectChanged: (_) {
                      final emp = employees.firstWhere((e) => e.employeeId == m['empNo']);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EmployeeDetailScreen(employee: emp)),
                      );
                    },
                    cells: [
                      DataCell(Text(m['empNo'] ?? '')),
                      DataCell(Text(m['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(m['status'] ?? '', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 10)),
                      )),
                      DataCell(Text(m['group'] ?? '')),
                      DataCell(Text(m['subgroup'] ?? '')),
                      DataCell(Text(m['position'] ?? '')),
                      DataCell(Text(m['dept'] ?? '')),
                      DataCell(Text('Rs. ${m['basic'] ?? ''}')),
                      DataCell(Text(m['dob'] ?? '')),
                      DataCell(Text(m['gender'] ?? '')),
                      DataCell(Text(m['mobile'] ?? '')),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
