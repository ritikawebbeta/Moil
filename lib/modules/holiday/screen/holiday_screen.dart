// lib/modules/holiday/screen/holiday_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_colors.dart';
import '../controller/holiday_controller.dart';
import '../../../widgets/app_widgets.dart';

class HolidayScreen extends StatefulWidget {
  const HolidayScreen({super.key});

  @override
  State<HolidayScreen> createState() => _HolidayScreenState();
}

class _HolidayScreenState extends State<HolidayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HolidayController>().fetchHolidays();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar(
          title: 'Holiday Calendar',
          showBack: Navigator.of(context).canPop(),
        ),
        body: Column(
          children: [
            Container(
              color: AppColors.backgroundSecondary,
              child: TabBar(
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                dividerColor: AppColors.cardBorder,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                tabs: const [
                  Tab(text: 'Holidays'),
                  Tab(text: 'Optional Leaves'),
                ],
              ),
            ),
            Expanded(
              child: Consumer<HolidayController>(
                builder: (context, controller, _) {
                  if (controller.isLoading) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }

                  return TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildFilters(controller),
                            const SizedBox(height: 16),
                            _buildHolidayStats(controller, optionalOnly: false),
                            const SizedBox(height: 16),
                            _buildHolidayList(controller, optionalOnly: false),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildFilters(controller),
                            const SizedBox(height: 16),
                            _buildHolidayStats(controller, optionalOnly: true),
                            const SizedBox(height: 16),
                            _buildHolidayList(controller, optionalOnly: true),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(HolidayController controller) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          const Text('Filter:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 10),
          // Year dropdown
          _FilterDropdown<int>(
            value: controller.selectedYear,
            items: const [2025, 2026, 2027],
            itemLabel: (y) => '$y',
            onChanged: controller.setYear,
          ),
          const SizedBox(width: 10),
          // Month dropdown
          _FilterDropdown<int?>(
            value: controller.selectedMonth,
            items: [null, ...List.generate(12, (i) => i + 1)],
            itemLabel: (m) => m == null ? 'All Months' : DateFormat('MMMM').format(DateTime(2026, m)),
            onChanged: controller.setMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayStats(HolidayController controller, {required bool optionalOnly}) {
    final holidays = controller.filteredHolidays
        .where((h) => optionalOnly ? h.type == 'Optional' : h.type != 'Optional')
        .toList();

    final national = holidays.where((h) => h.isNational).length;
    final regional = holidays.where((h) => !h.isNational && h.type != 'Optional').length;

    return Row(
      children: [
        Expanded(child: _StatChip(label: optionalOnly ? 'Total Optional' : 'Total Holidays', value: '${holidays.length}', color: AppColors.primary)),
        if (!optionalOnly) ...[
          const SizedBox(width: 12),
          Expanded(child: _StatChip(label: 'National', value: '$national', color: AppColors.success)),
          const SizedBox(width: 12),
          Expanded(child: _StatChip(label: 'Regional', value: '$regional', color: AppColors.warning)),
        ] else ...[
          const SizedBox(width: 12),
          Expanded(child: _StatChip(label: 'Restricted', value: '${holidays.length}', color: AppColors.warning)),
        ],
      ],
    );
  }

  Widget _buildHolidayList(HolidayController controller, {required bool optionalOnly}) {
    final holidays = controller.filteredHolidays
        .where((h) => optionalOnly ? h.type == 'Optional' : h.type != 'Optional')
        .toList();

    if (holidays.isEmpty) {
      return const EmptyState(
        icon: Icons.celebration_outlined,
        title: 'No Holidays Found',
        subtitle: 'No holidays found for the selected period.',
      );
    }

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SectionHeader(
            title: 'Holiday List ${controller.selectedYear}',
            icon: Icons.celebration_rounded,
          ),
          ...holidays.asMap().entries.map((e) {
            final h = e.value;
            final isEven = e.key.isEven;
            final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
            final isExpired = h.date.isBefore(today);
            final isUpcoming = h.date.isAfter(DateTime.now());

            return Column(
              children: [
                Container(
                  color: isEven ? AppColors.background.withOpacity(0.3) : Colors.transparent,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      // Date Box
                      Container(
                        width: 50,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isExpired
                              ? Colors.grey.shade400
                              : (h.isNational ? AppColors.primary : AppColors.warning),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('dd').format(h.date),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              DateFormat('MMM').format(h.date),
                              style: const TextStyle(color: Colors.white70, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.name,
                              style: TextStyle(
                                color: isExpired ? Colors.grey.shade500 : AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                decoration: isExpired ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            Text(
                              DateFormat('EEEE, dd MMMM yyyy').format(h.date),
                              style: TextStyle(
                                color: isExpired ? Colors.grey.shade400 : AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isExpired
                                    ? Colors.grey.withOpacity(0.08)
                                    : (h.isNational
                                        ? AppColors.primary.withOpacity(0.08)
                                        : AppColors.warning.withOpacity(0.08)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                h.type,
                                style: TextStyle(
                                  color: isExpired ? Colors.grey.shade500 : (h.isNational ? AppColors.primary : AppColors.warning),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isUpcoming && !isExpired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.success.withOpacity(0.2)),
                          ),
                          child: const Text(
                            'Upcoming',
                            style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (isExpired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Text(
                            'Passed',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
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
}

class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T) onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        underline: const SizedBox(),
        dropdownColor: AppColors.cardBg,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 14),
        items: items.map((item) => DropdownMenuItem<T>(value: item, child: Text(itemLabel(item)))).toList(),
        onChanged: (v) => onChanged(v as T),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}
