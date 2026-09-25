import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

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
  String? _loadError;
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
            physics: const AlwaysScrollableScrollPhysics(),
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
                eyebrow: 'Barangay leaderboard',
                eyebrowIcon: Icons.emoji_events_outlined,
                title: 'Rankings',
                subtitle:
                    'Top performing councils based on timely submissions, '
                    'completeness, and participation.',
              ),
              const SizedBox(height: 20),
              if (rankings.isEmpty && !_isLoading && _loadError == null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _EmptyRankingState(),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _RankingHistoryDropdown(
                    history: history,
                    selectedPeriod: selectedPeriod,
                    onChanged: (value) {
                      setState(() => _selectedHistoryPeriod = value);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _TopThreeSection(rankings: topThree),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _LeaderboardPanel(rankings: rankings),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _PointsSystemPanel(),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
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
        : rows.where((row) {
            final rowPeriod = _text(row['reporting_period']);
            // Keep barangays with no ranking yet so they remain searchable.
            return rowPeriod.isEmpty || rowPeriod == period;
          });

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
        const AppSectionHeading(
          icon: Icons.military_tech_outlined,
          title: 'Top barangays',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final podium =
                rankings.length == 3 &&
                constraints.maxWidth >= 300 &&
                MediaQuery.textScalerOf(context).scale(14) <= 19;
            if (!podium) {
              return Column(
                children: [
                  for (var i = 0; i < rankings.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TopRankCard(item: rankings[i], place: i + 1),
                    ),
                ],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final index in [1, 0, 2])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          4,
                          index == 0 ? 0 : 26,
                          4,
                          0,
                        ),
                        child: _PodiumCard(item: rankings[index]),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (rankings.isEmpty)
          const Text(
            'No results for this period.',
            style: TextStyle(color: AppColors.lightText),
          ),
      ],
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final _RankingItem item;
  const _PodiumCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final first = item.rank == 1;
    final accent = _medalColor(item.rank);
    return Semantics(
      sortKey: OrdinalSortKey(item.rank.toDouble()),
      child: Container(
        padding: EdgeInsets.fromLTRB(8, first ? 22 : 16, 8, 18),
        decoration:
            AppDecorations.surface(
              color: first ? AppColors.highlightSurface : AppColors.surface,
            ).copyWith(
              border: Border.all(
                color: first ? AppColors.gold : AppColors.border,
                width: first ? 1.5 : 1,
              ),
            ),
        child: Column(
          children: [
            AppIconTile(
              icon: first
                  ? Icons.emoji_events_rounded
                  : Icons.workspace_premium_rounded,
              color: accent,
              size: first ? 30 : 24,
              circle: true,
            ),
            const SizedBox(height: 10),
            AppStatusBadge(label: '#${item.rank}', color: accent),
            const SizedBox(height: 12),
            Text(
              item.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            const SizedBox(height: 12),
            Text(
              '${item.points}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: first ? AppColors.actionRed : AppColors.darkGray,
              ),
            ),
            Text('Points', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Gold, silver and bronze accents for the top three places.
Color _medalColor(int rank) => switch (rank) {
  1 => AppColors.gold,
  2 => AppColors.muted,
  3 => AppColors.warning,
  _ => AppColors.primaryRed,
};

class _TopRankCard extends StatelessWidget {
  final _RankingItem? item;
  final int place;

  const _TopRankCard({required this.item, required this.place});

  @override
  Widget build(BuildContext context) {
    if (item == null) return const SizedBox.shrink();
    return AppSurface(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _medalColor(place).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '#${item!.rank}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color.lerp(_medalColor(place), AppColors.darkGray, .2),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item!.name,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${item!.points} pts',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryRed,
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
          AppSectionHeading(
            icon: Icons.leaderboard_outlined,
            title: 'Live Leaderboard',
            action: AppStatusBadge(
              label:
                  '${widget.rankings.length} '
                  '${widget.rankings.length == 1 ? 'barangay' : 'barangays'}',
              color: AppColors.info,
            ),
          ),
          const SizedBox(height: 12),
          AppSearchField(
            controller: _searchController,
            hintText: 'Search barangay...',
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          const SizedBox(height: 12),
          SizedBox(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No barangay found.',
                      style: TextStyle(color: AppColors.lightText),
                    ),
                  )
                : ListView.separated(
                    primary: false,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, index) =>
                        _RankingRow(item: filtered[index]),
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
    final medal = item.rank <= 3;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.inset(radius: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: medal
                  ? _medalColor(item.rank).withValues(alpha: .14)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: medal
                    ? _medalColor(item.rank).withValues(alpha: .3)
                    : AppColors.border,
              ),
            ),
            child: Text(
              '${item.rank}',
              style: TextStyle(
                color: medal
                    ? Color.lerp(_medalColor(item.rank), AppColors.darkGray, .2)
                    : AppColors.darkGray,
                fontSize: 16,
                fontWeight: FontWeight.w800,
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
                _MetricBar(
                  label: 'On-time',
                  value: item.onTime,
                  color: AppColors.primaryRed,
                ),
                const SizedBox(height: 6),
                _MetricBar(
                  label: 'Complete',
                  value: item.completion,
                  color: AppColors.info,
                ),
                const SizedBox(height: 6),
                _MetricBar(
                  label: 'Engage',
                  value: item.engagement,
                  color: AppColors.success,
                ),
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
  final Color color;

  const _MetricBar({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0, 100) / 100;

    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.lightText,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: color.withValues(alpha: .12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            '$value%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, color: AppColors.lightText),
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
          const AppSectionHeading(
            icon: Icons.stars_outlined,
            title: 'Points System',
            subtitle: 'How points are earned and deducted',
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
                  ? AppColors.successSurface
                  : AppColors.softPink,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              rule.points,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: rule.positive ? AppColors.success : AppColors.primaryRed,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.highlightSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.gold.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.highlight),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
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
    return AppSurface(child: child);
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return AppSectionHeading(title: label);
  }
}

class _EmptyRankingState extends StatelessWidget {
  const _EmptyRankingState();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.emoji_events_outlined,
      title: 'Rankings are on their way',
      message:
          'Barangay results will appear when they are published. Pull down to refresh.',
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
            style: TextStyle(color: AppColors.lightText, fontSize: 13),
          ),
          const SizedBox(height: 10),
          if (history.isEmpty)
            const Text(
              'No past ranking periods yet.',
              style: TextStyle(color: AppColors.lightText),
            )
          else
            ...history.map((periodEntry) {
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
                          child: Text(
                            'No points recorded.',
                            style: TextStyle(color: AppColors.lightText),
                          ),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            title: Text(_text(row['barangay_name'])),
                            trailing: Text(
                              '${_number(row['total_points'])} pts',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
              );
            }),
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
          const AppSectionHeading(
            icon: Icons.history_rounded,
            title: 'Ranking History',
            subtitle: 'Select a month to view its top barangays.',
          ),
          const SizedBox(height: 14),
          if (periods.isEmpty)
            const Text(
              'No ranking periods yet.',
              style: TextStyle(color: AppColors.lightText),
            )
          else
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: periods.contains(selectedPeriod)
                  ? selectedPeriod
                  : null,

              decoration: const InputDecoration(
                labelText: 'Select month',
                prefixIcon: Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.primaryRed,
                ),
              ),
              items: [
                for (final period in periods)
                  DropdownMenuItem(value: period, child: Text(period)),
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
