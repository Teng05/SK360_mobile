import 'package:flutter/material.dart';

import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';
import '../../widgets/community_post.dart';
import 'create_post_screen.dart';

class SyncedDataScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String dataKey;
  final IconData icon;
  final bool allowCreatePost;

  const SyncedDataScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.dataKey,
    required this.icon,
    this.allowCreatePost = false,
  });

  @override
  State<SyncedDataScreen> createState() => _SyncedDataScreenState();
}

class _SyncedDataScreenState extends State<SyncedDataScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = false;
  String? _loadError;
  int _page = 1;
  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    final pageCount = rows.isEmpty ? 1 : (rows.length / _pageSize).ceil();
    final page = _page.clamp(1, pageCount);
    final visibleRows = rows.skip((page - 1) * _pageSize).take(_pageSize).toList();

    return Scaffold(
      key: _scaffoldKey,
      drawer: const PresidentSideDrawer(),
      backgroundColor: AppColors.lightGrayBg,
      bottomNavigationBar: PresidentBottomNavBar(
        activeItem: _activeNav,
        onItemSelected: _handleNavSelection,
      ),
      floatingActionButton: widget.allowCreatePost && _canCreatePost
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              onPressed: _showCreatePostDialog,
              icon: const Icon(Icons.add),
              label: const Text('New post'),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              PresidentHeader(
                leading: PresidentHeaderLeading.menu,
                onLeadingTap: () => _scaffoldKey.currentState?.openDrawer(),
                title: widget.title,
                subtitle: widget.subtitle,
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
                eyebrow: widget.dataKey == 'wall_posts'
                    ? 'Live feed'
                    : widget.subtitle,
                eyebrowIcon: widget.icon,
                title: widget.title,
                subtitle:
                    'Official advisories, council updates, and public notices.',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                child: _HeaderCard(
                  title: widget.dataKey == 'wall_posts'
                      ? 'Latest updates'
                      : widget.title,
                  subtitle:
                      '${rows.length} published update${rows.length == 1 ? '' : 's'}',
                  icon: widget.icon,
                ),
              ),
              const SizedBox(height: 14),
              if (rows.isEmpty && !_isLoading && _loadError == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _EmptyState(
                    icon: widget.icon,
                    title: 'No ${widget.title.toLowerCase()} yet',
                    message:
                        'Published updates will appear here. Pull down to refresh.',
                  ),
                )
              else
                ...visibleRows.map(
                  (row) => Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: {'wall_posts', 'announcements'}.contains(widget.dataKey) ? 0 : 16,
                      vertical: {'wall_posts', 'announcements'}.contains(widget.dataKey) ? 0 : 6,
                    ),
                    child: {'wall_posts', 'announcements'}.contains(widget.dataKey)
                        ? CommunityPostCard(
                            post: row,
                            onLike: row['visibility'] == 'public'
                                ? () => _likePost(row)
                                : null,
                            onCommentChanged: _refresh,
                            onEdit: _canManageAnnouncement(row)
                                ? () => _editAnnouncement(row)
                                : null,
                            onDelete: _canManageAnnouncement(row)
                                ? () => _deleteAnnouncement(row)
                                : null,
                          )
                        : _DataCard(row: row),
                  ),
                ),
              if (rows.length > _pageSize)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(onPressed: page > 1 ? () => setState(() => _page = page - 1) : null, icon: const Icon(Icons.chevron_left)),
                    Text('Page $page of $pageCount'),
                    IconButton(onPressed: page < pageCount ? () => setState(() => _page = page + 1) : null, icon: const Icon(Icons.chevron_right)),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  PresidentNavItem? get _activeNav {
    if (widget.dataKey == 'events' || widget.dataKey == 'meetings') {
      return PresidentNavItem.calendar;
    }

    if (widget.dataKey == 'messages') {
      return PresidentNavItem.chat;
    }

    if (widget.dataKey == 'wall_posts') {
      return null;
    }

    return null;
  }

  bool get _canCreatePost =>
      MobileApiService.currentUser?['role']?.toString() == 'sk_president';

  List<Map<String, dynamic>> _rows() {
    if (widget.dataKey == 'messages') {
      return [];
    }

    final source =
        MobileApiService.syncedData?[widget.dataKey] as List<dynamic>? ?? [];

    final rows = source
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    if (widget.dataKey == 'wall_posts' || widget.dataKey == 'announcements') {
      final wallPosts = MobileApiService.syncedData?['wall_posts'] as List? ?? [];
      final announcements = MobileApiService.syncedData?['announcements'] as List? ?? [];
      // wall_posts contains the live like/comment counters. Overlay it on
      // the announcement rows instead of keeping the older counter-less row.
      final merged = <String, Map<String, dynamic>>{};
      for (final item in [...announcements, ...wallPosts].whereType<Map>()) {
        final announcement = Map<String, dynamic>.from(item);
        merged['${announcement['announcement_id']}'] = announcement;
      }
      rows
        ..clear()
        ..addAll(merged.values);
    }

    if (widget.dataKey == 'wall_posts' || widget.dataKey == 'announcements') {
      if (widget.dataKey == 'announcements') {
        rows.removeWhere((row) {
          final category = '${row['post_category'] ?? row['category'] ?? row['title'] ?? ''}'.toLowerCase().trim();
          return !{'announcement', 'announcements'}.contains(category);
        });
      }
      rows.sort((a, b) {
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final dateOrder = (bDate ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(aDate ?? DateTime.fromMillisecondsSinceEpoch(0));
        if (dateOrder != 0) return dateOrder;

        final bId = int.tryParse(b['announcement_id']?.toString() ?? '') ?? 0;
        final aId = int.tryParse(a['announcement_id']?.toString() ?? '') ?? 0;
        return bId.compareTo(aId);
      });
    }

    return rows;
  }

  Future<void> _refresh() async {
    _page = 1;
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
    if (item == _activeNav) return;
    handleRoleNavSelection(context, item);
  }

  Future<void> _showCreatePostDialog() async {
    final posted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreatePostScreen(initialCategory: 'announcement'),
      ),
    );
    if (mounted) {
      setState(() {});
      if (posted == true) _showMessage('Your post has been published.');
    }
  }

  bool _canManageAnnouncement(Map<String, dynamic> row) {
    if (!{'wall_posts', 'announcements'}.contains(widget.dataKey) || !_canCreatePost) return false;
    final category = '${row['post_category'] ?? row['category'] ?? row['title'] ?? ''}'.trim().toLowerCase();
    return category == 'announcement' || category == 'announcements';
  }

  Future<void> _editAnnouncement(Map<String, dynamic> row) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreatePostScreen(announcement: row)),
    );
    if (saved == true && mounted) {
      setState(() {});
      _showMessage('Announcement updated.');
    }
  }

  Future<void> _likePost(Map<String, dynamic> row) async {
    final id = int.tryParse('${row['announcement_id']}');
    if (id == null) return;
    try {
      final response = await MobileApiService.toggleWallLike(id);
      final liked = response['liked'] == true || response['liked'] == 1;
      final currentLikes = int.tryParse('${row['likes_count'] ?? 0}') ?? 0;
      row['liked_by_current_user'] = liked;
      row['likes_count'] = response['likes_count'] ??
          (liked ? currentLikes + 1 : (currentLikes > 0 ? currentLikes - 1 : 0));
      if (response['feedback_count'] != null) {
        row['feedback_count'] = response['feedback_count'];
      }
      if (mounted) setState(() {});
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    }
  }

  Future<void> _deleteAnnouncement(Map<String, dynamic> row) async {
    final id = int.tryParse('${row['announcement_id']}');
    if (id == null) return;
    try {
      await MobileApiService.deleteWallPost(id);
      if (mounted) {
        setState(() {});
        _showMessage('Post deleted.');
      }
    } on MobileApiException catch (exception) {
      if (mounted) _showMessage(exception.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AppSectionHeading(
      title: title,
      icon: Icons.bolt_rounded,
      action: AppStatusBadge(label: subtitle, color: AppColors.info, dot: true),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(icon: icon, title: title, message: message);
  }
}

class _DataCard extends StatelessWidget {
  final Map<String, dynamic> row;

  const _DataCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final title = _firstValue([
      'title',
      'report_title',
      'full_name',
      'barangay_name',
      'type',
      'message',
      'status',
    ]);
    final subtitle = _firstValue([
      'content',
      'description',
      'agenda',
      'position',
      'reporting_period',
      'submitted_at',
      'created_at',
      'start_datetime',
    ]);

    return AppAccentCard(
      accent: AppColors.primaryRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? 'Council update' : title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  String _firstValue(List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return '';
  }
}
