import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_widgets.dart';
import '../utils/payslip_pdf_helper.dart';
import '../../auth/controller/auth_controller.dart';
import '../../profile/controller/profile_controller.dart';
import '../../leave/controller/leave_controller.dart';
class PayslipScreen extends StatefulWidget {
  const PayslipScreen({super.key});

  @override
  State<PayslipScreen> createState() => _PayslipScreenState();
}

class _PayslipScreenState extends State<PayslipScreen> {
  final List<Map<String, dynamic>> _payslips = [
    {'month': 'May 2026', 'gross': 185492.50, 'deductions': 46274.00, 'net': 139218.50, 'status': 'Available'},
    {'month': 'April 2026', 'gross': 185492.50, 'deductions': 46274.00, 'net': 139218.50, 'status': 'Available'},
    {'month': 'March 2026', 'gross': 185492.50, 'deductions': 45800.00, 'net': 139692.50, 'status': 'Available'},
    {'month': 'February 2026', 'gross': 185492.50, 'deductions': 46274.00, 'net': 139218.50, 'status': 'Available'},
    {'month': 'January 2026', 'gross': 185492.50, 'deductions': 46000.00, 'net': 139492.50, 'status': 'Available'},
    {'month': 'December 2025', 'gross': 180000.00, 'deductions': 45000.00, 'net': 135000.00, 'status': 'Available'},
  ];

  late String _selectedMonth;
  String _historyFilterYear = 'All';

  @override
  void initState() {
    super.initState();
    _selectedMonth = _payslips.first['month'];
  }

  String _formatCurrency(double val) {
    final format = NumberFormat.currency(locale: 'HI', symbol: '₹', decimalDigits: 0);
    return format.format(val);
  }

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
    final payslip = _payslips.firstWhere((p) => p['month'] == _selectedMonth);
    
    final auth = context.read<AuthController>();
    final cleanId = (auth.user?.employeeId ?? (ProfileController.rawEmployees.isNotEmpty ? ProfileController.rawEmployees.first['empNo']?.toString() : '') ?? '').trim().replaceAll(RegExp('^0+'), '');
    final Map<String, dynamic> raw = ProfileController.rawEmployees.firstWhere(
      (e) => e['empNo'] == cleanId,
      orElse: () => ProfileController.rawEmployees.isNotEmpty ? ProfileController.rawEmployees.first : <String, dynamic>{},
    );
    final double basic = double.tryParse(raw['basic'].toString().replaceAll(',', '')) ?? 100000.00;
    final double da = basic * 0.50;
    final double hra = basic * 0.15;
    final double otherPerks = payslip['gross'] - basic - da - hra;
    
    final double pf = (payslip['deductions'] * 16404.0 / 46274.00);
    final double it = (payslip['deductions'] * 22420.0 / 46274.00);
    final double otherDeductions = payslip['deductions'] - pf - it;
    final double remainingDeductions = otherDeductions - 200.00;

    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 600;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Salary Summary',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedMonth,
                    dropdownColor: AppColors.cardBg,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                    items: _payslips.map((p) {
                      return DropdownMenuItem<String>(
                        value: p['month'],
                        child: Text(p['month']),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedMonth = val;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SalaryCard(
                  label: 'Gross Salary',
                  amount: _formatCurrency(payslip['gross']),
                  color: AppColors.success,
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SalaryCard(
                  label: 'Deductions',
                  amount: _formatCurrency(payslip['deductions']),
                  color: AppColors.error,
                  icon: Icons.remove_circle_outline,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SalaryCard(
                  label: 'Net Pay',
                  amount: _formatCurrency(payslip['net']),
                  color: AppColors.primary,
                  icon: Icons.payments_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.cardBorder),
          const SizedBox(height: 12),
          if (isMobile)
            Column(
              children: [
                _buildMobileBreakdownRow('Basic Pay - Exe & NE', _formatCurrency(basic)),
                _buildMobileBreakdownRow('Dearness Allow - Exe & NE', _formatCurrency(da)),
                _buildMobileBreakdownRow('House Rent Allow E&NE', _formatCurrency(hra)),
                _buildMobileBreakdownRow('Other Perks', _formatCurrency(otherPerks)),
                _buildMobileBreakdownRow('Ee PF contribution', '-${_formatCurrency(pf)}', isDeduction: true),
                _buildMobileBreakdownRow('Prof Tax', '-₹ 200.00', isDeduction: true),
                _buildMobileBreakdownRow('Income Tax', '-${_formatCurrency(it)}', isDeduction: true),
                _buildMobileBreakdownRow('Other Deductions', '-${_formatCurrency(remainingDeductions)}', isDeduction: true),
              ],
            )
          else
            Table(
              border: TableBorder.all(color: AppColors.cardBorder, width: 0.5),
              columnWidths: const {
                0: FlexColumnWidth(2.5),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(2.5),
                3: FlexColumnWidth(1.2),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                  children: [
                    _tableCell('Earnings / अर्जन', bold: true, align: TextAlign.center),
                    _tableCell('Amount (₹)', bold: true, align: TextAlign.center),
                    _tableCell('Deductions / कटौतियाँ', bold: true, align: TextAlign.center),
                    _tableCell('Amount (₹)', bold: true, align: TextAlign.center),
                  ],
                ),
                TableRow(children: [
                  _tableCell('Basic Pay - Exe & NE\nमूल वेतन'),
                  _tableCell(_formatCurrency(basic), align: TextAlign.right),
                  _tableCell('Ee PF contribution\nकर्मचारी PF अंशदान'),
                  _tableCell(_formatCurrency(pf), align: TextAlign.right),
                ]),
                TableRow(children: [
                  _tableCell('Dearness Allow - Exe & NE\nमहंगाई भत्ता-दिव्या'),
                  _tableCell(_formatCurrency(da), align: TextAlign.right),
                  _tableCell('Prof Tax - split period\nवृत्ति कर - विभाजन अवधि'),
                  _tableCell('₹ 200.00', align: TextAlign.right),
                ]),
                TableRow(children: [
                  _tableCell('House Rent Allow E&NE\nमकान किराया भत्ता'),
                  _tableCell(_formatCurrency(hra), align: TextAlign.right),
                  _tableCell('Income Tax\nआयकर'),
                  _tableCell(_formatCurrency(it), align: TextAlign.right),
                ]),
                TableRow(children: [
                  _tableCell('Other Perks\nअन्य भत्ते'),
                  _tableCell(_formatCurrency(otherPerks), align: TextAlign.right),
                  _tableCell('Credit Society Share\nक्रेडिट सोसायटी शेयर'),
                  _tableCell(_formatCurrency(remainingDeductions * 0.8), align: TextAlign.right),
                ]),
                TableRow(children: [
                  _tableCell(''),
                  _tableCell(''),
                  _tableCell('Furn & Fixture Recovery\nफर्निचर और फिक्सचर रिकव'),
                  _tableCell(_formatCurrency(remainingDeductions * 0.1), align: TextAlign.right),
                ]),
                TableRow(children: [
                  _tableCell(''),
                  _tableCell(''),
                  _tableCell('MEA Subscription fees\nएमईए सदस्यता शुल्क'),
                  _tableCell(_formatCurrency(remainingDeductions * 0.05), align: TextAlign.right),
                ]),
                TableRow(children: [
                  _tableCell(''),
                  _tableCell(''),
                  _tableCell('Benevolent Fund\nपरोपकार निधि'),
                  _tableCell(_formatCurrency(remainingDeductions * 0.05), align: TextAlign.right),
                ]),
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xFFE2E8F0)),
                  children: [
                    _tableCell('Total Earnings / कुल अर्जन', bold: true),
                    _tableCell(_formatCurrency(payslip['gross']), bold: true, align: TextAlign.right),
                    _tableCell('Total Deductions / कुल कटौतियाँ', bold: true),
                    _tableCell(_formatCurrency(payslip['deductions']), bold: true, align: TextAlign.right),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMobileBreakdownRow(String label, String value, {bool isDeduction = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          Text(
            value,
            style: TextStyle(
              color: isDeduction ? AppColors.error : AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool bold = false, TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 10,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildPayslipList() {
    final filteredHistory = _payslips.where((p) {
      if (_historyFilterYear == 'All') return true;
      return p['month'].contains(_historyFilterYear);
    }).toList();

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: SectionHeader(title: 'Payslip History', icon: Icons.receipt_long_outlined),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _historyFilterYear,
                      dropdownColor: AppColors.cardBg,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Years')),
                        DropdownMenuItem(value: '2026', child: Text('2026')),
                        DropdownMenuItem(value: '2025', child: Text('2025')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _historyFilterYear = val;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          ...filteredHistory.asMap().entries.map((e) {
            final p = e.value;
            final isEven = e.key.isEven;
            return Column(
              children: [
                Container(
                  color: isEven ? AppColors.background.withOpacity(0.3) : Colors.transparent,
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
                            Text('Net: ${_formatCurrency(p['net'])}', style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download_rounded, color: AppColors.primary),
                        onPressed: () => _downloadPayslip(p),
                        tooltip: 'Download PDF',
                      ),
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, color: AppColors.textSecondary),
                        onPressed: () => _viewPayslip(p),
                        tooltip: 'View Layout',
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

  void _downloadPayslip(Map<String, dynamic> payslip) {
    final auth = context.read<AuthController>();
    PayslipPdfHelper.printPayslipPdf(
      payslip['month'],
      employeeId: auth.user?.employeeId,
      gross: payslip['gross'],
      deductions: payslip['deductions'],
    );
  }

  void _viewPayslip(Map<String, dynamic> payslip) {
    final auth = context.read<AuthController>();
    showDialog(
      context: context,
      builder: (context) {
        double zoomWidth = 600.0;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                height: MediaQuery.of(context).size.height * 0.8,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('View Payslip - ${payslip['month']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.zoom_out, color: AppColors.primary),
                              onPressed: () {
                                setState(() {
                                  if (zoomWidth > 300.0) zoomWidth -= 100.0;
                                });
                              },
                              tooltip: 'Zoom Out',
                            ),
                            IconButton(
                              icon: const Icon(Icons.zoom_in, color: AppColors.primary),
                              onPressed: () {
                                setState(() {
                                  if (zoomWidth < 1200.0) zoomWidth += 100.0;
                                });
                              },
                              tooltip: 'Zoom In',
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textSecondary),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final balances = context.read<LeaveController>().balances;
                          double elVal = 0.0;
                          double clVal = 0.0;
                          double hplVal = 0.0;
                          for (final b in balances) {
                            if (b.timeAccount.toLowerCase().contains('earned')) {
                              elVal = b.entitlementMinusPlanned;
                            } else if (b.timeAccount.toLowerCase().contains('casual')) {
                              clVal = b.entitlementMinusPlanned;
                            } else if (b.timeAccount.toLowerCase().contains('hpl') || b.timeAccount.toLowerCase().contains('half')) {
                              hplVal = b.entitlementMinusPlanned;
                            }
                          }
                          return PdfPreview(
                            build: (format) => PayslipPdfHelper.generatePayslipPdfBytes(
                              payslip['month'],
                              employeeId: auth.user?.employeeId,
                              gross: payslip['gross'],
                              deductions: payslip['deductions'],
                              elBalance: elVal,
                              clBalance: clVal,
                              hplBalance: hplVal,
                            ),
                            maxPageWidth: zoomWidth,
                            allowPrinting: true,
                            allowSharing: true,
                            canChangePageFormat: false,
                            canChangeOrientation: false,
                            canDebug: false,
                            initialPageFormat: PdfPageFormat.a4,
                          );
                        }
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(amount, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
