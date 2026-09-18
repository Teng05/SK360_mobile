import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../routes.dart';
import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';

// Role-based home dashboard shared by President, Chairman, and Secretary.
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
  int _activeFeedTab = 0;

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
    return WillPopScope(
      onWillPop: _handleHomeBack,
      child: Scaffold(
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
            title: 'SK 360',
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
              controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 18),
            children: [
              if (_isLoading) const LinearProgressIndicator(minHeight: 3),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Engagement',
                        value: '${posts.length}',
                        caption: 'posts',
                        icon: Icons.trending_up,
                        color: AppColors.primaryRed,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Active Users',
                        value: '${_rows('barangays').length}',
                        caption: 'barangays',
                        icon: Icons.people_alt_outlined,
                        color: const Color(0xFF0F5BFF),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _UpcomingMeetingsCard(meetings: meetings),
              ),
              if (_user['role']?.toString() == 'sk_president')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _QuickActions(onOpen: _openRoute),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _SharedWallComposer(
                  isPosting: _isLoading,
                  onPost: _createWallPost,
                ),
              ),
              const SizedBox(height: 12),
              _FeedSection(
                activeTab: _activeFeedTab,
                posts: _filteredPosts(posts),
                onTabSelected: (index) =>
                    setState(() => _activeFeedTab = index),
                onLike: _toggleWallLike,
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
    final result = rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();

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
    setState(() => _isLoading = true);
    try {
      await MobileApiService.sync();
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createWallPost(String content, String category) async {
    setState(() => _isLoading = true);
    try {
      await MobileApiService.createWallPost(
        content: content,
        category: category,
      );
      if (mounted) _showMessage('Posted to shared wall.');
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primaryRed),
    );
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
    return Container(
      height: 92,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const Spacer(),
              Icon(
                Icons.bar_chart,
                color: Colors.white.withValues(alpha: 0.8),
                size: 16,
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  caption,
                  style: const TextStyle(
                    color: Color(0xFFFFC107),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingMeetingsCard extends StatelessWidget {
  final List<Map<String, dynamic>> meetings;

  const _UpcomingMeetingsCard({required this.meetings});

  @override
  Widget build(BuildContext context) {
    final visible = meetings.where(_isUpcomingMeeting).toList()
      ..sort(_compareMeetings);
    final upcoming = visible.take(2).toList();

    return _Panel(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month,
                color: AppColors.primaryRed,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Text(
                'Upcoming Meetings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.videoMeetings),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: Color(0xFF0F5BFF),
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (upcoming.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'No meetings yet',
                style: TextStyle(color: AppColors.lightText),
              ),
            )
          else
            ...upcoming.map((meeting) => _MeetingTile(row: meeting)),
        ],
      ),
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
    final date =
        row['meeting_date']?.toString() ??
        row['start_datetime']?.toString() ??
        '';
    final day = _day(date);
    final month = _month(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E9FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderPink),
            ),
            child: Column(
              children: [
                Text(
                  month,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.primaryRed,
                  ),
                ),
                Text(
                  day,
                  style: const TextStyle(
                    fontSize: 16,
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
                  date,
                  style: const TextStyle(
                    fontSize: 10,
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

class _QuickActions extends StatelessWidget {
  final ValueChanged<String> onOpen;

  const _QuickActions({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        AppRoutes.moduleManagement,
        'Create Submission',
        Icons.check_circle_outline,
        const Color(0xFFFFE8EA),
      ),
      (
        AppRoutes.videoMeetings,
        'Join Meeting',
        Icons.video_call,
        const Color(0xFFEAF2FF),
      ),
      (
        AppRoutes.rankings,
        'View Rankings',
        Icons.emoji_events_outlined,
        const Color(0xFFFFF7D8),
      ),
      (
        AppRoutes.announcements,
        'Announcements',
        Icons.campaign_outlined,
        const Color(0xFFF2F0FF),
      ),
    ];

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: actions
                .map(
                  (action) => InkWell(
                    onTap: () => onOpen(action.$1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: action.$4,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            action.$3,
                            color: AppColors.primaryRed,
                            size: 24,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            action.$2,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _SharedWallComposer extends StatefulWidget {
  final bool isPosting;
  final Future<void> Function(String content, String category) onPost;

  const _SharedWallComposer({required this.isPosting, required this.onPost});

  @override
  State<_SharedWallComposer> createState() => _SharedWallComposerState();
}

class _SharedWallComposerState extends State<_SharedWallComposer> {
  final TextEditingController _controller = TextEditingController();
  String _category = 'update';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.forum_outlined, color: AppColors.primaryRed, size: 18),
              SizedBox(width: 8),
              Text(
                'Shared Wall',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Share an update...',
              filled: true,
              fillColor: AppColors.softPink,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderPink),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.borderPink),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'update', child: Text('Update')),
                    DropdownMenuItem(
                      value: 'announcement',
                      child: Text('Announcement'),
                    ),
                    DropdownMenuItem(value: 'event', child: Text('Event')),
                    DropdownMenuItem(
                      value: 'accomplishment',
                      child: Text('Accomplishment'),
                    ),
                  ],
                  onChanged: widget.isPosting
                      ? null
                      : (value) {
                          setState(() => _category = value ?? 'update');
                        },
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: widget.isPosting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(92, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.send, size: 16),
                label: Text(widget.isPosting ? 'Posting' : 'Post'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    await widget.onPost(content, _category);
    if (mounted) _controller.clear();
  }
}

class _FeedSection extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTabSelected;
  final List<Map<String, dynamic>> posts;
  final ValueChanged<Map<String, dynamic>> onLike;

  const _FeedSection({
    required this.activeTab,
    required this.onTabSelected,
    required this.posts,
    required this.onLike,
  });

  static const tabs = ['All', 'Announcements', 'Accomplishments', 'Events'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Container(
            height: 38,
            color: const Color(0xFFF10612),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemBuilder: (context, index) {
                final active = index == activeTab;
                return GestureDetector(
                  onTap: () => onTabSelected(index),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    color: active
                        ? const Color(0xFFFFC107)
                        : Colors.transparent,
                    child: Text(
                      tabs[index],
                      style: TextStyle(
                        color: active ? AppColors.primaryRed : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(width: 4),
              itemCount: tabs.length,
            ),
          ),
          if (posts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No posts yet',
                style: TextStyle(color: AppColors.lightText),
              ),
            )
          else
            ...posts.map((post) => _PostCard(row: post, onLike: onLike)),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final ValueChanged<Map<String, dynamic>> onLike;

  const _PostCard({required this.row, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final title = row['author_name']?.toString() ?? 'SK 360 User';
    final tag = row['title']?.toString() ?? 'Update';
    final content = row['content']?.toString() ?? '';
    final date = row['created_at']?.toString() ?? '';
    final likes = row['likes_count']?.toString() ?? '0';
    final liked =
        row['liked_by_current_user'] == true ||
        row['liked_by_current_user'] == 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEDEDED))),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFFEAF2FF),
                child: Icon(Icons.person, size: 18, color: Color(0xFF6B8DCC)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.softPink,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              color: AppColors.primaryRed,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content,
                      style: const TextStyle(fontSize: 10, height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => onLike(row),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 2,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  liked
                                      ? Icons.thumb_up
                                      : Icons.thumb_up_outlined,
                                  size: 14,
                                  color: liked
                                      ? AppColors.primaryRed
                                      : AppColors.lightText,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  likes,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: liked
                                        ? AppColors.primaryRed
                                        : AppColors.lightText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 14,
                          color: AppColors.lightText,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '0',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.lightText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.share_outlined,
                          size: 14,
                          color: AppColors.lightText,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
      padding: const EdgeInsets.all(12),
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

String _day(String value) {
  final date = DateTime.tryParse(value);
  return date == null ? '--' : date.day.toString().padLeft(2, '0');
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
