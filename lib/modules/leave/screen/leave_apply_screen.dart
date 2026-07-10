// lib/modules/leave/screen/leave_apply_screen.dart
// Matches SAP Leave Applied form: Type of Leave + General Data

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_widgets.dart';
import '../../auth/controller/auth_controller.dart';
import '../../leave/controller/leave_controller.dart';
import '../../../model/leave_model.dart';

class LeaveApplyScreen extends StatefulWidget {
  const LeaveApplyScreen({super.key});

  @override
  State<LeaveApplyScreen> createState() => _LeaveApplyScreenState();
}

class _LeaveApplyScreenState extends State<LeaveApplyScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form values
  String _selectedLeaveType = 'Earned leave';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _beginTime = '00:00';
  String _endTime = '00:00';
  String _duration = 'Full-Day';
  String _processor = 'Manish M Malewar';
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _leaveTypes = [
    'Earned leave',
    'Casual Leave',
    'HPL',
    'CHPL',
    'Medical Leave - App.',
    'Study leave',
    'Maternity Leave',
    'LWP',
    'Authorised LWP (Sick)',
    'Special leave',
    'Optional/Restricted Holid',
    'Special Sick Payment 100',
    'Transit Leave',
    'C-off',
    'Spl Sick 100',
    'Spl Sick 50%',
    'Spl Sick 25%',
    'Late Coming - CL',
    'Late Coming - EL',
    'Vocational Training',
    'Nursing Attendance',
    'Medical Leave GT/MT/NT',
    '1/2day LWP',
    'Paternity Leave',
    'Injured On Duty',
    'Sports Injury',
    'Casual Leave GT/MT/NT',
    'Suspension Absence (50%)',
    'Suspension Absence (75%)',
    'Suspension Absence (100%)',
    'Casual Leave - Consultant',
    'Optional Leave - Consult',
    'Authorised LWP',
  ];

  final List<String> _durations = ['Full-Day', 'Half-Day'];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTypeOfLeaveSection(),
            const SizedBox(height: 16),
            _buildGeneralDataSection(),
            const SizedBox(height: 20),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // ─── Type of Leave ────────────────────────────────────────────────
  Widget _buildTypeOfLeaveSection() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Type of Leave',
            icon: Icons.category_outlined,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Leave Type Dropdown
                _buildFormRow(
                  label: 'Type of Leave',
                  isRequired: true,
                  child: DropdownButtonFormField<String>(
                    value: _selectedLeaveType,
                    dropdownColor: AppColors.cardBg,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                    items: _leaveTypes
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedLeaveType = v!),
                  ),
                ),
                const SizedBox(height: 12),
                // Description
                _buildFormRow(
                  label: 'Description',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Text(
                      _selectedLeaveType,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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

  // ─── General Data ─────────────────────────────────────────────────
  Widget _buildGeneralDataSection() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'General Data',
            icon: Icons.info_outline_rounded,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Start Date
                _buildFormRow(
                  label: 'Start Date',
                  isRequired: true,
                  child: GestureDetector(
                    onTap: () => _pickDate(true),
                    child: _DateField(
                      value: DateFormat('dd-MM-yyyy').format(_startDate),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // End Date
                _buildFormRow(
                  label: 'End Date',
                  isRequired: true,
                  child: GestureDetector(
                    onTap: () => _pickDate(false),
                    child: _DateField(
                      value: DateFormat('dd-MM-yyyy').format(_endDate),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Begin Time
                _buildFormRow(
                  label: 'Begin Time',
                  child: _TimeField(
                    value: _beginTime,
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(height: 12),
                // End Time
                _buildFormRow(
                  label: 'End Time',
                  child: _TimeField(
                    value: _endTime,
                    onTap: () => _pickTime(false),
                  ),
                ),
                const SizedBox(height: 12),
                // Leave Duration
                _buildFormRow(
                  label: 'Leave Duration',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _durations.map((d) {
                      final isSelected = d == _duration;
                      return GestureDetector(
                        onTap: () => setState(() => _duration = d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.inputBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.inputBorder,
                            ),
                          ),
                          child: Text(
                            d,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                // Processor
                _buildFormRow(
                  label: 'Processor',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _processor,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                        const Icon(Icons.search, color: AppColors.textSecondary, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // New Note
                _buildFormRow(
                  label: 'New Note',
                  child: TextFormField(
                    controller: _noteController,
                    maxLines: 4,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Enter reason or remarks...',
                      contentPadding: EdgeInsets.all(12),
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

  Widget _buildFormRow({
    required String label,
    required Widget child,
    bool isRequired = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          child: RichText(
            textAlign: TextAlign.right,
            text: TextSpan(
              children: [
                if (isRequired)
                  const TextSpan(
                    text: '* ',
                    style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                TextSpan(
                  text: label,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: child),
      ],
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 10),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.cardBg,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(picked)) _endDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime(bool isBegin) async {
    final current = isBegin ? _beginTime : _endTime;
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.cardBg,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isBegin) _beginTime = formatted;
        else _endTime = formatted;
      });
    }
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Consumer<LeaveController>(
          builder: (context, controller, _) {
            return PrimaryButton(
              label: 'Submit Leave Request',
              icon: Icons.send_rounded,
              isLoading: _isSubmitting,
              onPressed: _submit,
            );
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _resetForm,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Reset Form'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.cardBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final auth = context.read<AuthController>();
    final request = LeaveApplicationRequest(
      employeeId: auth.user?.employeeId ?? '',
      leaveType: _selectedLeaveType,
      startDate: _startDate,
      endDate: _endDate,
      beginTime: _beginTime,
      endTime: _endTime,
      duration: _duration,
      processor: _processor,
      note: _noteController.text.isNotEmpty ? _noteController.text : null,
    );

    final success = await context.read<LeaveController>().applyLeave(request);

    setState(() => _isSubmitting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Leave request submitted successfully!'
                : 'Failed to submit leave request. Please try again.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      if (success) _resetForm();
    }
  }

  void _resetForm() {
    setState(() {
      _selectedLeaveType = 'Earned leave';
      _startDate = DateTime.now();
      _endDate = DateTime.now();
      _beginTime = '00:00';
      _endTime = '00:00';
      _duration = 'Full-Day';
      _noteController.clear();
    });
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────
class _DateField extends StatelessWidget {
  final String value;
  const _DateField({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
          const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 16),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String value;
  final VoidCallback onTap;
  const _TimeField({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            const Icon(Icons.access_time_rounded, color: AppColors.primary, size: 16),
          ],
        ),
      ),
    );
  }
}
