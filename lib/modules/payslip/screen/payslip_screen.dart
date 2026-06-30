import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_widgets.dart';

class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  final List<Map<String, dynamic>> _payslips = [
    {'month': 'May 2026', 'gross': 85000.0, 'deductions': 12500.0, 'net': 72500.0, 'status': 'Available'},
    {'month': 'April 2026', 'gross': 85000.0, 'deductions': 12500.0, 'net': 72500.0, 'status': 'Available'},
    {'month': 'March 2026', 'gross': 85000.0, 'deductions': 11800.0, 'net': 73200.0, 'status': 'Available'},
    {'month': 'February 2026', 'gross': 85000.0, 'deductions': 12500.0, 'net': 72500.0, 'status': 'Available'},
    {'month': 'January 2026', 'gross': 85000.0, 'deductions': 12000.0, 'net': 73000.0, 'status': 'Available'},
    {'month': 'December 2025', 'gross': 80000.0, 'deductions': 12000.0, 'net': 68000.0, 'status': 'Available'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Payslip',
        showBack: Navigator.of(context).canPop(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSalaryOverview(),
            const SizedBox(height: 16),
            _buildPayslipList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryOverview() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Latest Salary Summary', style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Text('May 2026', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _SalaryCard(
                label: 'Gross Salary',
                amount: '₹85,000',
                color: AppColors.success,
                icon: Icons.account_balance_wallet_outlined,
              )),
              const SizedBox(width: 12),
              Expanded(child: _SalaryCard(
                label: 'Deductions',
                amount: '₹12,500',
                color: AppColors.error,
                icon: Icons.remove_circle_outline,
              )),
              const SizedBox(width: 12),
              Expanded(child: _SalaryCard(
                label: 'Net Pay',
                amount: '₹72,500',
                color: AppColors.primary,
                icon: Icons.payments_outlined,
              )),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.cardBorder),
          const SizedBox(height: 12),
          _buildBreakdownRow('Basic Salary', '₹50,000'),
          _buildBreakdownRow('HRA', '₹20,000'),
          _buildBreakdownRow('Allowances', '₹15,000'),
          _buildBreakdownRow('PF Deduction', '-₹6,000', isDeduction: true),
          _buildBreakdownRow('Income Tax', '-₹4,500', isDeduction: true),
          _buildBreakdownRow('Professional Tax', '-₹2,000', isDeduction: true),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isDeduction = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: isDeduction ? AppColors.error : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayslipList() {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const SectionHeader(title: 'Payslip History', icon: Icons.receipt_long_outlined),
          ..._payslips.asMap().entries.map((e) {
            final p = e.value;
            return Column(
              children: [
                Container(
                  color: e.key.isEven ? AppColors.background.withOpacity(0.3) : Colors.transparent,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p['month'], style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                            Text('Net: ₹${(p['net'] as double).toStringAsFixed(0)}', style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download_rounded, color: AppColors.primary),
                        onPressed: () => _downloadPayslip(p['month']),
                        tooltip: 'Download PDF',
                      ),
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, color: AppColors.textSecondary),
                        onPressed: () => _viewPayslip(p),
                        tooltip: 'View',
                      ),
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

  void _downloadPayslip(String month) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Downloading payslip for $month...'),
      backgroundColor: AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _viewPayslip(Map<String, dynamic> payslip) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(payslip['month'], style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            const Divider(color: AppColors.cardBorder),
            _buildBreakdownRow('Gross Salary', '₹${(payslip['gross'] as double).toStringAsFixed(0)}'),
            _buildBreakdownRow('Total Deductions', '-₹${(payslip['deductions'] as double).toStringAsFixed(0)}', isDeduction: true),
            const Divider(color: AppColors.cardBorder),
            _buildBreakdownRow('Net Pay', '₹${(payslip['net'] as double).toStringAsFixed(0)}'),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Download PDF',
              icon: Icons.download_rounded,
              onPressed: () {
                Navigator.pop(context);
                _downloadPayslip(payslip['month']);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SalaryCard extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  const _SalaryCard({required this.label, required this.amount, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(amount, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 9), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
