import 'package:flutter/material.dart';

import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  String? _selectedHistoryPeriod;

  Map<String, dynamic> get _data => MobileApiService.syncedData ?? {};
  bool get _isPresident =>
      MobileApiService.currentUser?['role']?.toString() == 'sk_president';
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final rankings = _rankings();
    final period = _latestPeriod(_rows('rankings'));
    final history = _history();
    final historyPeriods = history
        .map((entry) => _text(entry['period']))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    final selectedPeriod = historyPeriods.contains(_selectedHistoryPeriod)
        ? _selectedHistoryPeriod!
        : historyPeriods.isNotEmpty
            ? historyPeriods.first
            : period;
    final topThree = _historyRankings(history, selectedPeriod).take(3).toList();

    return Scaffold(
      key: _scaffoldKey,
      drawer: _isPresident ? const PresidentSideDrawer() : null,
      backgroundColor: AppColors.lightGrayBg,
      bottomNavigationBar: _isPresident
          ? PresidentBottomNavBar(
              activeItem: null,
              onItemSelected: _handleNavSelection,
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              PresidentHeader(
                leading: _isPresident
                    ? PresidentHeaderLeading.menu
                    : PresidentHeaderLeading.back,
                onLeadingTap: _isPresident
                    ? () => _scaffoldKey.currentState?.openDrawer()
                    : () => Navigator.maybePop(context),
                title: 'Rankings',
                subtitle: period.isEmpty ? 'Barangay leaderboard' : period,
              ),
              if (_isLoading) const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 18),
              if (rankings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _EmptyRankingState(),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _RankingHistoryDropdown(
                    history: history,
                    selectedPeriod: selectedPeriod,
                    onChanged: (value) {
                      setState(() => _selectedHistoryPeriod = value);
                    },
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _TopThreeSection(rankings: topThree),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _LeaderboardPanel(rankings: rankings),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _PointsSystemPanel(),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: _BadgesPanel(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    try {
      await MobileApiService.sync();
    } on MobileApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(exception.message),
            backgroundColor: AppColors.primaryRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_RankingItem> _rankings() {
    final rows = _rows('rankings');
    final barangayNames = <String, String>{};

    for (final barangay in _rows('barangays')) {
      final id = _text(barangay['id']);
      if (id.isEmpty) continue;
      barangayNames[id] = _text(barangay['barangay_name']);
    }

    final period = _latestPeriod(rows);
    final filtered = period.isEmpty
        ? rows
        : rows.where((row) => _text(row['reporting_period']) == period);

    final items = filtered.map((row) {
      final barangayId = _text(row['barangay_id']);
      return _RankingItem(
        name: _firstText([
          row['barangay_name'],
          row['name'],
          barangayNames[barangayId],
          barangayId.isEmpty ? null : 'Barangay $barangayId',
        ]),
        points: _number(row['total_points'] ?? row['points']),
        onTime: _number(row['timely_submission_points']),
        completion: _number(row['completeness_points']),
        engagement: _number(row['participation_points']),
      );
    }).toList();

    items.sort((a, b) => b.points.compareTo(a.points));

    return [
      for (var index = 0; index < items.length; index++)
        items[index].copyWith(rank: index + 1),
    ];
  }

  String _latestPeriod(List<Map<String, dynamic>> rows) {
    final withPeriod = rows
        .where((row) => _text(row['reporting_period']).isNotEmpty)
        .toList();
    if (withPeriod.isEmpty) return '';

    withPeriod.sort((a, b) {
      final bDate = DateTime.tryParse(_text(b['created_at']));
      final aDate = DateTime.tryParse(_text(a['created_at']));
      if (aDate != null && bDate != null) return bDate.compareTo(aDate);
      return _text(
        b['reporting_period'],
      ).compareTo(_text(a['reporting_period']));
    });

    return _text(withPeriod.first['reporting_period']);
  }

  List<Map<String, dynamic>> _history() {
    final history = _data['ranking_history'];
    if (history is! List) return const [];

    return history
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  List<_RankingItem> _historyRankings(
    List<Map<String, dynamic>> history,
    String period,
  ) {
    Map<String, dynamic>? entry;
    for (final item in history) {
      if (_text(item['period']) == period) {
        entry = item;
        break;
      }
    }

    final rows = (entry?['rankings'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((row) {
          final data = Map<String, dynamic>.from(row);
          return _RankingItem(
            rank: _number(data['rank']),
            name: _text(data['barangay_name']),
            points: _number(data['total_points']),
            onTime: _number(data['timely_submission_points']),
            completion: _number(data['completeness_points']),
            engagement: _number(data['participation_points']),
          );
        })
        .toList();
    return rows;
  }

  List<Map<String, dynamic>> _rows(String key) {
    final rows = _data[key] as List<dynamic>? ?? [];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  void _handleNavSelection(PresidentNavItem item) {
    if (item == PresidentNavItem.rankings) return;
    handleRoleNavSelection(context, item);
  }
}

class _TopThreeSection extends StatelessWidget {
  final List<_RankingItem> rankings;

  const _TopThreeSection({required this.rankings});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Top Barangays'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var index = 0; index < 3; index++) ...[
              Expanded(
                child: _TopRankCard(
                  item: index < rankings.length ? rankings[index] : null,
                  place: index + 1,
                ),
              ),
              if (index < 2) const SizedBox(width: 10),
            ],
          ],
        ),
      ],
    );
  }
}

class _TopRankCard extends StatelessWidget {
  final _RankingItem? item;
  final int place;

  const _TopRankCard({required this.item, required this.place});

  @override
  Widget build(BuildContext context) {
    final color = switch (place) {
      1 => AppColors.primaryRed,
      2 => const Color(0xFF374151),
      _ => const Color(0xFF6B7280),
    };

    return Container(
      height: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: item == null
          ? Center(
              child: Text(
                '#$place',
                style: const TextStyle(
                  color: AppColors.lightText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color,
                  child: Text(
                    '#${item!.rank}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  item!.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item!.points} pts',
                  style: const TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
    );
  }
}

class _LeaderboardPanel extends StatefulWidget {
  final List<_RankingItem> rankings;

  const _LeaderboardPanel({required this.rankings});

  @override
  State<_LeaderboardPanel> createState() => _LeaderboardPanelState();
}

class _LeaderboardPanelState extends State<_LeaderboardPanel> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.rankings
        .where((item) => item.name.toLowerCase().contains(_query.toLowerCase()))
        .take(10)
        .toList();

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Live Leaderboard'),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              hintText: 'Search barangay...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
              filled: true,
              fillColor: AppColors.lightGrayBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 520,
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No barangay found.',
                      style: TextStyle(color: AppColors.lightText),
                    ),
                  )
                : ListView.separated(
                    primary: false,
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => _RankingRow(item: filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final _RankingItem item;

  const _RankingRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.lightGrayBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECEFF3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryRed,
            child: Text(
              '#${item.rank}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.darkGray,
                        ),
                      ),
                    ),
                    Text(
                      '${item.points} pts',
                      style: const TextStyle(
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _MetricBar(label: 'On-time', value: item.onTime),
                const SizedBox(height: 6),
                _MetricBar(label: 'Complete', value: item.completion),
                const SizedBox(height: 6),
                _MetricBar(label: 'Engage', value: item.engagement),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  final String label;
  final int value;

  const _MetricBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0, 100) / 100;

    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation(AppColors.primaryRed),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 34,
          child: Text(
            '$value%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
        ),
      ],
    );
  }
}

class _PointsSystemPanel extends StatelessWidget {
  const _PointsSystemPanel();

  static const rules = [
    _PointRule('On-time Report Submission', '+50 points', true),
    _PointRule('Meeting Attendance', '+30 points', true),
    _PointRule('Community Engagement', '+25 points', true),
    _PointRule('Quality Documentation', '+20 points', true),
    _PointRule('Event Participation', '+15 points', true),
    _PointRule('Late Submission', '-25 points', false),
    _PointRule('Missed Meeting', '-30 points', false),
  ];

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Points System',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'How points are earned and deducted',
            style: TextStyle(color: AppColors.lightText, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ...rules.map((rule) => _PointRuleTile(rule: rule)),
        ],
      ),
    );
  }
}

class _PointRuleTile extends StatelessWidget {
  final _PointRule rule;

  const _PointRuleTile({required this.rule});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rule.label,
              style: const TextStyle(fontSize: 13, color: AppColors.darkGray),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: rule.positive
                  ? const Color(0xFFDFF8EA)
                  : const Color(0xFFFFE4EA),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              rule.points,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: rule.positive
                    ? const Color(0xFF009E4D)
                    : AppColors.primaryRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgesPanel extends StatelessWidget {
  const _BadgesPanel();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('Achievement Badges'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _Badge(icon: Icons.schedule, label: 'On-time Leader'),
              _Badge(icon: Icons.check_circle_outline, label: 'Complete'),
              _Badge(icon: Icons.groups_outlined, label: 'Engaged'),
              _Badge(icon: Icons.star_outline, label: 'Top Performer'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.softPink,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryRed),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.darkGray,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECEFF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 11,
        letterSpacing: 0.8,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _EmptyRankingState extends StatelessWidget {
  const _EmptyRankingState();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: const [
          Icon(
            Icons.emoji_events_outlined,
            size: 42,
            color: AppColors.lightText,
          ),
          SizedBox(height: 12),
          Text(
            'No rankings yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Pull to refresh after rankings are added in the web app.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.lightText),
          ),
        ],
      ),
    );
  }
}

class _RankingItem {
  final int rank;
  final String name;
  final int points;
  final int onTime;
  final int completion;
  final int engagement;

  const _RankingItem({
    this.rank = 0,
    required this.name,
    required this.points,
    required this.onTime,
    required this.completion,
    required this.engagement,
  });

  _RankingItem copyWith({int? rank}) {
    return _RankingItem(
      rank: rank ?? this.rank,
      name: name,
      points: points,
      onTime: onTime,
      completion: completion,
      engagement: engagement,
    );
  }
}

// Kept for compatibility with older cached routes; the dropdown below is the active UI.
// ignore: unused_element
class _RankingHistoryPanel extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const _RankingHistoryPanel({required this.history});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ranking History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Top 3 barangays per month',
            style: TextStyle(color: AppColors.lightText, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (history.isEmpty)
            const Text('No past ranking periods yet.', style: TextStyle(color: AppColors.lightText))
          else
            ...history.map(
              (periodEntry) {
                final rows = (periodEntry['rankings'] as List<dynamic>? ?? [])
                    .whereType<Map>()
                    .toList();
                return ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text(
                    _text(periodEntry['period']),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  children: rows.isEmpty
                      ? [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text('No points recorded.', style: TextStyle(color: AppColors.lightText)),
                          ),
                        ]
                      : [
                          for (final row in rows)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 15,
                                backgroundColor: AppColors.primaryRed,
                                child: Text(
                                  '#${_text(row['rank'])}',
                                  style: const TextStyle(color: Colors.white, fontSize: 11),
                                ),
                              ),
                              title: Text(_text(row['barangay_name'])),
                              trailing: Text(
                                '${_number(row['total_points'])} pts',
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RankingHistoryDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final String selectedPeriod;
  final ValueChanged<String?> onChanged;

  const _RankingHistoryDropdown({
    required this.history,
    required this.selectedPeriod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final periods = history
        .map((entry) => _text(entry['period']))
        .where((period) => period.isNotEmpty)
        .toSet()
        .toList();

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ranking History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select a month to view its top barangays.',
            style: TextStyle(color: AppColors.lightText, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (periods.isEmpty)
            const Text('No ranking periods yet.', style: TextStyle(color: AppColors.lightText))
          else
            DropdownButtonFormField<String>(
              initialValue: periods.contains(selectedPeriod) ? selectedPeriod : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Select month',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: [
                for (final period in periods)
                  DropdownMenuItem(
                    value: period,
                    child: Text(period),
                  ),
              ],
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _PointRule {
  final String label;
  final String points;
  final bool positive;

  const _PointRule(this.label, this.points, this.positive);
}

String _text(Object? value) => value?.toString().trim() ?? '';

String _firstText(List<Object?> values) {
  for (final value in values) {
    final text = _text(value);
    if (text.isNotEmpty) return text;
  }
  return 'Unknown Barangay';
}

int _number(Object? value) {
  if (value is num) return value.round();
  return double.tryParse(_text(value))?.round() ?? 0;
}
