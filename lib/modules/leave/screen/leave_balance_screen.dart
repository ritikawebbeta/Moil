// lib/modules/leave/screen/leave_balance_screen.dart
// Matches SAP Leave Balance with Time Accounts table

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_colors.dart';
import '../controller/leave_controller.dart';
import '../../../widgets/app_widgets.dart';

class LeaveBalanceScreen extends StatelessWidget {
  const LeaveBalanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaveController>(
      builder: (context, controller, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // _buildBalanceCards(controller),
              const SizedBox(height: 16),
              _buildTimeAccountsTable(controller),
            ],
          ),
        );
      },
    );
  }

  // Widget _buildBalanceCards(LeaveController controller) {
  //   if (controller.balances.isEmpty) {
  //     return const SizedBox.shrink();
  //   }

  //   final filteredBalances = controller.balances.where((b) {
  //     final name = b.timeAccount.toLowerCase();
  //     return name != 'earned leave' && name != 'casual leave';
  //   }).toList();

  //   if (filteredBalances.isEmpty) {
  //     return const SizedBox.shrink();
  //   }

  //   return GridView.builder(
  //     shrinkWrap: true,
  //     physics: const NeverScrollableScrollPhysics(),
  //     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  //       crossAxisCount: 2,
  //       crossAxisSpacing: 12,
  //       mainAxisSpacing: 12,
  //       childAspectRatio: 1.6,
  //     ),
  //     itemCount: filteredBalances.length,
  //     itemBuilder: (context, index) {
  //       final balance = filteredBalances[index];
  //       final color = _getLeaveColor(balance.timeAccount);
  //       final used = balance.entitlement - balance.entitlementMinusPlanned;

  //       return Container(
  //         padding: const EdgeInsets.all(14),
  //         decoration: BoxDecoration(
  //           color: AppColors.cardBg,
  //           borderRadius: BorderRadius.circular(14),
  //           border: Border.all(color: color.withOpacity(0.25)),
  //           boxShadow: [
  //             BoxShadow(
  //               color: Colors.black.withOpacity(0.02),
  //               blurRadius: 10,
  //               offset: const Offset(0, 2),
  //             ),
  //           ],
  //         ),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 Expanded(
  //                   child: Text(
  //                     balance.timeAccount,
  //                     style: TextStyle(
  //                       color: color,
  //                       fontSize: 12,
  //                       fontWeight: FontWeight.w700,
  //                     ),
  //                     overflow: TextOverflow.ellipsis,
  //                   ),
  //                 ),
  //                 Container(
  //                   padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  //                   decoration: BoxDecoration(
  //                     color: color.withOpacity(0.08),
  //                     borderRadius: BorderRadius.circular(4),
  //                   ),
  //                   child: Text(
  //                     '${balance.entitlementMinusPlanned.toStringAsFixed(0)} d',
  //                     style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             const Spacer(),
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 Text(
  //                   'Used: ${used.toStringAsFixed(1)}',
  //                   style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
  //                 ),
  //                 Text(
  //                   'Total: ${balance.entitlement.toStringAsFixed(1)}',
  //                   style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w500),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

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

  Widget _buildTimeAccountsTable(LeaveController controller) {
    final filteredBalances = controller.balances.where((b) {
      final name = b.timeAccount.toLowerCase();
      return name != 'earned leave' && name != 'casual leave';
    }).toList();

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Time Accounts',
            icon: Icons.account_balance_wallet_outlined,
            trailing: _FilterRow(),
          ),
          // Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  color: AppColors.backgroundTertiary,
                  child: const Row(
                    children: [
                      _HeaderCell(text: 'Time Account', width: 160),
                      _HeaderCell(text: 'Deduction from', width: 130),
                      _HeaderCell(text: 'Deduction to', width: 130),
                      _HeaderCell(text: 'Entitlement', width: 120),
                      _HeaderCell(text: 'Entitlement Minus Planned', width: 200),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.cardBorder),
                // Rows
                if (filteredBalances.isEmpty)
                  const SizedBox(
                     width: 740,
                    height: 80,
                    child: Center(
                      child: Text('No records found', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ),
                  )
                else
                  ...filteredBalances.asMap().entries.map((entry) {
                    final i = entry.key;
                    final b = entry.value;
                    final color = _getLeaveColor(b.timeAccount);

                    return Column(
                      children: [
                        Container(
                          color: i.isEven ? AppColors.background.withOpacity(0.3) : Colors.transparent,
                          child: Row(
                            children: [
                              _BodyCell(
                                width: 160,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      b.timeAccount,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _BodyCell(
                                text: DateFormat('dd/MM/yyyy').format(b.deductionFrom),
                                width: 130,
                              ),
                              _BodyCell(
                                text: DateFormat('dd/MM/yyyy').format(b.deductionTo),
                                width: 130,
                              ),
                              _BodyCell(
                                text: '${b.entitlement.toStringAsFixed(2)} Days',
                                width: 120,
                                valueColor: AppColors.success,
                              ),
                              _BodyCell(
                                text: '${b.entitlementMinusPlanned.toStringAsFixed(2)} Days',
                                width: 200,
                                valueColor: AppColors.primary,
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
          ),
        ],
      ),
    );
  }

}

class _FilterRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: const Text('17.06.2026', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;
  const _HeaderCell({required this.text, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  final String? text;
  final Widget? child;
  final double width;
  final Color? valueColor;

  const _BodyCell({this.text, this.child, required this.width, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: child ??
          Text(
            text ?? '',
            style: TextStyle(color: valueColor ?? AppColors.textPrimary, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
    );
  }
}
