// lib/modules/leave/screen/leave_calendar_screen.dart
// Matches SAP Leave Calendar wise - Team Calendar view

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../utils/app_colors.dart';
import '../controller/leave_controller.dart';
import '../../../widgets/app_widgets.dart';
import '../../../model/leave_model.dart';
import '../../auth/controller/auth_controller.dart';
import '../../profile/controller/profile_controller.dart';

class LeaveCalendarScreen extends StatefulWidget {
  const LeaveCalendarScreen({super.key});

  @override
  State<LeaveCalendarScreen> createState() => _LeaveCalendarScreenState();
}

class _LeaveCalendarScreenState extends State<LeaveCalendarScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  String _viewMode = 'Month';

  final List<String> _teamMembers = [
    'G Rohini Kumar',
    'Nareshkumar Madhorao Gaidhane',
    'Gautam Bose',
  ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    final user = auth.user;
    final loggedInEmpNo = user?.employeeId;
    final isReportingOfficer = ProfileController.rawEmployees.any((emp) =>
        emp['reportingOfficer'] == loggedInEmpNo ||
        emp['reportingOfficer1'] == loggedInEmpNo);
    _tabController = TabController(length: isReportingOfficer ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final loggedInEmpNo = user?.employeeId;
    final isReportingOfficer = ProfileController.rawEmployees.any((emp) =>
        emp['reportingOfficer'] == loggedInEmpNo ||
        emp['reportingOfficer1'] == loggedInEmpNo);

    if (!isReportingOfficer) {
      return _buildPersonalCalendar();
    }

    return Column(
      children: [
        _buildSubTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPersonalCalendar(),
              _buildTeamCalendar(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubTabBar() {
    return Container(
      color: AppColors.backgroundSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _SubTab(
            label: 'Calendar',
            index: 0,
            controller: _tabController,
          ),
          const SizedBox(width: 4),
          _SubTab(
            label: 'Team Calendar',
            index: 1,
            controller: _tabController,
          ),
        ],
      ),
    );
  }

  // ─── Personal Calendar ────────────────────────────────────────────
  Widget _buildPersonalCalendar() {
    return Consumer<LeaveController>(
      builder: (context, controller, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              GlassCard(
                padding: EdgeInsets.zero,
                child: TableCalendar(
                  firstDay: DateTime(2024),
                  lastDay: DateTime(DateTime.now().year + 5),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: _calendarFormat,
                  onFormatChanged: (format) => setState(() => _calendarFormat = format),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  eventLoader: (day) => _getEventsForDay(day, controller.leaves),
                  calendarStyle: CalendarStyle(
                    defaultTextStyle: const TextStyle(color: AppColors.textPrimary),
                    weekendTextStyle: const TextStyle(color: AppColors.error),
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                    ),
                    outsideDaysVisible: false,
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    formatButtonDecoration: BoxDecoration(
                      color: AppColors.backgroundTertiary,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    formatButtonTextStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                    leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.textSecondary),
                    rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    weekendStyle: TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildLegend(),
              const SizedBox(height: 16),
              if (_selectedDay != null) _buildSelectedDayEvents(controller),
            ],
          ),
        );
      },
    );
  }

  List<LeaveModel> _getEventsForDay(DateTime day, List<LeaveModel> leaves) {
    return leaves.where((leave) {
      return !day.isBefore(leave.startDate) && !day.isAfter(leave.endDate);
    }).toList();
  }

  Widget _buildLegend() {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _LegendItem(color: AppColors.primary.withOpacity(0.6), label: 'Sent'),
          _LegendItem(color: AppColors.accent, label: 'Absent'),
          _LegendItem(color: AppColors.textHint, label: 'Non-Working Day'),
          _LegendItem(color: AppColors.officialTour, label: 'Travel'),
          _LegendItem(color: AppColors.primaryLight, label: 'Multiple Entries'),
          _LegendItem(color: AppColors.error, label: 'Deletion Requested'),
          _LegendItem(color: AppColors.warning, label: 'Holiday'),
        ],
      ),
    );
  }

  Widget _buildSelectedDayEvents(LeaveController controller) {
    final events = _getEventsForDay(_selectedDay!, controller.leaves);
    if (events.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            'No leave on ${DateFormat('dd MMM yyyy').format(_selectedDay!)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('dd MMMM yyyy').format(_selectedDay!),
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...events.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    LeaveTypeBadge(type: e.leaveType),
                    const Spacer(),
                    StatusBadge(status: e.status),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── Team Calendar ────────────────────────────────────────────────
  Widget _buildTeamCalendar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTeamCalendarControls(),
          const SizedBox(height: 12),
          _buildTeamCalendarGrid(),
          const SizedBox(height: 12),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildTeamCalendarControls() {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildControlChip(label: 'View:', value: _viewMode, options: const ['Month', 'Week'],
            onSelect: (v) => setState(() => _viewMode = v)),
          const SizedBox(width: 8),
          _buildControlChip(label: 'Month:', value: DateFormat('MMMM').format(_focusedDay),
            options: List.generate(12, (i) => DateFormat('MMMM').format(DateTime(2026, i + 1))),
            onSelect: (v) {
              final monthIndex = DateFormat('MMMM').parse(v).month;
              setState(() => _focusedDay = DateTime(_focusedDay.year, monthIndex));
            }),
          const SizedBox(width: 4),
          _buildControlChip(label: '', value: _focusedDay.year.toString(),
            options: const ['2025', '2026', '2027'],
            onSelect: (v) => setState(() => _focusedDay = DateTime(int.parse(v), _focusedDay.month))),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Apply', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlChip({
    required String label,
    required String value,
    required List<String> options,
    required void Function(String) onSelect,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        if (label.isNotEmpty) const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.inputBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: DropdownButton<String>(
            value: value,
            isDense: true,
            underline: const SizedBox(),
            dropdownColor: AppColors.cardBg,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 14),
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: (v) => onSelect(v!),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedDay.year, _focusedDay.month);
    final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);

    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: '${DateFormat('MMMM yyyy').format(_focusedDay)} Team Calendar',
            icon: Icons.people_outline_rounded,
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date header row
                _buildDateHeaderRow(daysInMonth, firstDay),
                const Divider(height: 1, color: AppColors.cardBorder),
                // Team member rows
                ..._teamMembers.asMap().entries.map((e) {
                  return _buildTeamMemberRow(e.value, daysInMonth, firstDay, e.key.isEven);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeaderRow(int daysInMonth, DateTime firstDay) {
    return Container(
      color: AppColors.backgroundTertiary,
      child: Row(
        children: [
          // Name column
          Container(
            width: 160,
            padding: const EdgeInsets.all(8),
            child: const Text(
              'Name',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          // Day columns
          ...List.generate(daysInMonth, (i) {
            final day = i + 1;
            final date = DateTime(firstDay.year, firstDay.month, day);
            final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
            return Container(
              width: 28,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  Text(
                    DateFormat('E').format(date).substring(0, 3),
                    style: TextStyle(
                      color: isWeekend ? AppColors.error.withOpacity(0.7) : AppColors.textSecondary,
                      fontSize: 8,
                    ),
                  ),
                  Text(
                    '$day',
                    style: TextStyle(
                      color: isWeekend ? AppColors.error.withOpacity(0.7) : AppColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTeamMemberRow(String name, int daysInMonth, DateTime firstDay, bool isEven) {
    // Mock leave data per member
    final leaveRanges = {
      'G Rohini Kumar': <int>[],
      'Nareshkumar Madhorao Gaidhane': [17, 18, 19],
      'Gautam Bose': [12],
    };

    return Column(
      children: [
        Container(
          color: isEven ? AppColors.background.withOpacity(0.3) : Colors.transparent,
          child: Row(
            children: [
              // Name
              Container(
                width: 160,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Text(
                  name,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Day cells
              ...List.generate(daysInMonth, (i) {
                final day = i + 1;
                final date = DateTime(firstDay.year, firstDay.month, day);
                final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
                final hasLeave = (leaveRanges[name] ?? []).contains(day);

                return Container(
                  width: 28,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isWeekend
                        ? AppColors.textHint.withOpacity(0.1)
                        : hasLeave
                            ? AppColors.accent.withOpacity(0.3)
                            : Colors.transparent,
                    border: Border(
                      left: BorderSide(color: AppColors.cardBorder.withOpacity(0.3), width: 0.5),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.cardBorder),
      ],
    );
  }
}

class _SubTab extends StatelessWidget {
  final String label;
  final int index;
  final TabController controller;

  const _SubTab({
    required this.label,
    required this.index,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isSelected = controller.index == index;
        return GestureDetector(
          onTap: () => controller.animateTo(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.inputBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.inputBorder,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}
