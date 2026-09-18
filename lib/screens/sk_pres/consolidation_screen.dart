import 'package:flutter/material.dart';

import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';

// President-only view of submitted reports and budget records by barangay.
class ConsolidationScreen extends StatefulWidget {
  const ConsolidationScreen({super.key});

  @override
  State<ConsolidationScreen> createState() => _ConsolidationScreenState();
}

class _ConsolidationScreenState extends State<ConsolidationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  String _period = 'all';
  String _quarter = 'Q${((DateTime.now().month - 1) ~/ 3) + 1}';
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _submissions = [];
  List<int> _years = [DateTime.now().year];

  @override
  void initState() {
    super.initState();
    _loadConsolidation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const PresidentSideDrawer(),
      backgroundColor: AppColors.lightGrayBg,
      bottomNavigationBar: PresidentBottomNavBar(
        activeItem: null,
        onItemSelected: _handleNavSelection,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadConsolidation,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              PresidentHeader(
                leading: PresidentHeaderLeading.menu,
                onLeadingTap: () => _scaffoldKey.currentState?.openDrawer(),
                title: 'Consolidation',
                subtitle: 'Barangay submissions',
              ),
              if (_isLoading) const LinearProgressIndicator(minHeight: 3),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _Filters(
                  year: _year,
                  years: _years,
                  period: _period,
                  month: _month,
                  quarter: _quarter,
                  onChanged: (year, period, month, quarter) {
                    setState(() {
                      _year = year;
                      _period = period;
                      _month = month;
                      _quarter = quarter;
                    });
                    _loadConsolidation();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: _Stat(label: 'Total', value: '${_stats['total_barangays'] ?? 0}')),
                    const SizedBox(width: 8),
                    Expanded(child: _Stat(label: 'Submitted', value: '${_stats['submitted'] ?? 0}', color: Colors.green)),
                    const SizedBox(width: 8),
                    Expanded(child: _Stat(label: 'Pending', value: '${_stats['pending'] ?? 0}', color: const Color(0xFFFFC107))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_submissions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No barangay records found.', style: TextStyle(color: AppColors.lightText)),
                  ),
                )
              else
                ..._submissions.map(
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _BarangaySubmissionCard(row: row),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadConsolidation() async {
    setState(() => _isLoading = true);
    try {
      final response = await MobileApiService.consolidation(
        year: _year,
        period: _period,
        month: _month,
        quarter: _quarter,
      );
      final submissions = response['submissions'] as List<dynamic>? ?? [];
      final years = response['years'] as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        _stats = Map<String, dynamic>.from((response['stats'] as Map?) ?? {});
        _submissions = submissions.map((row) => Map<String, dynamic>.from(row as Map)).toList();
        _years = years.map((year) => int.tryParse('$year') ?? DateTime.now().year).toSet().toList()..sort((a, b) => b.compareTo(a));
      });
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primaryRed),
    );
  }

  void _handleNavSelection(PresidentNavItem item) {
    handleRoleNavSelection(context, item);
  }
}

class _Filters extends StatelessWidget {
  final int year;
  final List<int> years;
  final String period;
  final int month;
  final String quarter;
  final void Function(int year, String period, int month, String quarter) onChanged;

  const _Filters({
    required this.year,
    required this.years,
    required this.period,
    required this.month,
    required this.quarter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: year,
                  decoration: _filterDecoration('Year'),
                  items: years.map((value) => DropdownMenuItem(value: value, child: Text('$value'))).toList(),
                  onChanged: (value) => onChanged(value ?? year, period, month, quarter),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: period,
                  decoration: _filterDecoration('Period'),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'quarterly', child: Text('Quarterly')),
                    DropdownMenuItem(value: 'annual', child: Text('Annual')),
                  ],
                  onChanged: (value) => onChanged(year, value ?? period, month, quarter),
                ),
              ),
            ],
          ),
          if (period == 'monthly' || period == 'quarterly') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (period == 'monthly')
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: month,
                      decoration: _filterDecoration('Month'),
                      items: List.generate(12, (index) => DropdownMenuItem(value: index + 1, child: Text('${index + 1}'))),
                      onChanged: (value) => onChanged(year, period, value ?? month, quarter),
                    ),
                  ),
                if (period == 'quarterly')
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: quarter,
                      decoration: _filterDecoration('Quarter'),
                      items: const [
                        DropdownMenuItem(value: 'Q1', child: Text('Q1')),
                        DropdownMenuItem(value: 'Q2', child: Text('Q2')),
                        DropdownMenuItem(value: 'Q3', child: Text('Q3')),
                        DropdownMenuItem(value: 'Q4', child: Text('Q4')),
                      ],
                      onChanged: (value) => onChanged(year, period, month, value ?? quarter),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

InputDecoration _filterDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.softPink,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({required this.label, required this.value, this.color = AppColors.primaryRed});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(color: AppColors.lightText, fontSize: 12)),
        ],
      ),
    );
  }
}

class _BarangaySubmissionCard extends StatelessWidget {
  final Map<String, dynamic> row;

  const _BarangaySubmissionCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final submitted = row['status'] == 'submitted';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: submitted ? Colors.green : AppColors.borderPink),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row['barangay']?.toString() ?? 'Barangay',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkGray),
                ),
              ),
              Chip(
                label: Text(submitted ? 'Submitted' : 'Pending'),
                backgroundColor: submitted ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Line(label: 'Monthly', value: row['monthly']?.toString() ?? 'Pending'),
          _Line(label: 'Quarterly', value: row['quarterly']?.toString() ?? 'Pending'),
          _Line(label: 'Annual', value: row['annual']?.toString() ?? 'Pending'),
          const SizedBox(height: 8),
          Text('Last: ${row['last_submission']}', style: const TextStyle(color: AppColors.lightText, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;

  const _Line({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 76, child: Text(label, style: const TextStyle(color: AppColors.lightText, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
