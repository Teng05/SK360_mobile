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

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();

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
                ...rows.map(
                  (row) => Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.dataKey == 'wall_posts' ? 0 : 16,
                      vertical: widget.dataKey == 'wall_posts' ? 0 : 6,
                    ),
                    child: widget.dataKey == 'wall_posts'
                        ? CommunityPostCard(
                            post: row,
                            onLike: () => _likePost(row),
                          )
                        : _DataCard(row: row),
                  ),
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

  Future<void> _likePost(Map<String, dynamic> row) async {
    final id = int.tryParse('${row['announcement_id']}');
    if (id == null) return;
    try {
      await MobileApiService.toggleWallLike(id);
      if (mounted) setState(() {});
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
