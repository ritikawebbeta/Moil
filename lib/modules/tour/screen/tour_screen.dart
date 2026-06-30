// lib/modules/tour/screen/tour_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../utils/app_colors.dart';
import '../../auth/controller/auth_controller.dart';
import '../controller/tour_controller.dart';
import '../../../model/tour_model.dart';
import '../../../widgets/app_widgets.dart';

class TourScreen extends StatefulWidget {
  const TourScreen({super.key});

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TourModel? _editingTour;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthController>();
      if (auth.user != null) {
        context.read<TourController>().fetchTours(auth.user!.employeeId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _startApply({TourModel? tour}) {
    setState(() {
      _editingTour = tour;
      _isApplying = true;
    });
  }

  void _cancelApply() {
    setState(() {
      _isApplying = false;
      _editingTour = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isApplying) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: CustomAppBar(
          title: _editingTour != null ? 'Edit Travel Request' : 'New Travel Request',
          showBack: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20, color: Colors.white),
            onPressed: _cancelApply,
          ),
        ),
        body: _ApplyTourTab(
          editingTour: _editingTour,
          onComplete: () {
            _cancelApply();
            _tabController.animateTo(0);
          },
        ),
      );
    }

    final user = context.watch<AuthController>().user;
    final tourController = context.watch<TourController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'Travel Dashboard',
        showBack: Navigator.of(context).canPop(),
        leading: Navigator.of(context).canPop() ? null : const SizedBox.shrink(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subheader: My Trips and Expenses
          Container(
            color: AppColors.backgroundSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              'My Trips and Expenses (${user?.name ?? 'Employee'}, ${user?.employeeId ?? '00000000'})',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // SAP Stepper-style Tabs
          Container(
            color: AppColors.backgroundSecondary,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: AppColors.cardBorder,
              tabs: [
                Tab(text: 'All My Trips (${tourController.tours.length})'),
                Tab(text: 'All My Travel Requests (${tourController.tours.length})'),
                const Tab(text: 'All My Travel Plans (2)'),
                const Tab(text: 'All My Expense Reports (2)'),
                const Tab(text: 'Pending Exp. Reports (1)'),
                const Tab(text: 'Credit Card Imports (2)'),
                const Tab(text: 'Calendar'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AllMyTripsTab(
                  onNewRequest: () => _startApply(),
                  onEditRequest: (tour) => _startApply(tour: tour),
                ),
                _TourStatusTab(
                  onEdit: (tour) => _startApply(tour: tour),
                  onNew: () => _startApply(),
                ),
                const _TravelPlansTab(),
                const _ExpenseReportsTab(),
                const _PendingReportsTab(),
                const _CreditCardImportsTab(),
                const _TourCalendarTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Travel Plans Tab ────────────────────────────────────────────
class _TravelPlansTab extends StatelessWidget {
  const _TravelPlansTab();
  @override
  Widget build(BuildContext context) {
    final plans = [
      {'dest': 'New Delhi', 'dates': '15.08.2026 – 18.08.2026', 'purpose': 'Annual General Board Meeting', 'status': 'Planned'},
      {'dest': 'Bangalore', 'dates': '10.09.2026 – 12.09.2026', 'purpose': 'Corporate Tech Summit & Exhibition', 'status': 'Draft'},
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final p = plans[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(p['dest']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                    StatusBadge(status: p['status']!),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(p['dates']!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(p['purpose']!, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Expense Reports Tab ──────────────────────────────────────────
class _ExpenseReportsTab extends StatelessWidget {
  const _ExpenseReportsTab();
  @override
  Widget build(BuildContext context) {
    final expenses = [
      {'title': 'Travel Claim: Mumbai Tour', 'amount': 'Rs 14,500.00', 'date': '20.05.2026', 'status': 'Approved'},
      {'title': 'Travel Claim: Hyderabad Tour', 'amount': 'Rs 8,200.00', 'date': '12.04.2026', 'status': 'Approved'},
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final e = expenses[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                    StatusBadge(status: e['status']!),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Claimed Amount: ${e['amount']!}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    Text('Paid on: ${e['date']!}', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Pending Reports Tab ──────────────────────────────────────────
class _PendingReportsTab extends StatelessWidget {
  const _PendingReportsTab();
  @override
  Widget build(BuildContext context) {
    final pending = [
      {'title': 'Travel Claim: Delhi Tour', 'amount': 'Rs 12,300.00', 'date': '22.05.2026', 'status': 'Pending'},
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final e = pending[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                    StatusBadge(status: e['status']!),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Claimed Amount: ${e['amount']!}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    Text('Submitted: ${e['date']!}', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Credit Card Imports Tab ──────────────────────────────────────
class _CreditCardImportsTab extends StatelessWidget {
  const _CreditCardImportsTab();
  @override
  Widget build(BuildContext context) {
    final imports = [
      {'merchant': 'Air India Airlines', 'amount': 'Rs 18,400.00', 'date': '05.05.2026', 'status': 'Imported'},
      {'merchant': 'Taj Hotels Nagpur', 'amount': 'Rs 9,800.00', 'date': '11.05.2026', 'status': 'Imported'},
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: imports.length,
      itemBuilder: (context, index) {
        final i = imports[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i['merchant']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Transaction Date: ${i['date']!}', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(i['amount']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                      child: Text(i['status']!, style: const TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── All My Trips Tab (SAP Table Style) ──────────────────────────
class _AllMyTripsTab extends StatelessWidget {
  final VoidCallback onNewRequest;
  final Function(TourModel) onEditRequest;

  const _AllMyTripsTab({required this.onNewRequest, required this.onEditRequest});

  @override
  Widget build(BuildContext context) {
    final tourController = context.watch<TourController>();

    if (tourController.status == TourStatus.loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final tours = tourController.tours;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Action Bar
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text(
                    'View: ',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Text(
                      '[Standard View]',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text('|', style: TextStyle(color: AppColors.cardBorder)),
                  const SizedBox(width: 14),
                  // Create New Travel Request Link
                  GestureDetector(
                    onTap: onNewRequest,
                    child: const Text(
                      'Create New Travel Request',
                      style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text('|', style: TextStyle(color: AppColors.cardBorder)),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Travel Plan creation coming soon'))),
                    child: const Text(
                      'Create New Travel Plan',
                      style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text('|', style: TextStyle(color: AppColors.cardBorder)),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense Report creation coming soon'))),
                    child: const Text(
                      'Create New Expense Report',
                      style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Scrollable SAP spreadsheet Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: GlassCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(const Color(0xFFE2E8F0)),
                  dataRowColor: MaterialStateColor.resolveWith((states) => Colors.white),
                  horizontalMargin: 16,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary))),
                    DataColumn(label: Text('End Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary))),
                    DataColumn(label: Text('Destination', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary))),
                    DataColumn(label: Text('Reason', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary))),
                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary))),
                  ],
                  rows: tours.map((tour) {
                    return DataRow(
                      cells: [
                        DataCell(Text(DateFormat('dd/MM/yyyy').format(tour.startDate), style: const TextStyle(fontSize: 11))),
                        DataCell(Text(DateFormat('dd/MM/yyyy').format(tour.endDate), style: const TextStyle(fontSize: 11))),
                        DataCell(Text(tour.destination, style: const TextStyle(fontSize: 11))),
                        DataCell(Text(tour.travelPurpose, style: const TextStyle(fontSize: 11))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () => onEditRequest(tour),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => _TravelRequisitionDialog(tour: tour),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(Icons.print_outlined, size: 14, color: AppColors.success),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tour Calendar Tab (TableCalendar style) ─────────────────────
class _TourCalendarTab extends StatefulWidget {
  const _TourCalendarTab();

  @override
  State<_TourCalendarTab> createState() => _TourCalendarTabState();
}

class _TourCalendarTabState extends State<_TourCalendarTab>
    with SingleTickerProviderStateMixin {
  late TabController _subTabController;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  List<TourModel> _getEventsForDay(DateTime day, List<TourModel> tours) {
    return tours.where((tour) {
      final start = DateTime(tour.startDate.year, tour.startDate.month, tour.startDate.day);
      final end = DateTime(tour.endDate.year, tour.endDate.month, tour.endDate.day);
      final current = DateTime(day.year, day.month, day.day);
      return (current.isAtSameMomentAs(start) || current.isAfter(start)) &&
          (current.isAtSameMomentAs(end) || current.isBefore(end));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub tabs: Personal vs Team
        Container(
          color: AppColors.backgroundSecondary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              _SubTab(label: 'Calendar', index: 0, controller: _subTabController),
              const SizedBox(width: 8),
              _SubTab(label: 'Team Calendar', index: 1, controller: _subTabController),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              _buildPersonalCalendar(),
              _buildTeamCalendar(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalCalendar() {
    final tourController = context.watch<TourController>();
    final tours = tourController.tours;
    final selectedDayEvents = _selectedDay != null ? _getEventsForDay(_selectedDay!, tours) : <TourModel>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GlassCard(
            padding: EdgeInsets.zero,
            child: TableCalendar(
              firstDay: DateTime(2025),
              lastDay: DateTime(2027),
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
              eventLoader: (day) => _getEventsForDay(day, tours),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) => const SizedBox.shrink(),
                defaultBuilder: (context, day, focusedDay) {
                  final events = _getEventsForDay(day, tours);
                  if (events.isNotEmpty) {
                    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
                    return Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.officialTour.withOpacity(0.12),
                          border: Border.all(color: AppColors.officialTour.withOpacity(0.6), width: 1.5),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              color: isWeekend ? AppColors.error : AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return null;
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Day events list
          if (_selectedDay != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Tours for ${DateFormat('dd MMM yyyy').format(_selectedDay!)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
            ),
            if (selectedDayEvents.isEmpty)
              const GlassCard(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No tours scheduled for this day', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                ),
              )
            else
              ...selectedDayEvents.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.officialTour.withOpacity(0.08), shape: BoxShape.circle),
                        child: const Icon(Icons.flight_takeoff_rounded, color: AppColors.officialTour, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.destination, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 2),
                            Text(t.travelPurpose, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      StatusBadge(status: t.status),
                    ],
                  ),
                ),
              )),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamCalendar() {
    return const SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textHint),
              SizedBox(height: 12),
              Text('Team Travel Calendar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              SizedBox(height: 4),
              Text('Currently all team members are on-site.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubTab extends StatelessWidget {
  final String label;
  final int index;
  final TabController controller;

  const _SubTab({required this.label, required this.index, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isSelected = controller.index == index;
        return GestureDetector(
          onTap: () => controller.animateTo(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSelected ? Colors.transparent : AppColors.cardBorder),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Tour Status Tab ──────────────────────────────────────────────
class _TourStatusTab extends StatelessWidget {
  final void Function(TourModel) onEdit;
  final VoidCallback onNew;

  const _TourStatusTab({required this.onEdit, required this.onNew});

  @override
  Widget build(BuildContext context) {
    return Consumer<TourController>(
      builder: (context, controller, _) {
        if (controller.status == TourStatus.loading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (controller.tours.isEmpty) {
          return EmptyState(
            icon: Icons.flight_takeoff_outlined,
            title: 'No Tour Records',
            subtitle: 'You have not applied for any tours yet.',
            action: ElevatedButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add),
              label: const Text('Create New Tour'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SectionHeader(
                  title: 'Tour Data Overview',
                  icon: Icons.flight_rounded,
                  trailing: GestureDetector(
                    onTap: onNew,
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
                          Text('New', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
                ...controller.tours.asMap().entries.map((e) {
                  return _TourListItem(tour: e.value, isEven: e.key.isEven, onEdit: onEdit);
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TourListItem extends StatelessWidget {
  final TourModel tour;
  final bool isEven;
  final void Function(TourModel) onEdit;

  const _TourListItem({required this.tour, required this.isEven, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => _TravelRequisitionDialog(tour: tour),
            );
          },
          child: Container(
            color: isEven ? AppColors.background.withOpacity(0.3) : Colors.transparent,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flight_takeoff_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tour.tourType,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                tour.destination,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                '${DateFormat('dd.MM.yyyy').format(tour.startDate)} – ${DateFormat('dd.MM.yyyy').format(tour.endDate)}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tour.travelPurpose,
                        style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusBadge(status: tour.status),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (tour.status.toLowerCase() != 'approved') ...[
                          _ActionBtn(
                            icon: Icons.edit_outlined,
                            color: AppColors.primary,
                            onTap: () => onEdit(tour),
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (tour.status.toLowerCase() != 'approved')
                          _ActionBtn(
                            icon: Icons.delete_outline,
                            color: AppColors.error,
                            onTap: () => _showDeleteDialog(context),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.cardBorder),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tour Request'),
        content: Text(
          tour.status == 'Draft'
              ? 'Are you sure you want to delete this draft request?'
              : 'Are you sure you want to delete this tour request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<TourController>().deleteTour(tour.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(success ? 'Request deleted successfully.' : 'Failed to delete request.'),
                  backgroundColor: success ? AppColors.success : AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: color, size: 15),
      ),
    );
  }
}

// ─── Apply Tour Tab (SAP style) ──────────────────────────────────
class _ApplyTourTab extends StatefulWidget {
  final TourModel? editingTour;
  final VoidCallback onComplete;

  const _ApplyTourTab({super.key, this.editingTour, required this.onComplete});

  @override
  State<_ApplyTourTab> createState() => _ApplyTourTabState();
}

class _ApplyTourTabState extends State<_ApplyTourTab> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 1; // 1 = General Data, 2 = Review, 3 = Completed
  TourModel? _lastSubmittedTour;

  // Form Fields State
  String _countryRegion = 'India';
  final _destinationCtrl = TextEditingController();
  String _activity = 'Official Tour';
  final _reasonCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 0, minute: 0);
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _endTime = const TimeOfDay(hour: 0, minute: 0);

  double _advancesAmount = 0.0;
  final _advancesCtrl = TextEditingController(text: '0.00 Indian Rupee');
  final _costAssignmentCtrl = TextEditingController(
      text: '100.00 % Cost Center 100511 (100511), Company Code 1000 (MOIL LIMITED)');

  // Transport Checkboxes
  bool _airways = true;
  bool _selfScooter = false;
  bool _bus = false;
  bool _selfCar = false;
  bool _railways = false;
  bool _privateCar = false;

  bool _isSubmitting = false;
  List<PlatformFile> _attachments = [];

  @override
  void initState() {
    super.initState();
    if (widget.editingTour != null) {
      _loadTour(widget.editingTour!);
    } else {
      _resetForm();
    }
  }

  @override
  void didUpdateWidget(covariant _ApplyTourTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editingTour != oldWidget.editingTour) {
      if (widget.editingTour != null) {
        _loadTour(widget.editingTour!);
      } else {
        _resetForm();
      }
    }
  }

  @override
  void dispose() {
    _destinationCtrl.dispose();
    _reasonCtrl.dispose();
    _advancesCtrl.dispose();
    _costAssignmentCtrl.dispose();
    super.dispose();
  }

  void _loadTour(TourModel tour) {
    _countryRegion = tour.countryRegion;
    _destinationCtrl.text = tour.destination == 'Draft Destination' ? '' : tour.destination;
    _activity = tour.activity;
    _reasonCtrl.text = tour.travelPurpose == 'Draft Purpose' ? '' : tour.travelPurpose;
    _startDate = tour.startDate;
    _startTime = TimeOfDay(hour: tour.startDate.hour, minute: tour.startDate.minute);
    _endDate = tour.endDate;
    _endTime = TimeOfDay(hour: tour.endDate.hour, minute: tour.endDate.minute);
    _advancesAmount = tour.advances;
    _advancesCtrl.text = "${tour.advances.toStringAsFixed(2)} Indian Rupee";
    _costAssignmentCtrl.text = tour.costAssignment;
    _airways = tour.airways;
    _selfScooter = tour.selfScooter;
    _bus = tour.bus;
    _selfCar = tour.selfCar;
    _railways = tour.railways;
    _privateCar = tour.privateCar;
    _currentStep = 1;
  }

  void _resetForm() {
    _countryRegion = 'India';
    _destinationCtrl.clear();
    _activity = 'Official Tour';
    _reasonCtrl.clear();
    _startDate = DateTime.now();
    _startTime = const TimeOfDay(hour: 0, minute: 0);
    _endDate = DateTime.now().add(const Duration(days: 1));
    _endTime = const TimeOfDay(hour: 0, minute: 0);
    _advancesAmount = 0.0;
    _advancesCtrl.text = '0.00 Indian Rupee';
    _costAssignmentCtrl.text =
        '100.00 % Cost Center 100511 (100511), Company Code 1000 (MOIL LIMITED)';
    _airways = true;
    _selfScooter = false;
    _bus = false;
    _selfCar = false;
    _railways = false;
    _privateCar = false;
    _attachments.clear();
    _lastSubmittedTour = null;
    _currentStep = 1;
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _pickStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _pickStartTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _pickEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _pickEndTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  void _showAdvancesDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: _advancesAmount.toString());
        return AlertDialog(
          title: const Text('Enter Advances'),
          content: TextFormField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.black87),
            decoration: const InputDecoration(
              labelText: 'Advance Amount (INR)',
              prefixText: '₹ ',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final val = double.tryParse(ctrl.text) ?? 0.0;
                setState(() {
                  _advancesAmount = val;
                  _advancesCtrl.text = "${val.toStringAsFixed(2)} Indian Rupee";
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showCostAssignmentDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController(text: _costAssignmentCtrl.text);
        return AlertDialog(
          title: const Text('Change Cost Assignment'),
          content: TextFormField(
            controller: ctrl,
            maxLines: 3,
            style: const TextStyle(color: Colors.black87),
            decoration: const InputDecoration(
              labelText: 'Cost Assignment Details',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _costAssignmentCtrl.text = ctrl.text.trim();
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showCalendarOfTripsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return const _TourCalendarDialog();
      },
    );
  }

  void _showAttachmentsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Attachments', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_attachments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No documents attached yet.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _attachments.length,
                          itemBuilder: (c, idx) {
                            final file = _attachments[idx];
                            final sizeKb = (file.size / 1024).toStringAsFixed(1);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.insert_drive_file, color: AppColors.primary),
                              title: Text(
                                file.name,
                                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '$sizeKb KB',
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: AppColors.error, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _attachments.removeAt(idx);
                                  });
                                  setDialogState(() {}); // rebuild dialog
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.any,
                          allowMultiple: true,
                        );
                        if (result != null) {
                          setState(() {
                            _attachments.addAll(result.files);
                          });
                          setDialogState(() {}); // rebuild dialog
                        }
                      },
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Add Document'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Stepper Header ──────────────────────────────────────────────
  Widget _buildStepperHeader() {
    return Container(
      color: AppColors.primaryLight,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStepItem(
              stepNum: '1',
              title: 'General Data',
              isActive: _currentStep == 1,
              isCompleted: _currentStep > 1,
            ),
            _buildStepConnector(isCompleted: _currentStep > 1),
            _buildStepItem(
              stepNum: '2',
              title: 'Review and Send',
              isActive: _currentStep == 2,
              isCompleted: _currentStep > 2,
            ),
            _buildStepConnector(isCompleted: _currentStep > 2),
            _buildStepItem(
              stepNum: '3',
              title: 'Completed',
              isActive: _currentStep == 3,
              isCompleted: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepItem({
    required String stepNum,
    required String title,
    required bool isActive,
    required bool isCompleted,
  }) {
    Color boxColor = Colors.grey.shade300;
    Color titleColor = Colors.grey.shade600;
    Color boxTextColor = Colors.white;
    FontWeight fontWeight = FontWeight.normal;

    if (isActive) {
      boxColor = AppColors.primary;
      titleColor = AppColors.primary;
      boxTextColor = Colors.white;
      fontWeight = FontWeight.bold;
    } else if (isCompleted) {
      boxColor = AppColors.primary.withOpacity(0.6);
      titleColor = AppColors.primary.withOpacity(0.8);
      boxTextColor = Colors.white;
      fontWeight = FontWeight.w600;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: boxColor,
            border: Border.all(color: Colors.black12, width: 1.2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text(
                    stepNum,
                    style: TextStyle(
                      color: boxTextColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: titleColor,
            fontSize: 11,
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector({required bool isCompleted}) {
    return Container(
      width: 30,
      height: 2,
      color: isCompleted ? AppColors.primary : Colors.grey.shade400,
      margin: const EdgeInsets.only(left: 6, right: 6, bottom: 18),
    );
  }

  // ─── Employee Info Banner ─────────────────────────────────────────
  Widget _buildEmployeeBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.primary.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: const Text(
        'Employee G Rohini Kumar ( 00000468 )',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ─── SAP Styled Buttons ──────────────────────────────────────────
  Widget _buildActionButtonRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildSapButton(
            label: '◀ Previous Step',
            isEnabled: _currentStep > 1 && _currentStep < 3,
            onPressed: () {
              setState(() {
                _currentStep--;
              });
            },
          ),
          const SizedBox(width: 8),
          if (_currentStep == 1)
            _buildSapButton(
              label: 'Review ▷',
              isEnabled: true,
              isPrimary: true,
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  setState(() {
                    _currentStep = 2;
                  });
                }
              },
            )
          else if (_currentStep == 2)
            _buildSapButton(
              label: 'Send ▷',
              isEnabled: true,
              isPrimary: true,
              onPressed: _submitForm,
            ),
          const SizedBox(width: 8),
          if (_currentStep < 3)
            _buildSapButton(
              label: 'Save Draft',
              isEnabled: true,
              onPressed: _saveDraft,
            ),
        ],
      ),
    );
  }

  Widget _buildSapButton({
    required String label,
    required bool isEnabled,
    bool isPrimary = false,
    required VoidCallback onPressed,
  }) {
    Color bg = Colors.transparent;
    Color text = AppColors.primary;
    Color border = AppColors.primary.withOpacity(0.3);

    if (isEnabled) {
      if (isPrimary) {
        bg = AppColors.primary;
        text = Colors.white;
        border = AppColors.primary;
      } else {
        bg = AppColors.primary.withOpacity(0.06);
        text = AppColors.primary;
        border = AppColors.primary.withOpacity(0.2);
      }
    } else {
      bg = Colors.grey.shade200;
      text = Colors.grey.shade500;
      border = Colors.grey.shade300;
    }

    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 1.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: text,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickLinks() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showCalendarOfTripsDialog,
            child: _buildQuickLinkBtn(label: '▶ Calendar of Trips'),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _showAttachmentsDialog,
            child: _buildQuickLinkBtn(label: '▶ Attachments (${_attachments.length})'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLinkBtn({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ─── Table Form Layout Helpers ────────────────────────────────────
  Widget _buildFormRow({
    required String label,
    required Widget field,
    bool isRequired = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 450;
        
        final labelWidget = Row(
          mainAxisAlignment: isMobile ? MainAxisAlignment.start : MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRequired)
              const Text(
                '* ',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: isMobile ? TextAlign.start : TextAlign.end,
              ),
            ),
          ],
        );

        if (isMobile) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: 6),
                field,
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isRequired)
                      const Text(
                        '* ',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: field,
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Form Section Widgets (Step 1) ────────────────────────────────
  Widget _buildGeneralDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'General Data',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
        _buildFormRow(
          label: 'Start Date/Time:',
          isRequired: true,
          field: Row(
            children: [
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () => _pickStartDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('yyyy-MM-dd').format(_startDate),
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                        Icon(Icons.calendar_month, size: 16, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () => _pickStartTime(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTimeOfDay(_startTime),
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        _buildFormRow(
          label: 'End Date/Time:',
          field: Row(
            children: [
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () => _pickEndDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('yyyy-MM-dd').format(_endDate),
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                        Icon(Icons.calendar_month, size: 16, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 1,
                child: GestureDetector(
                  onTap: () => _pickEndTime(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatTimeOfDay(_endTime),
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                        Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 168, top: 2, bottom: 8, right: 16),
          child: Container(
            width: double.infinity,
            color: AppColors.primaryLight,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: const Text(
              '(Enter Time in 24 hrs Format)',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDestinationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Destination',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
        _buildFormRow(
          label: 'Country / Region:',
          field: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _countryRegion,
                isExpanded: true,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                items: const [
                  DropdownMenuItem(value: 'India', child: Text('India')),
                  DropdownMenuItem(value: 'United States', child: Text('United States')),
                  DropdownMenuItem(value: 'Singapore', child: Text('Singapore')),
                  DropdownMenuItem(value: 'United Kingdom', child: Text('United Kingdom')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _countryRegion = val;
                    });
                  }
                },
              ),
            ),
          ),
        ),
        _buildFormRow(
          label: 'Destination:',
          field: TextFormField(
            controller: _destinationCtrl,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              suffixIcon: const Icon(Icons.search, size: 16, color: Colors.black54),
              suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 20),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Destination is required' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Additional Information',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
        _buildFormRow(
          label: 'Activity (Planning):',
          field: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _activity,
                isExpanded: true,
                dropdownColor: Colors.white,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
                items: const [
                  DropdownMenuItem(value: 'Official Tour', child: Text('Official Tour')),
                  DropdownMenuItem(value: 'Training', child: Text('Training')),
                  DropdownMenuItem(value: 'Conference', child: Text('Conference')),
                  DropdownMenuItem(value: 'Client Visit', child: Text('Client Visit')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _activity = val;
                    });
                  }
                },
              ),
            ),
          ),
        ),
        _buildFormRow(
          label: 'Reason:',
          field: TextFormField(
            controller: _reasonCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              suffixIcon: const Icon(Icons.note_alt_outlined, size: 16, color: Colors.black54),
              suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 20),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Reason is required' : null,
          ),
        ),
        _buildFormRow(
          label: 'Advances:',
          field: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _advancesCtrl,
                  readOnly: true,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: AppColors.inputBg,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSapButton(
                label: 'Enter Advances',
                isEnabled: true,
                onPressed: _showAdvancesDialog,
              ),
            ],
          ),
        ),
        _buildFormRow(
          label: 'Cost Assignment:',
          field: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _costAssignmentCtrl,
                  readOnly: true,
                  style: const TextStyle(fontSize: 11, color: Colors.black87),
                  maxLines: 1,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: AppColors.inputBg,
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildSapButton(
                label: 'Change Cost Assignment',
                isEnabled: true,
                onPressed: _showCostAssignmentDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeansOfTransportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Means of Transport to be Approved',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
        _buildCheckboxRow(
          label: 'Airways:',
          value: _airways,
          onChanged: (v) => setState(() => _airways = v ?? false),
        ),
        _buildCheckboxRow(
          label: 'Self Scooter:',
          value: _selfScooter,
          onChanged: (v) => setState(() => _selfScooter = v ?? false),
        ),
        _buildCheckboxRow(
          label: 'Bus:',
          value: _bus,
          onChanged: (v) => setState(() => _bus = v ?? false),
        ),
        _buildCheckboxRow(
          label: 'Self Car:',
          value: _selfCar,
          onChanged: (v) => setState(() => _selfCar = v ?? false),
        ),
        _buildCheckboxRow(
          label: 'Railways:',
          value: _railways,
          onChanged: (v) => setState(() => _railways = v ?? false),
        ),
        _buildCheckboxRow(
          label: 'Private Car:',
          value: _privateCar,
          onChanged: (v) => setState(() => _privateCar = v ?? false),
        ),
      ],
    );
  }

  Widget _buildCheckboxRow({
    required String label,
    required bool value,
    required void Function(bool?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: value,
              activeColor: AppColors.primary,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step Views ──────────────────────────────────────────────────
  Widget _buildFormStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuickLinks(),
          const SizedBox(height: 10),
          _buildGeneralDataSection(),
          _buildDestinationSection(),
          _buildAdditionalInfoSection(),
          _buildMeansOfTransportSection(),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    List<String> selectedTransport = [];
    if (_airways) selectedTransport.add('Airways');
    if (_selfScooter) selectedTransport.add('Self Scooter');
    if (_bus) selectedTransport.add('Bus');
    if (_selfCar) selectedTransport.add('Self Car');
    if (_railways) selectedTransport.add('Railways');
    if (_privateCar) selectedTransport.add('Private Car');
    if (selectedTransport.isEmpty) selectedTransport.add('None Selected');

    final startDateTimeStr =
        "${DateFormat('yyyy-MM-dd').format(_startDate)} ${_formatTimeOfDay(_startTime)}";
    final endDateTimeStr =
        "${DateFormat('yyyy-MM-dd').format(_endDate)} ${_formatTimeOfDay(_endTime)}";

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Review Your Travel Request',
              icon: Icons.rate_review_outlined,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  InfoRow(label: 'Start Date/Time', value: startDateTimeStr),
                  InfoRow(label: 'End Date/Time', value: endDateTimeStr),
                  InfoRow(label: 'Country / Region', value: _countryRegion),
                  InfoRow(label: 'Destination', value: _destinationCtrl.text.trim()),
                  InfoRow(label: 'Activity (Planning)', value: _activity),
                  InfoRow(label: 'Reason', value: _reasonCtrl.text.trim()),
                  InfoRow(label: 'Advances Requested', value: _advancesCtrl.text),
                  InfoRow(label: 'Cost Assignment', value: _costAssignmentCtrl.text),
                  InfoRow(label: 'Means of Transport', value: selectedTransport.join(', ')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
            ),
            const SizedBox(height: 18),
            const Text(
              'Travel Request Submitted!',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your travel request has been successfully processed and submitted for approval.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: widget.onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('View Tour Status'),
                ),
                if (_lastSubmittedTour != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      final auth = context.read<AuthController>();
                      final userName = auth.user?.name ?? 'Nitin Pagnis';
                      final employeeId = auth.user?.employeeId ?? '00000265';
                      _TravelRequisitionDialog.printTourDocument(
                          context, _lastSubmittedTour!, userName, employeeId);
                    },
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Print Request'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _resetForm();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Apply New Tour'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Form Submission & Draft Saving ──────────────────────────────
  Future<void> _submitForm() async {
    setState(() => _isSubmitting = true);
    final auth = context.read<AuthController>();

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    List<String> transportModes = [];
    if (_airways) transportModes.add('Airways');
    if (_selfScooter) transportModes.add('Self Scooter');
    if (_bus) transportModes.add('Bus');
    if (_selfCar) transportModes.add('Self Car');
    if (_railways) transportModes.add('Railways');
    if (_privateCar) transportModes.add('Private Car');
    final transportModeStr = transportModes.isEmpty ? 'Other' : transportModes.join(', ');

    final tour = TourModel(
      id: widget.editingTour?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      employeeId: auth.user?.employeeId ?? '00000468',
      tourType: _activity,
      destination: _destinationCtrl.text.trim(),
      startDate: startDateTime,
      endDate: endDateTime,
      travelPurpose: _reasonCtrl.text.trim(),
      transportMode: transportModeStr,
      status: 'Pending',
      appliedOn: DateTime.now(),
      countryRegion: _countryRegion,
      activity: _activity,
      advances: _advancesAmount,
      costAssignment: _costAssignmentCtrl.text.trim(),
      airways: _airways,
      selfScooter: _selfScooter,
      bus: _bus,
      selfCar: _selfCar,
      railways: _railways,
      privateCar: _privateCar,
    );

    final success = await context.read<TourController>().applyTour(tour);
    setState(() => _isSubmitting = false);
    if (success) {
      setState(() {
        _lastSubmittedTour = tour;
        _currentStep = 3;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to submit tour request. Please try again.'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Future<void> _saveDraft() async {
    setState(() => _isSubmitting = true);
    final auth = context.read<AuthController>();

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    List<String> transportModes = [];
    if (_airways) transportModes.add('Airways');
    if (_selfScooter) transportModes.add('Self Scooter');
    if (_bus) transportModes.add('Bus');
    if (_selfCar) transportModes.add('Self Car');
    if (_railways) transportModes.add('Railways');
    if (_privateCar) transportModes.add('Private Car');
    final transportModeStr = transportModes.isEmpty ? 'Other' : transportModes.join(', ');

    final tour = TourModel(
      id: widget.editingTour?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      employeeId: auth.user?.employeeId ?? '00000468',
      tourType: _activity,
      destination: _destinationCtrl.text.trim().isEmpty ? 'Draft Destination' : _destinationCtrl.text.trim(),
      startDate: startDateTime,
      endDate: endDateTime,
      travelPurpose: _reasonCtrl.text.trim().isEmpty ? 'Draft Purpose' : _reasonCtrl.text.trim(),
      transportMode: transportModeStr,
      status: 'Draft',
      appliedOn: DateTime.now(),
      countryRegion: _countryRegion,
      activity: _activity,
      advances: _advancesAmount,
      costAssignment: _costAssignmentCtrl.text.trim(),
      airways: _airways,
      selfScooter: _selfScooter,
      bus: _bus,
      selfCar: _selfCar,
      railways: _railways,
      privateCar: _privateCar,
    );

    final success = await context.read<TourController>().applyTour(tour);
    setState(() => _isSubmitting = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(success ? 'Tour request saved as draft!' : 'Failed to save draft.'),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
    if (success) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isSubmitting,
      message: _currentStep == 2 ? 'Submitting Travel Request...' : 'Saving Draft...',
      child: Column(
        children: [
          _buildStepperHeader(),
          _buildEmployeeBanner(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildActionButtonRow(),
                  if (_currentStep == 1)
                    _buildFormStep()
                  else if (_currentStep == 2)
                    _buildReviewStep()
                  else if (_currentStep == 3)
                    _buildCompletedStep(),
                  if (_currentStep < 3) _buildActionButtonRow(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TourCalendarDialog extends StatefulWidget {
  const _TourCalendarDialog();

  @override
  State<_TourCalendarDialog> createState() => _TourCalendarDialogState();
}

class _TourCalendarDialogState extends State<_TourCalendarDialog> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  List<TourModel> _getEventsForDay(DateTime day, List<TourModel> tours) {
    return tours.where((tour) {
      final start = DateTime(tour.startDate.year, tour.startDate.month, tour.startDate.day);
      final end = DateTime(tour.endDate.year, tour.endDate.month, tour.endDate.day);
      final target = DateTime(day.year, day.month, day.day);
      return !target.isBefore(start) && !target.isAfter(end);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    _selectedDay ??= DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(16),
        child: Consumer<TourController>(
          builder: (context, controller, _) {
            final eventsOnSelectedDay = _getEventsForDay(_selectedDay!, controller.tours);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Calendar of Trips',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TableCalendar(
                          firstDay: DateTime(2024),
                          lastDay: DateTime(2028),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          calendarFormat: _calendarFormat,
                          onFormatChanged: (format) {
                            setState(() {
                              _calendarFormat = format;
                            });
                          },
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          eventLoader: (day) => _getEventsForDay(day, controller.tours),
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, date, events) => const SizedBox.shrink(),
                            defaultBuilder: (context, day, focusedDay) {
                              final events = _getEventsForDay(day, controller.tours);
                              if (events.isNotEmpty) {
                                final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
                                return Center(
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.officialTour.withOpacity(0.12),
                                      border: Border.all(color: AppColors.officialTour.withOpacity(0.5), width: 1.5),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          color: isWeekend ? AppColors.error : AppColors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return null;
                            },
                          ),
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
                              color: AppColors.officialTour,
                              shape: BoxShape.circle,
                            ),
                            outsideDaysVisible: false,
                          ),
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            leftChevronIcon: Icon(Icons.chevron_left, color: AppColors.textSecondary),
                            rightChevronIcon: Icon(Icons.chevron_right, color: AppColors.textSecondary),
                          ),
                          daysOfWeekStyle: const DaysOfWeekStyle(
                            weekdayStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            weekendStyle: TextStyle(color: AppColors.error, fontSize: 11),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Legend
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.officialTour,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Travel/Tour Days',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Selected day events list
                        Text(
                          DateFormat('dd MMMM yyyy').format(_selectedDay!),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (eventsOnSelectedDay.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No tour scheduled on this day',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          )
                        else
                          ...eventsOnSelectedDay.map((e) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.cardBorder),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            e.tourType,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Destination: ${e.destination}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            'Purpose: ${e.travelPurpose}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    StatusBadge(status: e.status),
                                  ],
                                ),
                              )),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TravelRequisitionDialog extends StatelessWidget {
  final TourModel tour;

  const _TravelRequisitionDialog({super.key, required this.tour});

  static String _getCostCenter(String costAssignment) {
    if (costAssignment.contains('Cost Center')) {
      final parts = costAssignment.split('Cost Center');
      if (parts.length > 1) {
        return parts[1].split(',').first.trim();
      }
    }
    return costAssignment;
  }

  static Future<void> printTourDocument(BuildContext context, TourModel tour, String userName, String employeeId) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Container(
                        width: 40,
                        height: 40,
                        decoration: const pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          color: PdfColor.fromInt(0xFF0F2080),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'MOIL',
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'MOIL LIMITED',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Travel Requisition',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                pw.Divider(thickness: 1.2),
                pw.SizedBox(height: 8),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfRow('Trip No', tour.id),
                          _buildPdfRow('Name', userName),
                          _buildPdfRow('Emp Grp', employeeId),
                          _buildPdfRow('Purpose of journey', tour.travelPurpose),
                          _buildPdfRow('Date of Requisition', DateFormat('dd-MMM-yy').format(tour.appliedOn ?? DateTime.now())),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildPdfRow('Emp No', tour.employeeId),
                          _buildPdfRow('Basic Pay', '1,27,960'),
                          _buildPdfRow('Department', 'Industrial Relations, Trai'),
                          _buildPdfRow('Cost Center', _getCostCenter(tour.costAssignment)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                _buildPdfSectionHeader('Journey Details'),
                _buildPdfRow('Destination', tour.destination),
                pw.Row(
                  children: [
                    pw.Expanded(child: _buildPdfRow('From Date', DateFormat('dd-MMM-yy').format(tour.startDate))),
                    pw.Expanded(child: _buildPdfRow('To Date', DateFormat('dd-MMM-yy').format(tour.endDate))),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Expanded(child: _buildPdfRow('From Time', DateFormat('hh:mm:ss a').format(tour.startDate))),
                    pw.Expanded(child: _buildPdfRow('To Time', DateFormat('hh:mm:ss a').format(tour.endDate))),
                  ],
                ),
                _buildPdfSectionHeader('Conveyance Details'),
                _buildPdfRow('Mode of Conveyance', tour.transportMode),
                _buildPdfSectionHeader('Advance Details'),
                _buildPdfRow('Advance Required', tour.advances > 0 ? 'Yes' : 'No'),
                _buildPdfRow('Advance Amount (In Rupees)', tour.advances > 0 ? tour.advances.toStringAsFixed(2) : '0.00'),
                _buildPdfSectionHeader('Comments'),
                pw.Text(tour.remarks ?? '', style: const pw.TextStyle(fontSize: 10)),
                _buildPdfSectionHeader('Approvers'),
                _buildPdfRow('Reporting Manager', 'Usha Singh'),
                _buildPdfRow('Department Head', tour.status == 'Approved' ? (tour.processor ?? 'HOD User') : ''),
                _buildPdfRow('Verified - Finance Officer', ''),
                _buildPdfRow('Approved - Finance Head', ''),
                _buildPdfRow('Agent', ''),
                _buildPdfSectionHeader('Request Status'),
                _buildPdfRow('Status', tour.status),
                _buildPdfRow('Date of Approval', tour.status == 'Approved' ? '07.03.2026' : 'N/A'),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Travel_Requisition_${tour.id}.pdf',
    );
  }

  static pw.Widget _buildPdfSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      color: PdfColors.grey300,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const pw.EdgeInsets.only(top: 10, bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildPdfRow(String key, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              key,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Text(' : ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade300,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildRow(String key, String value, {double keyWidth = 110}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: keyWidth,
            child: Text(
              key,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ),
          const Text(' : ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 10, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    final userName = auth.user?.name ?? 'Nitin Pagnis';
    final employeeId = auth.user?.employeeId ?? '00000265';

    final requisitionDateStr = DateFormat('dd-MMM-yy').format(tour.appliedOn ?? DateTime.now());
    final fromDateStr = DateFormat('dd-MMM-yy').format(tour.startDate);
    final toDateStr = DateFormat('dd-MMM-yy').format(tour.endDate);
    final fromTimeStr = DateFormat('hh:mm:ss a').format(tour.startDate);
    final toTimeStr = DateFormat('hh:mm:ss a').format(tour.endDate);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.print, size: 20, color: AppColors.primary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => printTourDocument(context, tour, userName, employeeId),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF0F2080),
                            ),
                            child: const Center(
                              child: Text(
                                'मॉयल\nMOIL',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'MOIL LIMITED',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const Text(
                            'Travel Requisition',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.black87, thickness: 1.2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRow('Trip No', tour.id),
                              _buildRow('Name', userName),
                              _buildRow('Emp Grp', employeeId),
                              _buildRow('Purpose of journey', tour.travelPurpose),
                              _buildRow('Date of Requisition', requisitionDateStr),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRow('Emp No', tour.employeeId),
                              _buildRow('Basic Pay', '1,27,960'),
                              _buildRow('Department', 'Industrial Relations, Trai'),
                              _buildRow('Cost Center', _getCostCenter(tour.costAssignment)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    _buildSectionHeader('Journey Details'),
                    _buildRow('Destination', tour.destination),
                    Row(
                      children: [
                        Expanded(child: _buildRow('From Date', fromDateStr)),
                        Expanded(child: _buildRow('To Date', toDateStr)),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(child: _buildRow('From Time', fromTimeStr)),
                        Expanded(child: _buildRow('To Time', toTimeStr)),
                      ],
                    ),
                    _buildSectionHeader('Conveyance Details'),
                    _buildRow('Mode of Conveyance', tour.transportMode),
                    _buildSectionHeader('Advance Details'),
                    _buildRow('Advance Required', tour.advances > 0 ? 'Yes' : 'No'),
                    _buildRow('Advance Amount (In Rupees)', tour.advances > 0 ? tour.advances.toStringAsFixed(2) : '0.00'),
                    _buildSectionHeader('Comments'),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              tour.remarks ?? '',
                              style: const TextStyle(fontSize: 10, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildSectionHeader('Approvers'),
                    _buildRow('Reporting Manager', 'Usha Singh'),
                    _buildRow('Department Head', tour.status == 'Approved' ? (tour.processor ?? 'HOD User') : ''),
                    _buildRow('Verified - Finance Officer', ''),
                    _buildRow('Approved - Finance Head', ''),
                    _buildRow('Agent', ''),
                    _buildSectionHeader('Request Status'),
                    _buildRow('Status', tour.status),
                    _buildRow('Date of Approval', tour.status == 'Approved' ? '07.03.2026' : 'N/A'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
