import 'package:flutter/material.dart';

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
  String? _loadError;

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
    final events = [..._rows('events'), ..._rows('meetings'), ..._slotEvents()];
    final selectedEvents = events
        .where((event) => _isSameDay(_eventDate(event), _selectedDate))
        .toList();

    return Scaffold(
      key: _scaffoldKey,
      drawer: const PresidentSideDrawer(),
      backgroundColor: AppColors.lightGrayBg,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          (MediaQuery.textScalerOf(context).scale(1) > 1.2 ? 92 : 76) *
              MediaQuery.textScalerOf(context).scale(1),
        ),
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
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (_isLoading) const AppLoadingIndicator(),
              if (_loadError != null)
                AppEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Unable to refresh',
                  message:
                      'Check your connection and try again. Previously loaded records may still be shown.',
                  onAction: _refresh,
                ),
              AppPageIntro(
                title: 'Calendar',
                subtitle:
                    'Make room for what matters. Meetings, activities, and '
                    'submission dates in one place.',
                action: _canScheduleEvents
                    ? FilledButton.icon(
                        onPressed: _showScheduleDialog,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text('Schedule event'),
                      )
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _MonthCalendar(
                  month: _visibleMonth,
                  selectedDate: _selectedDate,
                  eventDates: [
                    for (final event in events)
                      if (_eventDate(event) case final date?)
                        (date, _eventColor(event)),
                  ],
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                child: _EventsForDateCard(
                  date: _selectedDate,
                  events: selectedEvents,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
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
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      await MobileApiService.sync();
    } on MobileApiException catch (exception) {
      if (mounted) setState(() => _loadError = exception.message);
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

    DateTime startDate = _selectedDate;
    DateTime endDate = _selectedDate;
    String eventType = 'program';
    String visibility = 'public';
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) => AppDialogForm(
        builder: (context, controllers) {
          final titleController = controllers[0];
          final descriptionController = controllers[1];
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              icon: const AppIconTile(icon: Icons.event_available_outlined),
              title: const Text('New Event'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _DialogField(
                        controller: titleController,
                        hint: 'Event Title',
                      ),
                      const SizedBox(height: 10),
                      _DialogField(
                        controller: descriptionController,
                        hint: 'Description',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      AppAdaptiveRow(
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
                                  endDate.isBefore(startDate)
                                      ? startDate
                                      : endDate,
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
                      AppAdaptiveRow(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
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
                              onChanged: (value) => setDialogState(
                                () => eventType = value ?? 'program',
                              ),
                              decoration: _inputDecoration(
                                'Event Type',
                                label: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
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
                              decoration: _inputDecoration(
                                'Visibility',
                                label: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (titleController.text.trim().isEmpty) {
                            _showMessage('Enter an event title.');
                            return;
                          }

                          if (endDate.isBefore(startDate)) {
                            _showMessage(
                              'End date cannot be before start date.',
                            );
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
                  child: Text(isSubmitting ? 'Creating...' : 'Create Event'),
                ),
              ],
            ),
          );
        },
      ),
    );
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MonthCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDate;
  final List<(DateTime, Color)> eventDates;
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
    final today = DateTime.now();
    final cells = <DateTime?>[
      ...List<DateTime?>.filled(leading, null),
      ...List.generate(
        daysInMonth,
        (index) => DateTime(month.year, month.month, index + 1),
      ),
    ];

    return AppSurface(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Column(
        children: [
          Row(
            children: [
              _MonthButton(
                tooltip: 'Previous month',
                icon: Icons.chevron_left_rounded,
                onPressed: onPrevious,
              ),
              Expanded(
                child: Text(
                  '${_monthName(month.month)} ${month.year}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _MonthButton(
                tooltip: 'Next month',
                icon: Icons.chevron_right_rounded,
                onPressed: onNext,
              ),
            ],
          ),
          const SizedBox(height: 10),
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
          const SizedBox(height: 4),
          GridView.builder(
            itemCount: cells.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 48,
            ),
            itemBuilder: (context, index) {
              final date = cells[index];
              if (date == null) return const SizedBox.shrink();

              final selected = _isSameDay(date, selectedDate);
              final isToday = _isSameDay(date, today);
              final dots = <Color>{
                for (final entry in eventDates)
                  if (_isSameDay(entry.$1, date)) entry.$2,
              }.take(3).toList();
              final hasEvent = dots.isNotEmpty;

              return Semantics(
                button: true,
                selected: selected,
                label:
                    '${MaterialLocalizations.of(context).formatFullDate(date)}${hasEvent ? ', has scheduled activity' : ''}',
                child: InkWell(
                  onTap: () => onSelected(date),
                  customBorder: const CircleBorder(),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primaryRed
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday && !selected
                              ? Border.all(
                                  color: AppColors.primaryRed,
                                  width: 1.5,
                                )
                              : null,
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryRed.withValues(
                                      alpha: .3,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: selected || isToday
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : isToday
                                ? AppColors.primaryRed
                                : AppColors.darkGray,
                          ),
                        ),
                      ),
                      if (hasEvent)
                        Positioned(
                          bottom: selected ? 9 : 2,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final color in dots)
                                Container(
                                  width: 5,
                                  height: 5,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected ? Colors.white : color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Divider(height: 20),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 6,
            children: [
              _LegendDot(color: AppColors.primaryRed, label: 'Meetings'),
              _LegendDot(color: AppColors.info, label: 'Programs'),
              _LegendDot(color: AppColors.highlight, label: 'Deadlines'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _MonthButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: AppColors.field,
      foregroundColor: AppColors.darkGray,
    ),
    icon: Icon(icon),
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        TextSpan(text: label),
      ],
    ),
    style: const TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: AppColors.lightText,
    ),
  );
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
            fontSize: 12.5,
            color: AppColors.lightText,
            fontWeight: FontWeight.w800,
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
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final isToday = _isSameDay(date, DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeading(
          icon: Icons.event_note_outlined,
          title:
              '${weekdays[date.weekday - 1]}, ${_monthName(date.month)} ${date.day}'
              '${isToday ? ' (Today)' : ''}',
          action: AppStatusBadge(
            label:
                '${events.length} ${events.length == 1 ? 'event' : 'events'}',
            color: AppColors.primaryRed,
          ),
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          const AppSurface(
            child: AppEmptyState(
              icon: Icons.event_available_outlined,
              title: 'No events on this day',
              message: 'Select another date to see its schedule.',
              color: AppColors.info,
            ),
          )
        else
          ...events.map((event) => _EventTile(event: event)),
      ],
    );
  }
}

class _AllEventsCard extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const _AllEventsCard({required this.events});

  @override
  Widget build(BuildContext context) {
    final visible = events.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeading(
          title: 'All Upcoming Events',
          action: AppStatusBadge(
            label: '${visible.length} shown',
            color: AppColors.info,
          ),
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
    final type = _eventTypeLabel(
      event['event_type']?.toString() ??
          (event.containsKey('meeting_id') ? 'meeting' : 'other'),
    );
    final color = _eventColor(event);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppAccentCard(
        accent: color,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            AppDateBlock(date: date, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppStatusBadge(label: type.toUpperCase(), color: color),
                  const SizedBox(height: 7),
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  if (date != null) ...[
                    const SizedBox(height: 4),
                    AppMeta(
                      icon: Icons.calendar_today_outlined,
                      label:
                          '${_monthName(date.month).substring(0, 3)} ${date.day}, ${date.year}',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
      borderRadius: BorderRadius.circular(AppSpace.controlRadius),
      child: InputDecorator(
        decoration: _inputDecoration(label, label: true).copyWith(
          suffixIcon: const Icon(
            Icons.calendar_month_outlined,
            color: AppColors.primaryRed,
          ),
        ),
        child: Text(
          _dateText(date),
          style: const TextStyle(
            color: AppColors.darkGray,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String text, {bool label = false}) {
  return InputDecoration(
    hintText: label ? null : text,
    labelText: label ? text : null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
  );
}

Color _eventColor(Map<String, dynamic> event) {
  switch (event['event_type']?.toString()) {
    case 'meeting':
      return AppColors.primaryRed;
    case 'program':
      return AppColors.info;
    case 'deadline':
    case 'report_slot':
    case 'budget_slot':
      return AppColors.highlight;
    default:
      return event.containsKey('meeting_id')
          ? AppColors.primaryRed
          : AppColors.muted;
  }
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
