import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/president_components.dart';

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

  @override
  void initState() {
    super.initState();
    if (MobileApiService.syncedData == null) {
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows();

    return Scaffold(
      key: _scaffoldKey,
      drawer: _isYouth ? null : const PresidentSideDrawer(),
      backgroundColor: AppColors.lightGrayBg,
      bottomNavigationBar: PresidentBottomNavBar(
        activeItem: _activeNav,
        onItemSelected: _handleNavSelection,
      ),
      floatingActionButton: widget.allowCreatePost && _canCreatePost
          ? FloatingActionButton(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              onPressed: _showCreatePostDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              PresidentHeader(
                leading: _isYouth
                    ? PresidentHeaderLeading.none
                    : PresidentHeaderLeading.menu,
                onLeadingTap: _isYouth
                    ? null
                    : () => _scaffoldKey.currentState?.openDrawer(),
                title: widget.title,
                subtitle: widget.subtitle,
                trailing: [
                  IconButton(
                    onPressed: _isLoading ? null : _refresh,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ],
              ),
              if (_isLoading) const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _HeaderCard(
                  title: widget.title,
                  subtitle:
                      '${rows.length} synced item${rows.length == 1 ? '' : 's'}',
                  icon: widget.icon,
                ),
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _EmptyState(
                    icon: widget.icon,
                    title: 'No ${widget.title.toLowerCase()} yet',
                    message:
                        'Pull to refresh after data is added in the web app.',
                  ),
                )
              else
                ...rows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    child: _DataCard(row: row),
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
      return _isYouth ? PresidentNavItem.announcements : null;
    }

    return null;
  }

  bool get _isYouth =>
      MobileApiService.currentUser?['role']?.toString() == 'youth';

  bool get _canCreatePost =>
      MobileApiService.currentUser?['role']?.toString() == 'sk_president';

  List<Map<String, dynamic>> _rows() {
    if (widget.dataKey == 'messages') {
      return [];
    }

    final source =
        MobileApiService.syncedData?[widget.dataKey] as List<dynamic>? ?? [];

    return source.map((row) => Map<String, dynamic>.from(row as Map)).toList();
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
    if (item == _activeNav) return;
    handleRoleNavSelection(context, item);
  }

  Future<void> _showCreatePostDialog() async {
    final controller = TextEditingController();
    String category = 'announcement';

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                items: const [
                  DropdownMenuItem(
                    value: 'announcement',
                    child: Text('Announcement'),
                  ),
                  DropdownMenuItem(value: 'event', child: Text('Event')),
                  DropdownMenuItem(
                    value: 'accomplishment',
                    child: Text('Accomplishment'),
                  ),
                  DropdownMenuItem(value: 'update', child: Text('Update')),
                ],
                onChanged: (value) {
                  setDialogState(() => category = value ?? 'announcement');
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Write the post content',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;

                Navigator.pop(context);
                await _createPost(text, category);
              },
              child: const Text('Post'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPost(String content, String category) async {
    setState(() => _isLoading = true);
    try {
      await MobileApiService.createWallPost(
        content: content,
        category: category,
      );
      if (mounted) _showMessage('Post created.');
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.softPink,
            child: Icon(icon, color: AppColors.primaryRed),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGray,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.lightText),
                ),
              ],
            ),
          ),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppColors.primaryRed),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.lightText),
          ),
        ],
      ),
    );
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderPink),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? 'Synced item' : title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.lightText),
            ),
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
