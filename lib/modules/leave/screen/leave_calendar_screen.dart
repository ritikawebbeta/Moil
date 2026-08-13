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
import '../../../model/user_model.dart';

import '../../holiday/controller/holiday_controller.dart';

class LeaveCalendarScreen extends StatefulWidget {
  const LeaveCalendarScreen({super.key});

  @override
  State<LeaveCalendarScreen> createState() => _LeaveCalendarScreenState();
}

class _LeaveCalendarScreenState extends State<LeaveCalendarScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  String _viewMode = 'Month';

  late String _tempViewMode;
  late int _tempMonth;
  late int _tempYear;

  static final Map<String, String> _mandatoryHolidays = {
    '2025-01-26': 'Republic Day',
    '2025-03-14': 'Holi',
    '2025-04-14': 'Dr. Babasaheb Ambedkar Jayanti',
    '2025-08-15': 'Independence Day',
    '2025-08-24': 'Narbodh/Pola',
    '2025-10-02': 'Mahatma Gandhi Jayanti',
    '2025-10-20': 'Diwali',
    '2025-10-21': 'Diwali',
    '2026-01-26': 'Republic Day',
    '2026-03-03': 'Holi',
    '2026-04-14': 'Dr. Babasaheb Ambedkar Jayanti',
    '2026-08-15': 'Independence Day',
    '2026-09-12': 'Narbodh/Pola',
    '2026-10-02': 'Mahatma Gandhi Jayanti',
    '2026-11-08': 'Diwali',
    '2026-11-09': 'Diwali',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tempViewMode = _viewMode;
    _tempMonth = _focusedDay.month;
    _tempYear = _focusedDay.year;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaveController>().fetchLeaves();
      context.read<LeaveController>().fetchTeamCalendar();
      context.read<HolidayController>().fetchHolidays();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  firstDay: DateTime(2022),
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
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isEmpty) return const SizedBox.shrink();
                      return Positioned(
                        bottom: 2,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                    defaultBuilder: (context, day, focusedDay) {
                      final events = _getEventsForDay(day, controller.leaves);
                      if (events.isNotEmpty) {
                        final leave = events.first;
                        final isHoliday = leave.status.toUpperCase() == 'HOLIDAY';
                        final isApproved = leave.status.toUpperCase() == 'APPROVED';
                        final bg = isHoliday
                            ? AppColors.warning.withOpacity(0.3)
                            : isApproved
                                ? AppColors.success.withOpacity(0.2)
                                : AppColors.primary.withOpacity(0.2);
                        final fg = isHoliday
                            ? AppColors.warning
                            : isApproved
                                ? AppColors.success
                                : AppColors.primary;
                        return Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: bg,
                            shape: BoxShape.circle,
                            border: Border.all(color: fg, width: 1.5),
                          ),
                          child: Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                  calendarStyle: const CalendarStyle(
                    defaultTextStyle: TextStyle(color: AppColors.textPrimary),
                    weekendTextStyle: TextStyle(color: AppColors.textPrimary),
                    selectedDecoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.fromBorderSide(BorderSide(color: AppColors.primary, width: 1.5)),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
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
                    weekendStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
    final list = leaves.where((leave) {
      return !day.isBefore(leave.startDate) && !day.isAfter(leave.endDate);
    }).toList();

    final dateKey = DateFormat('yyyy-MM-dd').format(day);
    if (_mandatoryHolidays.containsKey(dateKey)) {
      list.insert(0, LeaveModel(
        id: 'hol_$dateKey',
        leaveType: 'Holiday (${_mandatoryHolidays[dateKey]})',
        startDate: day,
        endDate: day,
        status: 'Holiday',
        reason: _mandatoryHolidays[dateKey] ?? 'Public Holiday',
        processor: 'System',
        processor1: 'System',
      ));
    }

    return list;
  }

  Widget _buildLegend() {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          _LegendItem(color: AppColors.primary.withOpacity(0.6), label: 'Sent'),
          _LegendItem(color: AppColors.success, label: 'Approved'),
          _LegendItem(color: AppColors.textHint, label: 'Non-Working Day'),
          _LegendItem(color: AppColors.officialTour, label: 'Travel'),
          _LegendItem(color: AppColors.warning, label: 'Holiday'),
          _LegendItem(color: Colors.amber.shade700, label: 'Casual Leave (CL)'),
          _LegendItem(color: AppColors.primary, label: 'Earned Leave (EL)'),
          _LegendItem(color: Colors.purple.shade600, label: 'HPL / CHPL'),
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

  DateTime? _parseFlexibleDate(dynamic dateVal) {
    if (dateVal == null) return null;
    final str = dateVal.toString().trim();
    if (str.isEmpty || str == 'null') return null;
    try {
      return DateTime.parse(str);
    } catch (_) {}
    try {
      final parts = str.split(RegExp(r'[-./]'));
      if (parts.length >= 3) {
        if (parts[0].length == 4) {
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else if (parts[2].length == 4) {
          return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      }
    } catch (_) {}
    return null;
  }

  Color _getLeaveColor(String type, String status) {
    final upperType = type.toUpperCase();
    final upperStatus = status.toUpperCase();
    if (upperStatus == 'REJECTED') return AppColors.error;
    if (upperType.contains('CASUAL') || upperType.contains('CL')) return Colors.amber.shade700;
    if (upperType.contains('EARNED') || upperType.contains('EL')) return AppColors.primary;
    if (upperType.contains('HPL') || upperType.contains('HALF')) return Colors.purple.shade600;
    if (upperType.contains('OPTIONAL') || upperType.contains('OL')) return Colors.teal;
    if (upperType.contains('TOUR') || upperType.contains('TRAVEL')) return AppColors.officialTour;
    if (upperStatus == 'APPROVED' || upperStatus == 'POSTED') return AppColors.success;
    return AppColors.primary.withOpacity(0.7);
  }

  String _getLeaveBadgeCode(String type) {
    final upper = type.toUpperCase();
    if (upper.contains('CASUAL')) return 'CL';
    if (upper.contains('EARNED')) return 'EL';
    if (upper.contains('CHPL')) return 'CHPL';
    if (upper.contains('HPL')) return 'HPL';
    if (upper.contains('OPTIONAL')) return 'OL';
    if (upper.contains('SPECIAL')) return 'SL';
    if (upper.contains('TOUR')) return 'TR';
    return 'LV';
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
    final currentYear = DateTime.now().year;
    final yearOptions = List.generate(currentYear - 2022 + 1, (i) => (2022 + i).toString());

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildControlChip(label: 'View:', value: _tempViewMode, options: const ['Month', 'Week'],
            onSelect: (v) => setState(() => _tempViewMode = v)),
          const SizedBox(width: 8),
          _buildControlChip(label: 'Month:', value: DateFormat('MMMM').format(DateTime(2026, _tempMonth)),
            options: List.generate(12, (i) => DateFormat('MMMM').format(DateTime(2026, i + 1))),
            onSelect: (v) {
              final monthIndex = DateFormat('MMMM').parse(v).month;
              setState(() => _tempMonth = monthIndex);
            }),
          const SizedBox(width: 4),
          _buildControlChip(label: '', value: yearOptions.contains(_tempYear.toString()) ? _tempYear.toString() : currentYear.toString(),
            options: yearOptions,
            onSelect: (v) => setState(() => _tempYear = int.parse(v))),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _viewMode = _tempViewMode;
                _focusedDay = DateTime(_tempYear, _tempMonth, 1);
              });
            },
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

    final auth = context.read<AuthController>();
    final currentUser = auth.user;
    final cleanCurrentUserId = (currentUser?.employeeId ?? '').trim().replaceAll(RegExp('^0+'), '');

    final leaveController = context.watch<LeaveController>();
    final dbTeamCalendar = leaveController.teamCalendar;

    final List<Map<String, dynamic>> teamMembersWithLeaves = [];

    if (dbTeamCalendar.isNotEmpty) {
      for (var item in dbTeamCalendar) {
        final name = item['name']?.toString() ?? 'Unknown';
        final List<dynamic> leavesList = item['leaves'] ?? [];
        final Map<int, Map<String, String>> leaveDaysMap = {};

        for (var l in leavesList) {
          try {
            final start = _parseFlexibleDate(l['startDate']);
            final end = _parseFlexibleDate(l['endDate']);
            final type = l['leaveType']?.toString() ?? 'Earned leave';
            final status = l['status']?.toString() ?? 'Approved';

            if (start != null && end != null) {
              DateTime current = start;
              while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
                if (current.year == _focusedDay.year && current.month == _focusedDay.month) {
                  leaveDaysMap[current.day] = {
                    'type': type,
                    'status': status,
                  };
                }
                current = current.add(const Duration(days: 1));
              }
            }
          } catch (_) {}
        }

        teamMembersWithLeaves.add({
          'name': name,
          'leaveDaysMap': leaveDaysMap,
        });
      }
    } else {
      final List<String> teamList = cleanCurrentUserId.isEmpty
          ? []
          : ProfileController.rawEmployees
              .where((emp) {
                final ro = (emp['reportingOfficer']?.toString() ?? '').trim().replaceAll(RegExp('^0+'), '');
                final ro1 = (emp['reportingOfficer1']?.toString() ?? '').trim().replaceAll(RegExp('^0+'), '');
                return ro == cleanCurrentUserId || ro1 == cleanCurrentUserId;
              })
              .map((emp) => emp['name']?.toString() ?? 'Employee')
              .toList();

      for (var name in teamList) {
        teamMembersWithLeaves.add({
          'name': name,
          'leaveDaysMap': <int, Map<String, String>>{},
        });
      }
    }

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
                if (teamMembersWithLeaves.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No team members found',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  )
                else
                  ...teamMembersWithLeaves.asMap().entries.map((e) {
                    final name = e.value['name']?.toString() ?? '';
                    final leaveDaysMap = Map<int, Map<String, String>>.from(e.value['leaveDaysMap'] ?? {});
                    return _buildTeamMemberRow(name, leaveDaysMap, daysInMonth, firstDay, e.key.isEven);
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
            width: 220,
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
            final dateKey = DateFormat('yyyy-MM-dd').format(date);
            final isHoliday = _mandatoryHolidays.containsKey(dateKey);
            final isWeekend = date.weekday == DateTime.sunday;

            return Container(
              width: 32,
              padding: const EdgeInsets.symmetric(vertical: 4),
              color: isHoliday ? AppColors.warning.withOpacity(0.18) : Colors.transparent,
              child: Column(
                children: [
                  Text(
                    isHoliday ? 'HOL' : DateFormat('E').format(date).substring(0, 3),
                    style: TextStyle(
                      color: isHoliday ? AppColors.warning : (isWeekend ? AppColors.error.withOpacity(0.7) : AppColors.textSecondary),
                      fontSize: 8,
                      fontWeight: isHoliday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    '$day',
                    style: TextStyle(
                      color: isHoliday ? AppColors.warning : (isWeekend ? AppColors.error.withOpacity(0.7) : AppColors.textPrimary),
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

  Widget _buildTeamMemberRow(String name, Map<int, Map<String, String>> leaveDaysMap, int daysInMonth, DateTime firstDay, bool isEven) {
    return Column(
      children: [
        Container(
          color: isEven ? AppColors.background.withOpacity(0.3) : Colors.transparent,
          child: Row(
            children: [
              // Name
              Container(
                width: 220,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Text(
                  name,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Day cells
              ...List.generate(daysInMonth, (i) {
                final day = i + 1;
                final date = DateTime(firstDay.year, firstDay.month, day);
                final dateKey = DateFormat('yyyy-MM-dd').format(date);
                final isHoliday = _mandatoryHolidays.containsKey(dateKey);
                final isWeekend = date.weekday == DateTime.sunday;
                final leaveInfo = leaveDaysMap[day];

                if (isHoliday) {
                  final holName = _mandatoryHolidays[dateKey] ?? 'Holiday';
                  return Tooltip(
                    message: '$holName (Public Holiday)',
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.12),
                        border: Border(
                          left: BorderSide(color: AppColors.cardBorder.withOpacity(0.3), width: 0.5),
                        ),
                      ),
                      child: Container(
                        width: 24,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'HOL',
                          style: TextStyle(color: Colors.black87, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                }

                if (leaveInfo != null) {
                  final type = leaveInfo['type'] ?? 'Leave';
                  final status = leaveInfo['status'] ?? 'Approved';
                  final color = _getLeaveColor(type, status);
                  final badgeCode = _getLeaveBadgeCode(type);

                  return Tooltip(
                    message: '$name: $type ($status)',
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: AppColors.cardBorder.withOpacity(0.3), width: 0.5),
                        ),
                      ),
                      child: Container(
                        width: 24,
                        height: 20,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          badgeCode,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                }

                return Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isWeekend ? AppColors.textHint.withOpacity(0.12) : Colors.transparent,
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
