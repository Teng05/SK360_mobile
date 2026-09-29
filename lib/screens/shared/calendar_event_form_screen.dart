import 'package:flutter/material.dart';
import '../../services/mobile_api_service.dart';

class CalendarEventFormScreen extends StatefulWidget {
  const CalendarEventFormScreen({super.key, required this.initialDate, this.event});
  final DateTime initialDate;
  final Map<String, dynamic>? event;
  @override
  State<CalendarEventFormScreen> createState() => _CalendarEventFormScreenState();
}

class _CalendarEventFormScreenState extends State<CalendarEventFormScreen> {
  final title = TextEditingController();
  final description = TextEditingController();
  final location = TextEditingController();
  late DateTime start = DateTime.tryParse(widget.event?['start_datetime']?.toString() ?? '') ?? widget.initialDate;
  late DateTime end = DateTime.tryParse(widget.event?['end_datetime']?.toString() ?? '') ?? widget.initialDate.add(const Duration(hours: 1));
  String type = 'event';
  String visibility = 'public';
  bool saving = false;
  @override void didChangeDependencies() { super.didChangeDependencies(); if (title.text.isEmpty) { title.text = widget.event?['title']?.toString() ?? ''; description.text = widget.event?['description']?.toString() ?? ''; location.text = widget.event?['location']?.toString() ?? ''; type = widget.event?['event_type']?.toString() ?? 'event'; visibility = widget.event?['visibility']?.toString() ?? 'public'; } }
  @override void dispose() { title.dispose(); description.dispose(); location.dispose(); super.dispose(); }
  Future<void> _pick(bool isStart) async {
    final value = await showDatePicker(context: context, initialDate: isStart ? start : end, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (value == null) return;
    setState(() { if (isStart) { start = DateTime(value.year, value.month, value.day, start.hour); if (end.isBefore(start)) end = start.add(const Duration(hours: 1)); } else { end = DateTime(value.year, value.month, value.day, end.hour); } });
  }
  Future<void> _save() async {
    if (title.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an event title.'))); return; }
    setState(() => saving = true);
    try { final id = int.tryParse('${widget.event?['event_id'] ?? ''}'); if (id == null) { await MobileApiService.createEvent(title: title.text.trim(), description: description.text.trim(), location: location.text.trim().isEmpty ? null : location.text.trim(), startDateTime: start, endDateTime: end, eventType: type, visibility: visibility); } else { await MobileApiService.updateEvent(eventId: id, title: title.text.trim(), description: description.text.trim(), location: location.text.trim().isEmpty ? null : location.text.trim(), startDateTime: start, endDateTime: end, eventType: type, visibility: visibility); } if (mounted) Navigator.pop(context, true); }
    on MobileApiException catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))); }
    finally { if (mounted) setState(() => saving = false); }
  }
  Future<void> _delete() async {
    final id = int.tryParse('${widget.event?['event_id'] ?? ''}');
    if (id == null) return;
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Delete event?'), content: const Text('This event will be permanently deleted.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))]));
    if (ok != true) return;
    setState(() => saving = true);
    try { await MobileApiService.deleteEvent(id); if (mounted) Navigator.pop(context, true); } on MobileApiException catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))); } finally { if (mounted) setState(() => saving = false); }
  }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.event == null ? 'Create Event' : 'Edit Event'), actions: [if (widget.event != null) IconButton(onPressed: saving ? null : _delete, icon: const Icon(Icons.delete_outline), tooltip: 'Delete event')]), body: ListView(padding: const EdgeInsets.all(20), children: [Text(widget.event == null ? 'Schedule an event' : 'Edit event', style: Theme.of(context).textTheme.headlineSmall), const SizedBox(height: 20), TextField(controller: title, decoration: const InputDecoration(labelText: 'Event title')), const SizedBox(height: 14), DropdownButtonFormField(initialValue: type, decoration: const InputDecoration(labelText: 'Event type'), items: const [DropdownMenuItem(value: 'event', child: Text('Event')), DropdownMenuItem(value: 'meeting', child: Text('Meeting')), DropdownMenuItem(value: 'deadline', child: Text('Deadline')), DropdownMenuItem(value: 'program', child: Text('Program'))], onChanged: (v) => setState(() => type = v ?? 'event')), const SizedBox(height: 14), DropdownButtonFormField(initialValue: visibility, decoration: const InputDecoration(labelText: 'Audience'), items: const [DropdownMenuItem(value: 'public', child: Text('All users / Public')), DropdownMenuItem(value: 'officials_only', child: Text('Officials only'))], onChanged: (v) => setState(() => visibility = v ?? 'public')), const SizedBox(height: 14), TextField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'Description')), const SizedBox(height: 14), TextField(controller: location, decoration: const InputDecoration(labelText: 'Location (optional)', hintText: 'Venue, room, or meeting location')), const SizedBox(height: 14), Row(children: [Expanded(child: OutlinedButton(onPressed: () => _pick(true), child: Text('Start: ${start.year}-${start.month}-${start.day}'))), const SizedBox(width: 10), Expanded(child: OutlinedButton(onPressed: () => _pick(false), child: Text('End: ${end.year}-${end.month}-${end.day}')))]), const SizedBox(height: 28), FilledButton(onPressed: saving ? null : _save, child: Text(saving ? 'Saving...' : widget.event == null ? 'Save Event' : 'Save Changes'))]));
}

