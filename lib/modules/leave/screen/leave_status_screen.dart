// lib/modules/leave/screen/leave_status_screen.dart
// Matches SAP Leave Status layout: Leave Data Overview + Time Accounts Overview

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  DateTime? _tempShowFrom;
  String? _tempTimeAccount;
  DateTime? _tempTimeAccountShowFrom;

  Future<void> _printLeavePdf(LeaveModel leave) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'MOIL LIMITED',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF0F2080)),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'LEAVE APPLICATION REQUISITION SHEET',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, decoration: pw.TextDecoration.underline),
                  ),
                ),
                pw.SizedBox(height: 30),
                _buildPdfRow('Leave ID:', leave.id),
                _buildPdfRow('Employee ID:', leave.employeeId),
                _buildPdfRow('Leave Type:', leave.leaveType),
                _buildPdfRow('Duration:', leave.duration),
                _buildPdfRow('Start Date:', DateFormat('dd-MM-yyyy').format(leave.startDate)),
                _buildPdfRow('End Date:', DateFormat('dd-MM-yyyy').format(leave.endDate)),
                _buildPdfRow('Absence Hours:', leave.absenceHours?.toStringAsFixed(2) ?? 'N/A'),
                _buildPdfRow('Used Days:', leave.used ?? 'N/A'),
                _buildPdfRow('Reason:', leave.reason ?? 'N/A'),
                _buildPdfRow('Status:', leave.status),
                _buildPdfRow('Processor:', leave.processor ?? 'N/A'),
                pw.Divider(height: 20),
                _buildPdfRow('Applied Time:', leave.appliedOn != null ? DateFormat('dd-MM-yyyy HH:mm').format(leave.appliedOn!) : 'N/A'),
                _buildPdfRow('Approval Time:', leave.approvedOn != null ? DateFormat('dd-MM-yyyy HH:mm').format(leave.approvedOn!) : 'N/A'),
                _buildPdfRow('Approver Comments:', leave.remarks ?? 'N/A'),
                pw.SizedBox(height: 50),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Container(width: 120, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 5),
                        pw.Text('Employee Signature', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Container(width: 120, height: 1, color: PdfColors.black),
                        pw.SizedBox(height: 5),
                        pw.Text('Approving Authority Signature', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Leave_Application_${leave.id}.pdf',
    );
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(width: 150, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))),
          pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  void _viewLeaveDetails(LeaveModel leave) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Leave Request Details',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    StatusBadge(status: leave.status),
                  ],
                ),
                const Divider(height: 24, color: AppColors.cardBorder),
                _buildDetailRow('Leave Type', leave.leaveType),
                _buildDetailRow('Duration', leave.duration),
                _buildDetailRow(
                  'Date Range',
                  '${DateFormat('dd-MM-yyyy').format(leave.startDate)} to ${DateFormat('dd-MM-yyyy').format(leave.endDate)}',
                ),
                _buildDetailRow('Used Days / Hours', '${leave.used ?? 'N/A'} (${leave.absenceHours?.toStringAsFixed(2) ?? '0.00'} Hrs)'),
                _buildDetailRow('Reason', leave.reason ?? 'N/A'),
                const Divider(height: 24, color: AppColors.cardBorder),
                _buildDetailRow(
                  'Applied Time',
                  leave.appliedOn != null ? DateFormat('dd-MM-yyyy HH:mm:ss').format(leave.appliedOn!) : 'N/A',
                ),
                _buildDetailRow(
                  'Approval Time',
                  leave.approvedOn != null ? DateFormat('dd-MM-yyyy HH:mm:ss').format(leave.approvedOn!) : 'N/A',
                ),
                _buildDetailRow('Approving Authority Remarks', leave.remarks ?? 'No remarks provided'),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Print Requisition Form',
                  icon: Icons.print_rounded,
                  onPressed: () {
                    Navigator.pop(context);
                    _printLeavePdf(leave);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaveController>(
      builder: (context, controller, _) {
        if (controller.status == LeaveStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        _tempShowFrom ??= controller.showFrom;
        _tempTimeAccount ??= controller.selectedTimeAccount;
        _tempTimeAccountShowFrom ??= controller.timeAccountShowFrom;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLeaveDataOverview(controller),
              const SizedBox(height: 16),
              _buildTimeAccountsOverview(controller),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header
          SectionHeader(
            title: 'Leave Data Overview',
            icon: Icons.list_alt_rounded,
            trailing: _buildNewButton(),
          ),
          // Filter Row
          _buildFilterRow(controller),
          // Data Table
          _buildLeaveTable(controller),
        ],
      ),
    );
  }

  Widget _buildNewButton() {
    return GestureDetector(
      onTap: () {
        context.read<LeaveController>().setActiveTabIndex(2);
      },
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

  Widget _buildFilterRow(LeaveController controller) {
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
            onTap: () => _pickDate(controller),
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
                    DateFormat('dd-MM-yyyy').format(_tempShowFrom!),
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
          _ApplyButton(onTap: () {
            controller.updateShowFrom(_tempShowFrom!);
          }),
        ],
      ),
    );
  }

  Future<void> _pickDate(LeaveController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempShowFrom ?? controller.showFrom,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 10),
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
    if (picked != null) {
      setState(() {
        _tempShowFrom = picked;
      });
    }
  }

  Widget _buildLeaveTable(LeaveController controller) {
    final filteredLeaves = controller.leaves.where((leave) {
      return !leave.startDate.isBefore(controller.showFrom);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth > 1430 ? constraints.maxWidth : 1430.0;
        final extraWidth = totalWidth - 1430.0;
        
        final actionsWidth = 80.0;
        final typeWidth = 150.0 + extraWidth * 0.2;
        final otherWidth = 120.0 + extraWidth * 0.8 / 10;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Table Header
              Container(
                color: AppColors.backgroundTertiary,
                child: Row(
                  children: [
                    _TableHeaderCell(text: 'Actions', width: actionsWidth),
                    _TableHeaderCell(text: 'Type of Leave', width: typeWidth),
                    _TableHeaderCell(text: 'Start Date', width: otherWidth),
                    _TableHeaderCell(text: 'Start time', width: otherWidth),
                    _TableHeaderCell(text: 'End Date', width: otherWidth),
                    _TableHeaderCell(text: 'End time', width: otherWidth),
                    _TableHeaderCell(text: 'Applied Time', width: otherWidth),
                    _TableHeaderCell(text: 'Approve Time', width: otherWidth),
                    _TableHeaderCell(text: 'Processor', width: otherWidth),
                    _TableHeaderCell(text: 'Status', width: otherWidth),
                    _TableHeaderCell(text: 'Absence hours', width: otherWidth),
                    _TableHeaderCell(text: 'Used', width: otherWidth),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.cardBorder),
              // Table Rows
              if (filteredLeaves.isEmpty)
                SizedBox(
                  width: totalWidth,
                  height: 80,
                  child: const Center(
                    child: Text(
                      'No leave records found',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...filteredLeaves.asMap().entries.map((e) {
                  final leave = e.value;
                  final isEven = e.key.isEven;
                  return Container(
                    width: totalWidth,
                    color: isEven
                        ? AppColors.background.withOpacity(0.3)
                        : Colors.transparent,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: actionsWidth,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                child: Row(
                                  children: [
                                    _ActionIcon(
                                      icon: Icons.visibility_outlined,
                                      color: AppColors.primary,
                                      onTap: () => _viewLeaveDetails(leave),
                                    ),
                                    const SizedBox(width: 6),
                                    _ActionIcon(
                                      icon: Icons.print_outlined,
                                      color: AppColors.primary,
                                      onTap: () => _printLeavePdf(leave),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            _TableCell(
                              child: LeaveTypeBadge(type: leave.leaveType),
                              width: typeWidth,
                            ),
                            _TableCell(
                              text: DateFormat('dd-MM-yyyy').format(leave.startDate),
                              width: otherWidth,
                            ),
                            _TableCell(text: leave.startTime, width: otherWidth),
                            _TableCell(
                              text: DateFormat('dd-MM-yyyy').format(leave.endDate),
                              width: otherWidth,
                            ),
                            _TableCell(text: leave.endTime, width: otherWidth),
                            _TableCell(
                              text: leave.appliedOn != null
                                  ? DateFormat('dd-MM-yyyy HH:mm').format(leave.appliedOn!)
                                  : 'N/A',
                              width: otherWidth,
                            ),
                            _TableCell(
                              text: leave.approvedOn != null
                                  ? DateFormat('dd-MM-yyyy HH:mm').format(leave.approvedOn!)
                                  : 'N/A',
                              width: otherWidth,
                            ),
                            _TableCell(text: leave.processor ?? '', width: otherWidth),
                            _TableCell(
                              child: StatusBadge(status: leave.status),
                              width: otherWidth,
                            ),
                            _TableCell(
                              text: leave.absenceHours != null
                                  ? leave.absenceHours!.toStringAsFixed(2)
                                  : '',
                              width: otherWidth,
                            ),
                            _TableCell(text: leave.used ?? '', width: otherWidth),
                          ],
                        ),
                        const Divider(height: 1, color: AppColors.cardBorder),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  // ─── Time Accounts Overview ──────────────────────────────────────
  Widget _buildTimeAccountsOverview(LeaveController controller) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Time Accounts Overview',
            icon: Icons.account_balance_wallet_outlined,
          ),
          // Filter
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.backgroundTertiary,
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Time Account', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(width: 8),
                  _DropdownChip(
                    value: _tempTimeAccount!,
                    items: const ['All Types', 'Earned leave', 'Casual Leave', 'HPL', 'Optional Holiday'],
                    onChanged: (v) {
                      setState(() {
                        _tempTimeAccount = v;
                      });
                    },
                  ),
                  const SizedBox(width: 16),
                  const Text('Show from', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _pickTimeAccountDate(controller),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 12),
                          const SizedBox(width: 4),
                          Text(DateFormat('dd-MM-yyyy').format(_tempTimeAccountShowFrom!), style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ApplyButton(onTap: () {
                    controller.updateSelectedTimeAccount(_tempTimeAccount!);
                    controller.updateTimeAccountShowFrom(_tempTimeAccountShowFrom!);
                  }),
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

  Future<void> _pickTimeAccountDate(LeaveController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tempTimeAccountShowFrom ?? controller.timeAccountShowFrom,
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
        _tempTimeAccountShowFrom = picked;
      });
    }
  }

  Widget _buildTimeAccountsTable(LeaveController controller) {
    final filteredBalances = controller.balances.where((b) {
      final matchesType = controller.selectedTimeAccount == 'All Types' || b.timeAccount.toLowerCase() == controller.selectedTimeAccount.toLowerCase();
      final matchesDate = !b.deductionTo.isBefore(controller.timeAccountShowFrom);
      return matchesType && matchesDate;
    }).toList();

    final colWidths = [160.0, 130.0, 130.0, 130.0, 180.0];
    final baseTotal = colWidths.reduce((a, b) => a + b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth > baseTotal ? constraints.maxWidth : baseTotal;
        final extraWidth = totalWidth - baseTotal;
        
        final col0 = 160.0 + extraWidth * 0.4;
        final col1 = 130.0 + extraWidth * 0.15;
        final col2 = 130.0 + extraWidth * 0.15;
        final col3 = 130.0 + extraWidth * 0.15;
        final col4 = 180.0 + extraWidth * 0.15;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                color: AppColors.backgroundTertiary,
                child: Row(
                  children: [
                    _TableHeaderCell(text: 'Time Account', width: col0),
                    _TableHeaderCell(text: 'Deduction from', width: col1),
                    _TableHeaderCell(text: 'Deduction to', width: col2),
                    _TableHeaderCell(text: 'Entitlement', width: col3),
                    _TableHeaderCell(text: 'Entitlement Minus Planned', width: col4),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.cardBorder),
              // Rows
              if (filteredBalances.isEmpty)
                SizedBox(
                  width: totalWidth,
                  height: 60,
                  child: const Center(
                    child: Text(
                      'No matching records found',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ),
                )
              else
                ...filteredBalances.asMap().entries.map((e) {
                  final b = e.value;
                  final isEven = e.key.isEven;
                  return Column(
                    children: [
                      Container(
                        width: totalWidth,
                        color: isEven ? AppColors.background.withOpacity(0.3) : Colors.transparent,
                        child: Row(
                          children: [
                            _TableCell(
                              width: col0,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _getLeaveColor(b.timeAccount),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      b.timeAccount,
                                      style: TextStyle(
                                        color: _getLeaveColor(b.timeAccount),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _TableCell(text: DateFormat('dd-MM-yyyy').format(b.deductionFrom), width: col1),
                            _TableCell(text: DateFormat('dd-MM-yyyy').format(b.deductionTo), width: col2),
                            _TableCell(text: '${b.entitlement.toStringAsFixed(2)} Days', width: col3, valueColor: AppColors.success),
                            _TableCell(text: '${b.entitlementMinusPlanned.toStringAsFixed(2)} Days', width: col4, valueColor: AppColors.primary),
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
      },
    );
  }

  Color _getLeaveColor(String type) {
    switch (type.toLowerCase()) {
      case 'earned leave':
        return AppColors.earnedLeave;
      case 'casual leave':
        return AppColors.casualLeave;
      case 'hpl':
        return AppColors.hpl;
      case 'optional holiday':
        return AppColors.optionalHoliday;
      default:
        return AppColors.primary;
    }
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
  final ValueChanged<String>? onChanged;
  const _DropdownChip({required this.value, required this.items, this.onChanged});

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
  void didUpdateWidget(covariant _DropdownChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _selected = widget.value;
    }
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
        onChanged: (v) {
          if (v != null) {
            setState(() => _selected = v);
            if (widget.onChanged != null) widget.onChanged!(v);
          }
        },
      ),
    );
  }
}
