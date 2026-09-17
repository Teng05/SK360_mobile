import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';

class PrototypeCalendarScreen extends StatefulWidget {
  const PrototypeCalendarScreen({super.key});

  @override
  State<PrototypeCalendarScreen> createState() =>
      _PrototypeCalendarScreenState();
}

class _PrototypeCalendarScreenState extends State<PrototypeCalendarScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  Map<String, dynamic> get _data => MobileApiService.syncedData ?? {};
  Map<String, dynamic> get _user => MobileApiService.currentUser ?? {};
  bool get _canScheduleEvents => _user['role']?.toString() == 'sk_president';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final barangay = _user['barangay_name']?.toString() ?? 'Barangay';
    final events = [
      ..._rows('events'),
      ..._rows('meetings'),
      ..._slotEvents(),
    ];
    final selectedEvents = events
        .where((event) => _isSameDay(_eventDate(event), _selectedDate))
        .toList();

    return Scaffold(
      key: _scaffoldKey,
      drawer: const PresidentSideDrawer(),
      backgroundColor: AppColors.lightGrayBg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(86),
        child: SafeArea(
          bottom: false,
          child: PresidentHeader(
            leading: PresidentHeaderLeading.menu,
            onLeadingTap: () => _scaffoldKey.currentState?.openDrawer(),
            title: 'Calendar',
            subtitle: barangay,
          ),
        ),
      ),
      bottomNavigationBar: PresidentBottomNavBar(
        activeItem: PresidentNavItem.calendar,
        onItemSelected: _handleNavSelection,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (_isLoading) const LinearProgressIndicator(minHeight: 3),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _HeroCard(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _MonthCalendar(
                  month: _visibleMonth,
                  selectedDate: _selectedDate,
                  eventDates: events
                      .map(_eventDate)
                      .whereType<DateTime>()
                      .toList(),
                  onPrevious: () => setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month - 1,
                    );
                  }),
                  onNext: () => setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month + 1,
                    );
                  }),
                  onSelected: (date) => setState(() => _selectedDate = date),
                ),
              ),
              if (_canScheduleEvents)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: ElevatedButton.icon(
                    onPressed: _showScheduleDialog,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+ Schedule New Event'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF10612),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _EventsForDateCard(
                  date: _selectedDate,
                  events: selectedEvents,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _AllEventsCard(events: events),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _rows(String key) {
    final rows = _data[key] as List<dynamic>? ?? [];
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  List<Map<String, dynamic>> _slotEvents() {
    return _rows('submission_slots').map((slot) {
      final type = slot['submission_type']?.toString() == 'budget_report'
          ? 'budget_slot'
          : 'report_slot';

      return {
        ...slot,
        'title': slot['title'] ?? 'Submission Slot',
        'event_type': type,
        'start_datetime': slot['start_date'],
        'end_datetime': slot['end_date'],
      };
    }).toList();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      await MobileApiService.sync();
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleNavSelection(PresidentNavItem item) {
    if (item == PresidentNavItem.calendar) return;
    handleRoleNavSelection(context, item);
  }

  Future<void> _showScheduleDialog() async {
    if (!_canScheduleEvents) return;

    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime startDate = _selectedDate;
    DateTime endDate = _selectedDate;
    String eventType = 'program';
    String visibility = 'public';
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text('New Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogField(controller: titleController, hint: 'Event Title'),
                const SizedBox(height: 10),
                _DialogField(
                  controller: descriptionController,
                  hint: 'Description',
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerField(
                        label: 'Start date',
                        date: startDate,
                        onTap: () async {
                          final picked = await _pickDate(startDate);
                          if (picked == null) return;

                          setDialogState(() {
                            startDate = picked;
                            if (endDate.isBefore(startDate)) {
                              endDate = startDate;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DatePickerField(
                        label: 'End date',
                        date: endDate,
                        firstDate: startDate,
                        onTap: () async {
                          final picked = await _pickDate(
                            endDate.isBefore(startDate) ? startDate : endDate,
                            firstDate: startDate,
                          );
                          if (picked == null) return;

                          setDialogState(() => endDate = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: eventType,
                        items: const [
                          DropdownMenuItem(
                            value: 'program',
                            child: Text('Event/Program'),
                          ),
                          DropdownMenuItem(
                            value: 'meeting',
                            child: Text('Meeting'),
                          ),
                          DropdownMenuItem(
                            value: 'deadline',
                            child: Text('Deadline'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => eventType = value ?? 'program'),
                        decoration: _inputDecoration('Event Type'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: visibility,
                        items: const [
                          DropdownMenuItem(
                            value: 'public',
                            child: Text('Public'),
                          ),
                          DropdownMenuItem(
                            value: 'officials_only',
                            child: Text('Officials'),
                          ),
                          DropdownMenuItem(
                            value: 'chairman_only',
                            child: Text('Chairmen'),
                          ),
                          DropdownMenuItem(
                            value: 'secretary_only',
                            child: Text('Secretaries'),
                          ),
                        ],
                        onChanged: (value) => setDialogState(
                          () => visibility = value ?? 'public',
                        ),
                        decoration: _inputDecoration('Visibility'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        _showMessage('Enter an event title.');
                        return;
                      }

                      if (endDate.isBefore(startDate)) {
                        _showMessage('End date cannot be before start date.');
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      final created = await _createEvent(
                        title: titleController.text.trim(),
                        description: descriptionController.text.trim(),
                        startDateTime: DateTime(
                          startDate.year,
                          startDate.month,
                          startDate.day,
                        ),
                        endDateTime: DateTime(
                          endDate.year,
                          endDate.month,
                          endDate.day,
                          23,
                          59,
                        ),
                        eventType: eventType,
                        visibility: visibility,
                      );
                      if (created) {
                        if (context.mounted) Navigator.pop(context);
                      } else {
                        setDialogState(() => isSubmitting = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF10612),
                foregroundColor: Colors.white,
              ),
              child: Text(isSubmitting ? 'Creating...' : 'Create Event'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initialDate, {DateTime? firstDate}) {
    final earliest = firstDate ?? DateTime(DateTime.now().year - 1);
    final safeInitial = initialDate.isBefore(earliest) ? earliest : initialDate;

    return showDatePicker(
      context: context,
      initialDate: safeInitial,
      firstDate: earliest,
      lastDate: DateTime(DateTime.now().year + 5),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryRed,
            onPrimary: Colors.white,
            onSurface: AppColors.darkGray,
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  Future<bool> _createEvent({
    required String title,
    required String description,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required String eventType,
    required String visibility,
  }) async {
    setState(() => _isLoading = true);
    try {
      await MobileApiService.createEvent(
        title: title,
        description: description,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        eventType: eventType,
        visibility: visibility,
      );
      if (mounted) _showMessage('Event created.');
      return true;
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
      return false;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primaryRed),
    );
  }
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF10612),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.calendar_month, color: Colors.white),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calendar & Events',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Manage meetings, activities, and deadlines',
                style: TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final List<DateTime> eventDates;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<DateTime> onSelected;

  const _MonthCalendar({
    required this.month,
    required this.selectedDate,
    required this.eventDates,
    required this.onPrevious,
    required this.onNext,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday % 7;
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(leading, null),
      ...List.generate(
        daysInMonth,
        (index) => DateTime(month.year, month.month, index + 1),
      ),
    ];

    return _CalendarPanel(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '${_monthName(month.month)} ${month.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const Row(
            children: [
              _Weekday('S'),
              _Weekday('M'),
              _Weekday('T'),
              _Weekday('W'),
              _Weekday('T'),
              _Weekday('F'),
              _Weekday('S'),
            ],
          ),
          GridView.builder(
            itemCount: cells.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemBuilder: (context, index) {
              final date = cells[index];
              if (date == null) return const SizedBox.shrink();

              final selected = _isSameDay(date, selectedDate);
              final hasEvent = eventDates.any(
                (eventDate) => _isSameDay(eventDate, date),
              );

              return GestureDetector(
                onTap: () => onSelected(date),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primaryRed : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: selected ? Colors.white : AppColors.darkGray,
                        ),
                      ),
                      if (hasEvent)
                        Positioned(
                          bottom: 3,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFFFFC107),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Weekday extends StatelessWidget {
  final String label;

  const _Weekday(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.lightText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _EventsForDateCard extends StatelessWidget {
  final DateTime date;
  final List<Map<String, dynamic>> events;

  const _EventsForDateCard({required this.date, required this.events});

  @override
  Widget build(BuildContext context) {
    return _CalendarPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Events on ${_monthName(date.month)} ${date.day}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const SizedBox(
              height: 120,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      color: AppColors.lightText,
                      size: 36,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No events scheduled for this date',
                      style: TextStyle(
                        color: AppColors.lightText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...events.map((event) => _EventTile(event: event)),
        ],
      ),
    );
  }
}

class _AllEventsCard extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const _AllEventsCard({required this.events});

  @override
  Widget build(BuildContext context) {
    final visible = events.take(5).toList();

    return _CalendarPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'All Upcoming Events',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const Text(
              'No upcoming events yet',
              style: TextStyle(color: AppColors.lightText),
            )
          else
            ...visible.map((event) => _EventTile(event: event)),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Map<String, dynamic> event;

  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final title = event['title']?.toString() ?? 'Event';
    final date = _eventDate(event);
    final type = _eventTypeLabel(event['event_type']?.toString() ?? 'other');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.softPink,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  _monthShort(date),
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppColors.primaryRed,
                  ),
                ),
                Text(
                  '${date?.day ?? '--'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryRed,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  type,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.lightText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  final Widget child;

  const _CalendarPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _DialogField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: _inputDecoration(hint),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final DateTime? firstDate;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.date,
    this.firstDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: _inputDecoration(label).copyWith(
          suffixIcon: const Icon(
            Icons.calendar_month,
            color: AppColors.primaryRed,
          ),
        ),
        child: Text(
          _dateText(date),
          style: const TextStyle(
            color: AppColors.darkGray,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.softPink,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.borderPink),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.borderPink),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.primaryRed),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}

DateTime? _eventDate(Map<String, dynamic> event) {
  final raw =
      event['start_datetime'] ??
      event['start_date'] ??
      event['meeting_date'] ??
      event['created_at'];
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString());
}

String _dateText(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');

  return '${date.year}-$month-$day';
}

bool _isSameDay(DateTime? a, DateTime b) {
  return a != null && a.year == b.year && a.month == b.month && a.day == b.day;
}

String _monthName(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return months[month - 1];
}

String _monthShort(DateTime? date) {
  if (date == null) return '---';
  return _monthName(date.month).substring(0, 3);
}

String _eventTypeLabel(String type) {
  switch (type) {
    case 'meeting':
      return 'Meeting';
    case 'program':
      return 'Event/Program';
    case 'deadline':
      return 'Deadline';
    case 'report_slot':
      return 'Report Slot';
    case 'budget_slot':
      return 'Budget Slot';
    default:
      return 'Other Activity';
  }
}
