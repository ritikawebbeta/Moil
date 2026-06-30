// lib/modules/leave/screen/leave_status_screen.dart
// Matches SAP Leave Status layout: Leave Data Overview + Time Accounts Overview

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_widgets.dart';
import '../controller/leave_controller.dart';
import '../../../model/leave_model.dart';

class LeaveStatusScreen extends StatefulWidget {
  const LeaveStatusScreen({super.key});

  @override
  State<LeaveStatusScreen> createState() => _LeaveStatusScreenState();
}

class _LeaveStatusScreenState extends State<LeaveStatusScreen> {
  DateTime _showFrom = DateTime(2026, 2, 1);

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaveController>(
      builder: (context, controller, _) {
        if (controller.status == LeaveStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLeaveDataOverview(controller),
              const SizedBox(height: 16),
              _buildTimeAccountsOverview(controller),
              const SizedBox(height: 16),
              _buildLeaveApprovalPrint(),
            ],
          ),
        );
      },
    );
  }

  // ─── Leave Data Overview ─────────────────────────────────────────
  Widget _buildLeaveDataOverview(LeaveController controller) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          SectionHeader(
            title: 'Leave Data Overview',
            icon: Icons.list_alt_rounded,
            trailing: _buildNewButton(),
          ),
          // Filter Row
          _buildFilterRow(),
          // Data Table
          _buildLeaveTable(controller),
        ],
      ),
    );
  }

  Widget _buildNewButton() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(
              'New',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.backgroundTertiary,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          const Text(
            'Show from',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.inputBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: AppColors.primary, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd/MM/yyyy').format(_showFrom),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _ApplyButton(onTap: () {}),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _showFrom,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.cardBg,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _showFrom = picked);
  }

  Widget _buildLeaveTable(LeaveController controller) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header
          Container(
            color: AppColors.backgroundTertiary,
            child: Row(
              children: _tableHeaders
                  .map((h) => _TableHeaderCell(
                        text: h,
                        width: h == 'Actions'
                            ? 80
                            : (h == 'Type of Leave' ? 150 : 120),
                      ))
                  .toList(),
            ),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          // Table Rows
          if (controller.leaves.isEmpty)
            const SizedBox(
              width: 1190.0,
              height: 80,
              child: const Center(
                child: Text(
                  'No leave records found',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...controller.leaves.asMap().entries.map((e) {
              return _buildLeaveRow(e.value, e.key.isEven);
            }),
        ],
      ),
    );
  }

  static const List<String> _tableHeaders = [
    'Actions', 'Type of Leave', 'Start Date', 'Start time',
    'End Date', 'End time', 'Processor', 'Status', 'Absence hours', 'Used',
  ];

  Widget _buildLeaveRow(LeaveModel leave, bool isEven) {
    return Container(
      color: isEven
          ? AppColors.background.withOpacity(0.3)
          : Colors.transparent,
      child: Column(
        children: [
          Row(
            children: [
              // Actions
              SizedBox(
                width: 80,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Row(
                    children: [
                      _ActionIcon(
                        icon: Icons.edit_outlined,
                        color: AppColors.primary,
                        onTap: () {},
                      ),
                      const SizedBox(width: 4),
                      _ActionIcon(
                        icon: Icons.delete_outline_rounded,
                        color: AppColors.error,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ),
              // Leave Type
              _TableCell(
                child: LeaveTypeBadge(type: leave.leaveType),
                width: 150,
              ),
              // Start Date
              _TableCell(
                text: DateFormat('dd/MM/yyyy').format(leave.startDate),
                width: 120,
              ),
              // Start Time
              _TableCell(text: leave.startTime, width: 120),
              // End Date
              _TableCell(
                text: DateFormat('dd/MM/yyyy').format(leave.endDate),
                width: 120,
              ),
              // End Time
              _TableCell(text: leave.endTime, width: 120),
              // Processor
              _TableCell(text: leave.processor ?? '', width: 120),
              // Status
              _TableCell(
                child: StatusBadge(status: leave.status),
                width: 120,
              ),
              // Absence Hours
              _TableCell(
                text: leave.absenceHours != null
                    ? leave.absenceHours!.toStringAsFixed(2)
                    : '',
                width: 120,
              ),
              // Used
              _TableCell(text: leave.used ?? '', width: 120),
            ],
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
        ],
      ),
    );
  }

  // ─── Time Accounts Overview ──────────────────────────────────────
  Widget _buildTimeAccountsOverview(LeaveController controller) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Time Accounts Overview',
            icon: Icons.account_balance_wallet_outlined,
          ),
          // Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.backgroundTertiary,
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Time Account', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(width: 8),
                  const _DropdownChip(value: 'All Types', items: ['All Types', 'Earned leave', 'Casual Leave', 'HPL', 'Optional Holiday']),
                  const SizedBox(width: 16),
                  const Text('Show from', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 12),
                        SizedBox(width: 4),
                        Text('17/06/2026', style: TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ApplyButton(onTap: () {}),
                ],
              ),
            ),
          ),
          // Time Accounts Table
          _buildTimeAccountsTable(controller),
        ],
      ),
    );
  }

  Widget _buildTimeAccountsTable(LeaveController controller) {
    final headers = ['Time Account', 'Deduction from', 'Deduction to', 'Entitlement', 'Entitlement Minus Planned'];
    final widths = [160.0, 130.0, 130.0, 130.0, 180.0];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            color: AppColors.backgroundTertiary,
            child: Row(
              children: List.generate(headers.length, (i) =>
                _TableHeaderCell(text: headers[i], width: widths[i]),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          // Rows
          if (controller.balances.isEmpty)
            SizedBox(
              width: widths.reduce((a, b) => a + b),
              height: 60,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ),
            )
          else
            ...controller.balances.asMap().entries.map((e) {
              final b = e.value;
              final isEven = e.key.isEven;
              return Column(
                children: [
                  Container(
                    color: isEven ? AppColors.background.withOpacity(0.3) : Colors.transparent,
                    child: Row(
                      children: [
                        _TableCell(text: b.timeAccount, width: 160, bold: true),
                        _TableCell(text: DateFormat('dd/MM/yyyy').format(b.deductionFrom), width: 130),
                        _TableCell(text: DateFormat('dd/MM/yyyy').format(b.deductionTo), width: 130),
                        _TableCell(text: '${b.entitlement.toStringAsFixed(2)} Days', width: 130, valueColor: AppColors.success),
                        _TableCell(text: '${b.entitlementMinusPlanned.toStringAsFixed(2)} Days', width: 180, valueColor: AppColors.primary),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.cardBorder),
                ],
              );
            }),
        ],
      ),
    );
  }

  // ─── Leave Approval Print ─────────────────────────────────────────
  Widget _buildLeaveApprovalPrint() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SectionHeader(
            title: 'Leave Approval Print',
            icon: Icons.print_outlined,
            trailing: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download_rounded, size: 14),
              label: const Text('Download PDF', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
              ),
            ),
          ),
          const SizedBox(height: 60),
          const Center(
            child: Column(
              children: [
                Icon(Icons.print_disabled_outlined, color: AppColors.textHint, size: 36),
                SizedBox(height: 8),
                Text(
                  'Select a leave record to print approval',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────
class _TableHeaderCell extends StatelessWidget {
  final String text;
  final double width;
  const _TableHeaderCell({required this.text, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String? text;
  final Widget? child;
  final double width;
  final Color? valueColor;
  final bool bold;

  const _TableCell({
    this.text,
    this.child,
    required this.width,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: child ??
          Text(
            text ?? '',
            style: TextStyle(
              color: valueColor ?? AppColors.textPrimary,
              fontSize: 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ApplyButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: const Text(
          'Apply',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DropdownChip extends StatefulWidget {
  final String value;
  final List<String> items;
  const _DropdownChip({required this.value, required this.items});

  @override
  State<_DropdownChip> createState() => _DropdownChipState();
}

class _DropdownChipState extends State<_DropdownChip> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: DropdownButton<String>(
        value: _selected,
        isDense: true,
        underline: const SizedBox(),
        dropdownColor: AppColors.cardBg,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 16),
        items: widget.items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: (v) => setState(() => _selected = v!),
      ),
    );
  }
}
