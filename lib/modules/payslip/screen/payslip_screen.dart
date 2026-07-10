import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_colors.dart';
import '../../../widgets/app_widgets.dart';
import '../utils/payslip_pdf_helper.dart';

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
    
    // Proportional breakdown calculations
    final double basic = (payslip['gross'] * 88710.0 / 185492.50);
    final double da = (payslip['gross'] * 47992.0 / 185492.50);
    final double hra = (payslip['gross'] * 17742.0 / 185492.50);
    final double otherPerks = payslip['gross'] - basic - da - hra;
    
    final double pf = (payslip['deductions'] * 16404.0 / 46274.00);
    final double it = (payslip['deductions'] * 22420.0 / 46274.00);
    final double otherDeductions = payslip['deductions'] - pf - it;

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
          if (isMobile)
            Column(
              children: [
                _SalaryCard(
                  label: 'Gross Salary',
                  amount: _formatCurrency(payslip['gross']),
                  color: AppColors.success,
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(height: 12),
                _SalaryCard(
                  label: 'Deductions',
                  amount: _formatCurrency(payslip['deductions']),
                  color: AppColors.error,
                  icon: Icons.remove_circle_outline,
                ),
                const SizedBox(height: 12),
                _SalaryCard(
                  label: 'Net Pay',
                  amount: _formatCurrency(payslip['net']),
                  color: AppColors.primary,
                  icon: Icons.payments_outlined,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(child: _SalaryCard(
                  label: 'Gross Salary',
                  amount: _formatCurrency(payslip['gross']),
                  color: AppColors.success,
                  icon: Icons.account_balance_wallet_outlined,
                )),
                const SizedBox(width: 12),
                Expanded(child: _SalaryCard(
                  label: 'Deductions',
                  amount: _formatCurrency(payslip['deductions']),
                  color: AppColors.error,
                  icon: Icons.remove_circle_outline,
                )),
                const SizedBox(width: 12),
                Expanded(child: _SalaryCard(
                  label: 'Net Pay',
                  amount: _formatCurrency(payslip['net']),
                  color: AppColors.primary,
                  icon: Icons.payments_outlined,
                )),
              ],
            ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.cardBorder),
          const SizedBox(height: 12),
          _buildBreakdownRow('Basic Pay - Exe & NE', _formatCurrency(basic)),
          _buildBreakdownRow('Dearness Allow - Exe & NE', _formatCurrency(da)),
          _buildBreakdownRow('House Rent Allow E&NE', _formatCurrency(hra)),
          _buildBreakdownRow('Other Perks', _formatCurrency(otherPerks)),
          _buildBreakdownRow('Ee PF contribution', '-${_formatCurrency(pf)}', isDeduction: true),
          _buildBreakdownRow('Income Tax', '-${_formatCurrency(it)}', isDeduction: true),
          _buildBreakdownRow('Other Deductions', '-${_formatCurrency(otherDeductions)}', isDeduction: true),
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
                        onPressed: () => _downloadPayslip(p['month']),
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

  void _downloadPayslip(String month) {
    PayslipPdfHelper.printPayslipPdf(month);
  }

  void _viewPayslip(Map<String, dynamic> payslip) {
    showDialog(
      context: context,
      builder: (context) {
        Widget cellText(String text, {bool bold = false, TextAlign align = TextAlign.left, Color? bgColor}) {
          return Container(
            color: bgColor,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            alignment: align == TextAlign.center
                ? Alignment.center
                : align == TextAlign.right ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(
              text,
              textAlign: align,
              style: TextStyle(
                fontSize: 10,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: Colors.black87,
              ),
            ),
          );
        }

        Widget docCard = Container(
          width: 800,
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'मॉयल\nMOIL',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 6,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MOIL LIMITED',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          Text(
                            'मॉयल लिमिटेड',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Payment Slip',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      Text(
                        'वेतन पर्ची',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Employee Info Table
              Table(
                border: TableBorder.all(color: Colors.grey.shade400, width: 0.5),
                columnWidths: const {
                  0: FixedColumnWidth(100),
                  1: FlexColumnWidth(),
                  2: FixedColumnWidth(100),
                  3: FlexColumnWidth(),
                  4: FixedColumnWidth(100),
                  5: FlexColumnWidth(),
                },
                children: [
                  TableRow(children: [
                    cellText('Emp Name\nनाम', bold: true),
                    cellText('B.C.N. Gautam'),
                    cellText('Location\nकार्यस्थल', bold: true),
                    cellText('Head Office Nag'),
                    cellText('Grade\nवेतनमान', bold: true),
                    cellText('80000-220000'),
                  ]),
                  TableRow(children: [
                    cellText('Personnel No.\nकर्मचारी नंबर', bold: true),
                    cellText('00004428'),
                    cellText('Department\nविभाग', bold: true),
                    cellText('System'),
                    cellText('Emp Grp\nकर्मचारी समूह', bold: true),
                    cellText('Executive'),
                  ]),
                  TableRow(children: [
                    cellText('Period\nअवधि', bold: true),
                    cellText(payslip['month'] == 'May 2026' ? '01.06.2026-30.06.2026' : '01.05.2026-31.05.2026'),
                    cellText('PF No\nभविष्य निधि नंबर', bold: true),
                    cellText('NG/NAG/3600/4755'),
                    cellText('Emp Subgrp\nकर्मचारी उपसमूह', bold: true),
                    cellText('Asst. Gen. Manager'),
                  ]),
                  TableRow(children: [
                    cellText('Pan No\nपैन नंबर', bold: true),
                    cellText('AIMPG8474A'),
                    cellText('Form B No\nफॉर्म बी. नंबर', bold: true),
                    cellText('02260'),
                    cellText('Designation\nपदनाम', bold: true),
                    cellText('Assistant General Manager-System'),
                  ]),
                ],
              ),
              const SizedBox(height: 8),

              // Bank Info & Summary Table
              Table(
                border: TableBorder.all(color: Colors.grey.shade400, width: 0.5),
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1.2),
                  3: FlexColumnWidth(1.2),
                  4: FlexColumnWidth(1.2),
                  5: FlexColumnWidth(1.2),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: [
                      cellText('Bank Name', bold: true, align: TextAlign.center),
                      cellText('Account No', bold: true, align: TextAlign.center),
                      cellText('Basic', bold: true, align: TextAlign.center),
                      cellText('Earnings', bold: true, align: TextAlign.center),
                      cellText('Deductions', bold: true, align: TextAlign.center),
                      cellText('Net Pay', bold: true, align: TextAlign.center),
                    ],
                  ),
                  TableRow(
                    children: [
                      cellText('STATE BANK OF INDIA', align: TextAlign.center),
                      cellText('20529486466', align: TextAlign.center),
                      cellText('88,710.00', align: TextAlign.center),
                      cellText(payslip['month'] == 'May 2026' ? '185,492.50' : '185,492.50', align: TextAlign.center),
                      cellText(payslip['month'] == 'May 2026' ? '46,274.00' : '46,274.00', align: TextAlign.center),
                      cellText(payslip['month'] == 'May 2026' ? '139,218.50' : '139,218.50', align: TextAlign.center),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Earnings & Deductions Details Table
              Table(
                border: TableBorder.all(color: Colors.grey.shade400, width: 0.5),
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(2.5),
                  3: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade50),
                    children: [
                      cellText('Earnings\nअर्जन', bold: true, align: TextAlign.center),
                      cellText('', bold: true),
                      cellText('Deductions\nकटौतियाँ', bold: true, align: TextAlign.center),
                      cellText('', bold: true),
                    ],
                  ),
                  TableRow(children: [
                    cellText('Basic Pay - Exe & NE\nमूल वेतन'),
                    cellText('88,710.00', align: TextAlign.right),
                    cellText('Ee PF contribution\nकर्मचारी PF अंशदान'),
                    cellText('16,404.00', align: TextAlign.right),
                  ]),
                  TableRow(children: [
                    cellText('Dearness Allow - Exe & NE\nमहंगाई भत्ता-दिव्या'),
                    cellText('47,992.00', align: TextAlign.right),
                    cellText('Prof Tax - split period\nवृत्ति कर - विभाजन अवधि'),
                    cellText('200.00', align: TextAlign.right),
                  ]),
                  TableRow(children: [
                    cellText('House Rent Allow E&NE\nमकान किराया भत्ता'),
                    cellText('17,742.00', align: TextAlign.right),
                    cellText('Income Tax\nआयकर'),
                    cellText('22,420.00', align: TextAlign.right),
                  ]),
                  TableRow(children: [
                    cellText('Other Perks\nअन्य भत्ते'),
                    cellText('31,048.50', align: TextAlign.right),
                    cellText('Credit Society Share\nक्रेडिट सोसायटी शेयर'),
                    cellText('7,000.00', align: TextAlign.right),
                  ]),
                  TableRow(children: [
                    cellText(''),
                    cellText(''),
                    cellText('Furn & Fixture Recovery\nफर्निचर और फिक्सचर रिकव'),
                    cellText('100.00', align: TextAlign.right),
                  ]),
                  TableRow(children: [
                    cellText(''),
                    cellText(''),
                    cellText('MEA Subscription fees\nएमईए सदस्यता शुल्क'),
                    cellText('100.00', align: TextAlign.right),
                  ]),
                  TableRow(children: [
                    cellText(''),
                    cellText(''),
                    cellText('Benevolent Fund\nपरोपकार निधि'),
                    cellText('50.00', align: TextAlign.right),
                  ]),
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: [
                      cellText('Total Earnings', bold: true),
                      cellText('185,492.50', bold: true, align: TextAlign.right),
                      cellText('Total Deductions', bold: true),
                      cellText('46,274.00', bold: true, align: TextAlign.right),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 5),

              // Take Home Pay Summary Box
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 0.5),
                  color: Colors.grey.shade200,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Take Home Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                    Text(payslip['month'] == 'May 2026' ? '139,218.50' : '139,218.50', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Form 16 Summary & Chapter VIA Deductions Side-by-Side
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form 16 Summary
                  Expanded(
                    flex: 1,
                    child: Table(
                      border: TableBorder.all(color: Colors.grey.shade400, width: 0.5),
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(1),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade100),
                          children: [
                            cellText('Form 16 Summary', bold: true),
                            cellText('', bold: true),
                          ],
                        ),
                        TableRow(children: [
                          cellText('Gross Salary'),
                          cellText('2,239,830.00', align: TextAlign.right),
                        ]),
                        TableRow(children: [
                          cellText('Balance'),
                          cellText('2,239,830.00', align: TextAlign.right),
                        ]),
                        TableRow(children: [
                          cellText('Incm under Hd Salary'),
                          cellText('2,239,830.00', align: TextAlign.right),
                        ]),
                        TableRow(children: [
                          cellText('Gross Tot Income'),
                          cellText('2,239,830.00', align: TextAlign.right),
                        ]),
                        TableRow(children: [
                          cellText('Total Income'),
                          cellText('2,239,830.00', align: TextAlign.right),
                        ]),
                        TableRow(children: [
                          cellText('Tax payable and surcharge'),
                          cellText('425,827.00', align: TextAlign.right),
                        ]),
                        TableRow(children: [
                          cellText('Income Tax'),
                          cellText('22,420.00', align: TextAlign.right),
                        ]),
                        TableRow(children: [
                          cellText('Balance tax(payable/refundable)'),
                          cellText('384,327.00', align: TextAlign.right),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Chapter VIA Deductions
                  Expanded(
                    flex: 1,
                    child: Table(
                      border: TableBorder.all(color: Colors.grey.shade400, width: 0.5),
                      columnWidths: const {
                        0: FlexColumnWidth(1.5),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(1),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade100),
                          children: [
                            cellText('Chapter VIA Deductions', bold: true),
                            cellText('Invst. amt', bold: true),
                            cellText('Effect Exm.', bold: true),
                          ],
                        ),
                        TableRow(children: [
                          cellText('Section 80C'),
                          cellText('150,000.00', align: TextAlign.right),
                          cellText('150,000.00', align: TextAlign.right),
                        ]),
                        TableRow(children: [
                          cellText('Section 80D'),
                          cellText('25,000.00', align: TextAlign.right),
                          cellText('25,000.00', align: TextAlign.right),
                        ]),
                        TableRow(children: [
                          cellText('Section 80CCD(1B)'),
                          cellText('50,000.00', align: TextAlign.right),
                          cellText('50,000.00', align: TextAlign.right),
                        ]),
                        TableRow(children: [
                          cellText(''),
                          cellText(''),
                          cellText(''),
                        ]),
                        TableRow(children: [
                          cellText(''),
                          cellText(''),
                          cellText(''),
                        ]),
                        TableRow(children: [
                          cellText(''),
                          cellText(''),
                          cellText(''),
                        ]),
                        TableRow(children: [
                          cellText(''),
                          cellText(''),
                          cellText(''),
                        ]),
                        TableRow(children: [
                          cellText(''),
                          cellText(''),
                          cellText(''),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Leave Details Row
              Table(
                border: TableBorder.all(color: Colors.grey.shade400, width: 0.5),
                columnWidths: const {
                  0: FlexColumnWidth(1.5),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                  4: FlexColumnWidth(1.2),
                  5: FlexColumnWidth(1),
                  6: FlexColumnWidth(1),
                  7: FlexColumnWidth(1),
                  8: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.shade100),
                    children: [
                      cellText('Leave Details\nहाजरी', bold: true, align: TextAlign.center),
                      cellText('E.L.\nअर्जित छुट्टी', bold: true, align: TextAlign.center),
                      cellText('C.L.\nआकस्मिक छुट्टी', bold: true, align: TextAlign.center),
                      cellText('H.P.L.\nअर्ध वेतन छुट्टी', bold: true, align: TextAlign.center),
                      cellText('C.H.P.L.\nसी.एच.पी.एल.', bold: true, align: TextAlign.center),
                      cellText('O.L.\nवैकल्पिक छुट्टी', bold: true, align: TextAlign.center),
                      cellText('L.W.P.\nविन वेतन छुट्टी', bold: true, align: TextAlign.center),
                      cellText('ATTEND\nहाजरी', bold: true, align: TextAlign.center),
                      cellText('Total\nकुल', bold: true, align: TextAlign.center),
                    ],
                  ),
                  TableRow(
                    children: [
                      cellText('Balance', align: TextAlign.center),
                      cellText('263.50', align: TextAlign.center),
                      cellText('6.50', align: TextAlign.center),
                      cellText('315.00', align: TextAlign.center),
                      cellText('0.00', align: TextAlign.center),
                      cellText('2.00', align: TextAlign.center),
                      cellText('0.00', align: TextAlign.center),
                      cellText('30', align: TextAlign.center),
                      cellText('30.00', align: TextAlign.center),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Footer Note
              const Center(
                child: Text(
                  'This is a system generated pay-slip and requires no signature',
                  style: TextStyle(fontSize: 8, fontStyle: FontStyle.italic, color: Colors.grey),
                ),
              ),
            ],
          ),
        );

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 850),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: Text('Payslip Layout - ${payslip['month']}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: docCard,
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text('Close'),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download PDF'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadPayslip(payslip['month']);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
