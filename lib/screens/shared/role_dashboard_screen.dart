import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../routes.dart';
import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';
import '../../widgets/community_post.dart';
import '../../widgets/community_avatar.dart';
import 'create_post_screen.dart';

class MobileDashboardScreen extends StatefulWidget {
  const MobileDashboardScreen({super.key});

  @override
  State<MobileDashboardScreen> createState() => _MobileDashboardScreenState();
}

class _MobileDashboardScreenState extends State<MobileDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  Timer? _exitTimer;
  bool _canExit = false;
  bool _isLoading = false;
  String? _loadError;
  int _activeFeedTab = 0;
  bool _communityOnly = false;

  Map<String, dynamic> get _data => MobileApiService.syncedData ?? {};
  Map<String, dynamic> get _user => MobileApiService.currentUser ?? {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _exitTimer?.cancel();
    super.dispose();
  }

  Future<bool> _handleHomeBack() async {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return false;
    }

    if (!_canExit) {
      setState(() => _canExit = true);
      _exitTimer?.cancel();
      _exitTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _canExit = false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Press back again to exit.')),
      );
      return false;
    }

    await SystemNavigator.pop();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final barangay = _user['barangay_name']?.toString() ?? 'Barangay';
    final posts = _rows('wall_posts');
    final meetings = _rows('meetings');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleHomeBack();
      },
      child: Scaffold(
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
              title: 'SK 360°',
              subtitle: barangay,
            ),
          ),
        ),
        bottomNavigationBar: PresidentBottomNavBar(
          activeItem: PresidentNavItem.home,
          onItemSelected: _handleNavSelection,
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 18),
              children: [
                if (_isLoading) const AppLoadingIndicator(),
                if (_loadError != null)
                  AppEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Unable to refresh',
                    message: _loadError!,
                    onAction: _refresh,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Overview'),
                        icon: Icon(Icons.dashboard_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Community'),
                        icon: Icon(Icons.people_outline),
                      ),
                    ],
                    selected: {_communityOnly},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        setState(() => _communityOnly = selection.first),
                  ),
                ),
                if (!_communityOnly) ...[
                  AppPageIntro(
                    eyebrow: '${_roleLabel(_user['role'])} · $barangay',
                    title: 'Hello, ${_user['first_name'] ?? 'SK official'}',
                    subtitle: 'Stay on top of your council’s work.',
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: AppMetricGrid(
                      children: [
                        _StatCard(
                          title: 'Community posts',
                          value: '${posts.length}',
                          caption: 'Shared updates',
                          icon: Icons.forum_outlined,
                          color: AppColors.primaryRed,
                        ),
                        _StatCard(
                          title: 'Barangays',
                          value: '${_rows('barangays').length}',
                          caption: 'Connected councils',
                          icon: Icons.location_city_outlined,
                          color: AppColors.info,
                        ),
                        _StatCard(
                          title: 'Upcoming meetings',
                          value: '${meetings.where(_isUpcomingMeeting).length}',
                          caption: 'On the schedule',
                          icon: Icons.event_available_outlined,
                          color: AppColors.highlight,
                        ),
                        _StatCard(
                          title: 'Open slots',
                          value:
                              '${_rows('submission_slots').where((slot) => slot['status']?.toString() == 'open').length}',
                          caption: 'Submission windows',
                          icon: Icons.inventory_2_outlined,
                          color: AppColors.success,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: _UpcomingMeetingsCard(meetings: meetings),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: _QuickActions(onOpen: _openRoute),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: _SharedWallComposer(onOpen: _openComposer),
                ),
                const SizedBox(height: 8),
                _FeedSection(
                  activeTab: _activeFeedTab,
                  posts: _filteredPosts(posts),
                  onTabSelected: (index) =>
                      setState(() => _activeFeedTab = index),
                  onLike: _toggleWallLike,
                  onRefresh: _refresh,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _rows(String key) {
    final rows = _data[key] as List<dynamic>? ?? [];
    final result = rows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    if (key == 'wall_posts') {
      result.sort(_compareNewestPosts);
    }

    return result;
  }

  int _compareNewestPosts(Map<String, dynamic> a, Map<String, dynamic> b) {
    final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
    final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
    final dateOrder = (bDate ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(aDate ?? DateTime.fromMillisecondsSinceEpoch(0));

    if (dateOrder != 0) return dateOrder;

    final bId = int.tryParse(b['announcement_id']?.toString() ?? '') ?? 0;
    final aId = int.tryParse(a['announcement_id']?.toString() ?? '') ?? 0;
    return bId.compareTo(aId);
  }

  List<Map<String, dynamic>> _filteredPosts(List<Map<String, dynamic>> posts) {
    if (_activeFeedTab == 0) return posts;

    final needle = [
      'announcement',
      'accomplishment',
      'event',
    ][_activeFeedTab - 1];
    return posts.where((post) {
      final title = post['title']?.toString().toLowerCase() ?? '';
      return title.contains(needle);
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

  Future<void> _openComposer() async {
    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (mounted && posted == true) {
      setState(() {});
      _showMessage('Your post has been published.');
    }
  }

  Future<void> _toggleWallLike(Map<String, dynamic> post) async {
    final id = int.tryParse('${post['announcement_id'] ?? post['id'] ?? ''}');
    if (id == null) return;

    try {
      await MobileApiService.toggleWallLike(id);
      if (mounted) setState(() {});
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    }
  }

  void _handleNavSelection(PresidentNavItem item) {
    if (item == PresidentNavItem.home) return;
    handleRoleNavSelection(context, item);
  }

  void _openRoute(String route) {
    Navigator.pushNamed(context, route);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppStatistic(
      label: title,
      value: value,
      icon: icon,
      caption: caption,
      color: color,
    );
  }
}

String _roleLabel(Object? role) => switch (role?.toString()) {
  'sk_chairman' => 'SK Chairman',
  'sk_secretary' => 'SK Secretary',
  'sk_president' => 'SK Federation',
  _ => 'SK Official',
};

class _UpcomingMeetingsCard extends StatelessWidget {
  final List<Map<String, dynamic>> meetings;

  const _UpcomingMeetingsCard({required this.meetings});

  @override
  Widget build(BuildContext context) {
    final visible = meetings.where(_isUpcomingMeeting).toList()
      ..sort(_compareMeetings);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeading(
          title: 'Coming up',
          action: TextButton(
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.videoMeetings),
            child: const Text('View all'),
          ),
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          const AppSurface(
            child: Row(
              children: [
                AppIconTile(
                  icon: Icons.event_available_outlined,
                  color: AppColors.info,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No upcoming meetings. Check your calendar for activities and deadlines.',
                    style: TextStyle(color: AppColors.lightText),
                  ),
                ),
              ],
            ),
          )
        else
          ...visible.take(2).map((meeting) => _MeetingTile(row: meeting)),
      ],
    );
  }
}

bool _isUpcomingMeeting(Map<String, dynamic> meeting) {
  final status = meeting['status']?.toString().trim().toLowerCase();
  if (status == 'completed' ||
      status == 'done' ||
      status == 'cancelled' ||
      status == 'canceled') {
    return false;
  }

  final scheduledAt = _meetingDateTime(meeting);
  return scheduledAt != null &&
      !scheduledAt.add(const Duration(hours: 1)).isBefore(DateTime.now());
}

int _compareMeetings(Map<String, dynamic> a, Map<String, dynamic> b) {
  final aDate = _meetingDateTime(a);
  final bDate = _meetingDateTime(b);
  if (aDate == null && bDate == null) return 0;
  if (aDate == null) return 1;
  if (bDate == null) return -1;
  return aDate.compareTo(bDate);
}

DateTime? _meetingDateTime(Map<String, dynamic> meeting) {
  final start = meeting['start_datetime']?.toString();
  if (start != null && start.isNotEmpty && start.contains('T')) {
    return DateTime.tryParse(start);
  }

  final dateText = meeting['meeting_date']?.toString() ?? start;
  if (dateText == null || dateText.isEmpty) return null;

  final date = DateTime.tryParse(dateText);
  if (date == null) return null;

  final timeText = meeting['meeting_time']?.toString();
  if (timeText != null && timeText.isNotEmpty) {
    final parts = timeText.split(':');
    final hour = int.tryParse(parts.first);
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : 0;
    if (hour != null && minute != null) {
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
  }

  // Date-only meetings remain upcoming for the entire scheduled day.
  return DateTime(date.year, date.month, date.day, 23, 59, 59);
}

class _MeetingTile extends StatelessWidget {
  final Map<String, dynamic> row;

  const _MeetingTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final title = row['title']?.toString() ?? 'Meeting';
    final scheduled = _meetingDateTime(row);
    final hasTime =
        row['meeting_time']?.toString().isNotEmpty == true ||
        (row['start_datetime']?.toString().contains('T') ?? false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppAccentCard(
        accent: AppColors.primaryRed,
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: [
            AppDateBlock(date: scheduled),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppStatusBadge(
                    label: 'Council meeting',
                    color: AppColors.info,
                    icon: Icons.videocam_outlined,
                  ),
                  const SizedBox(height: 6),
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  if (scheduled != null) ...[
                    const SizedBox(height: 4),
                    AppMeta(
                      icon: Icons.schedule_rounded,
                      label: _whenLabel(scheduled, hasTime),
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

String _whenLabel(DateTime date, bool hasTime) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final month = _month(date.toIso8601String());
  final day =
      '${days[date.weekday - 1]}, ${month[0]}${month.substring(1).toLowerCase()} '
      '${date.day}';
  if (!hasTime) return day;
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$day · $hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
}

class _QuickActions extends StatelessWidget {
  final ValueChanged<String> onOpen;

  const _QuickActions({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final official = MobileApiService.currentUser?['role'] != 'sk_president';
    // Each shortcut keeps its own tone on the icon and label; boxes stay white.
    final actions = [
      (
        official ? AppRoutes.reports : AppRoutes.moduleManagement,
        official ? 'Submit a report' : 'Submission slots',
        Icons.description_outlined,
        AppColors.primaryRed,
      ),
      if (official)
        (
          AppRoutes.budget,
          'Budget reports',
          Icons.account_balance_wallet_outlined,
          AppColors.success,
        ),
      (
        AppRoutes.videoMeetings,
        'Video meetings',
        Icons.videocam_outlined,
        AppColors.info,
      ),
      (
        AppRoutes.announcements,
        'Announcements',
        Icons.campaign_outlined,
        AppColors.warning,
      ),
      (
        AppRoutes.rankings,
        'Rankings',
        Icons.emoji_events_outlined,
        AppColors.highlight,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeading(
          title: 'Your workspace',
          action: AppStatusBadge(
            label: '${actions.length} shortcuts',
            color: AppColors.primaryRed,
          ),
        ),
        const SizedBox(height: 12),
        // Two per row; an odd last shortcut spans the full width.
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0;
            final stacked =
                (constraints.maxWidth - gap) / 2 < 150 ||
                MediaQuery.textScalerOf(context).scale(14) > 19;
            return Column(
              children: [
                for (var i = 0; i < actions.length; i += 2) ...[
                  if (i > 0) const SizedBox(height: gap),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, action)
                            in actions.skip(i).take(2).indexed) ...[
                          if (index > 0) const SizedBox(width: gap),
                          Expanded(
                            child: _ShortcutTile(
                              label: action.$2,
                              icon: action.$3,
                              color: action.$4,
                              stacked: stacked,
                              onTap: () => onOpen(action.$1),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A white shortcut box. The icon sits beside the label, or above it on
/// narrow screens and at large text sizes.
class _ShortcutTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool stacked;
  final VoidCallback onTap;

  const _ShortcutTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.stacked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: AppDecorations.surface(radius: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: stacked
                ? const EdgeInsets.fromLTRB(6, 14, 6, 12)
                : const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: stacked
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIconTile(icon: icon, color: color, size: 21),
                      const SizedBox(height: 10),
                      _ShortcutLabel(label, color: color, centered: true),
                    ],
                  )
                : Row(
                    children: [
                      AppIconTile(icon: icon, color: color, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: _ShortcutLabel(label, color: color)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Multi-word labels wrap; single long words shrink instead of splitting.
class _ShortcutLabel extends StatelessWidget {
  final String label;
  final Color color;
  final bool centered;
  const _ShortcutLabel(
    this.label, {
    required this.color,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 13,
      height: 1.3,
      fontWeight: FontWeight.w800,
      color: color,
    );
    if (label.contains(' ')) {
      return Text(
        label,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: style,
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: centered ? Alignment.center : AlignmentDirectional.centerStart,
      child: Text(label, maxLines: 1, style: style),
    );
  }
}

class _SharedWallComposer extends StatelessWidget {
  final VoidCallback onOpen;
  const _SharedWallComposer({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final user = MobileApiService.currentUser ?? {};
    final name = [
      user['first_name'],
      user['last_name'],
    ].where((p) => p != null).join(' ');
    return AppSurface(
      padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
      child: Row(
        children: [
          CommunityAvatar(
            name: name,
            photoUrl: user['profile_pic_url']?.toString(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(24),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Text(
                    'Share an update with your council…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.lightText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Create post',
            onPressed: onOpen,
            icon: const Icon(Icons.edit_square, color: AppColors.primaryRed),
          ),
        ],
      ),
    );
  }
}

class _FeedSection extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTabSelected;
  final List<Map<String, dynamic>> posts;
  final Future<void> Function(Map<String, dynamic>) onLike;
  final Future<void> Function() onRefresh;

  const _FeedSection({
    required this.activeTab,
    required this.onTabSelected,
    required this.posts,
    required this.onLike,
    required this.onRefresh,
  });

  static const tabs = ['All', 'Announcements', 'Accomplishments', 'Events'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: AppSectionHeading(
            title: 'Community updates',
            action: AppStatusBadge(
              label: '${posts.length} ${posts.length == 1 ? 'post' : 'posts'}',
              color: AppColors.info,
            ),
          ),
        ),
        AppFilterPills(
          labels: tabs,
          selectedIndex: activeTab,
          onSelected: onTabSelected,
        ),
        const SizedBox(height: 14),
        if (posts.isEmpty)
          const AppEmptyState(
            icon: Icons.forum_outlined,
            title: 'No updates here yet',
            message: 'Share a council update above or choose another category.',
          )
        else
          ...posts.map(
            (post) => CommunityPostCard(
              key: ValueKey(post['announcement_id']),
              post: post,
              onLike: () => onLike(post),
              onCommentChanged: onRefresh,
            ),
          ),
      ],
    );
  }
}

String _month(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return '---';
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return months[date.month - 1];
}
