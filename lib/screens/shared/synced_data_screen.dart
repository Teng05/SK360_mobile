import 'package:flutter/material.dart';

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
                leading: PresidentHeaderLeading.menu,
                onLeadingTap: () => _scaffoldKey.currentState?.openDrawer(),
                title: widget.title,
                subtitle: widget.subtitle,
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

    final rows = source.map((row) => Map<String, dynamic>.from(row as Map)).toList();

    if (widget.dataKey == 'wall_posts' || widget.dataKey == 'announcements') {
      rows.sort((a, b) {
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final dateOrder = (bDate ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(aDate ?? DateTime.fromMillisecondsSinceEpoch(0));
        if (dateOrder != 0) return dateOrder;

        final bId = int.tryParse(
              b['announcement_id']?.toString() ?? '',
            ) ??
            0;
        final aId = int.tryParse(
              a['announcement_id']?.toString() ?? '',
            ) ??
            0;
        return bId.compareTo(aId);
      });
    }

    return rows;
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
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _CreatePostPage()),
    );
    if (mounted) setState(() {});
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primaryRed),
    );
  }
}

class _CreatePostPage extends StatefulWidget {
  const _CreatePostPage();

  @override
  State<_CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<_CreatePostPage> {
  final TextEditingController _controller = TextEditingController();
  String _category = 'announcement';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something before posting.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await MobileApiService.createWallPost(
        content: content,
        category: _category,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on MobileApiException catch (exception) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(exception.message),
            backgroundColor: AppColors.primaryRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Create Post',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.darkGray,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Share an announcement or update with the SK community.',
            style: TextStyle(color: AppColors.lightText),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
              labelText: 'Post type',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
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
            onChanged: _isSubmitting
                ? null
                : (value) => setState(() => _category = value ?? 'announcement'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            enabled: !_isSubmitting,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Write the post content',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(_isSubmitting ? 'Posting...' : 'Post'),
          ),
        ],
      ),
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
