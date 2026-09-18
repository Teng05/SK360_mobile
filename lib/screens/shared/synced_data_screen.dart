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
                    child: _DataCard(
                      row: row,
                      onTap: widget.dataKey == 'wall_posts'
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _AnnouncementDetailsPage(
                                    row: row,
                                    canEdit: _canCreatePost,
                                  ),
                                ),
                              )
                          : null,
                    ),
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
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _controller = TextEditingController();
  String _category = 'announcement';
  String _audience = 'public';
  String _status = 'published';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _controller.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content are required.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await MobileApiService.createWallPost(
        title: title,
        content: content,
        category: _category,
        audience: _audience,
        status: _status,
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
          TextField(
            controller: _titleController,
            enabled: !_isSubmitting,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
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
          DropdownButtonFormField<String>(
            initialValue: _audience,
            decoration: const InputDecoration(
              labelText: 'Audience',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            items: const [
              DropdownMenuItem(value: 'public', child: Text('Public')),
              DropdownMenuItem(
                value: 'officials_only',
                child: Text('Officials only'),
              ),
            ],
            onChanged: _isSubmitting
                ? null
                : (value) => setState(() => _audience = value ?? 'public'),
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
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: 'Save as',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            items: const [
              DropdownMenuItem(value: 'published', child: Text('Publish now')),
              DropdownMenuItem(value: 'draft', child: Text('Save draft')),
            ],
            onChanged: _isSubmitting
                ? null
                : (value) => setState(() => _status = value ?? 'published'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(_isSubmitting ? 'Saving...' : 'Save announcement'),
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
  final VoidCallback? onTap;

  const _DataCard({required this.row, this.onTap});

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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderPink),
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.isEmpty ? 'Synced item' : title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGray,
                    ),
                  ),
                ),
                if (onTap != null)
                  const Icon(Icons.chevron_right, color: AppColors.lightText),
              ],
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

class _AnnouncementDetailsPage extends StatefulWidget {
  final Map<String, dynamic> row;
  final bool canEdit;

  const _AnnouncementDetailsPage({required this.row, required this.canEdit});

  @override
  State<_AnnouncementDetailsPage> createState() =>
      _AnnouncementDetailsPageState();
}

// Officials can review, search, hide, and restore public feedback here.
class FeedbackManagementPage extends StatefulWidget {
  const FeedbackManagementPage({super.key});

  @override
  State<FeedbackManagementPage> createState() => _FeedbackManagementPageState();
}

class _FeedbackManagementPageState extends State<FeedbackManagementPage> {
  final _searchController = TextEditingController();
  bool _loading = false;
  String _status = 'all';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _feedback {
    final rows = (MobileApiService.syncedData?['feedback'] as List<dynamic>? ?? [])
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where((row) {
          final query = _searchController.text.trim().toLowerCase();
          final text = [
            row['name'],
            row['comment'],
            row['announcement_title'],
          ].join(' ').toLowerCase();
          return (_status == 'all' || row['status'] == _status) &&
              (query.isEmpty || text.contains(query));
        })
        .toList();
    return rows;
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await MobileApiService.sync();
    } on MobileApiException catch (exception) {
      if (mounted) _message(exception.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> row) async {
    final current = row['status']?.toString() ?? 'posted';
    final next = current == 'hidden' ? 'posted' : 'hidden';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(next == 'hidden' ? 'Hide feedback?' : 'Restore feedback?'),
        content: Text(
          next == 'hidden'
              ? 'This feedback will no longer appear as active.'
              : 'This feedback will be visible again to officials.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(next == 'hidden' ? 'Hide' : 'Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await MobileApiService.updateFeedback(
        feedbackId: int.parse(row['feedback_id'].toString()),
        status: next,
      );
      if (mounted) setState(() {});
    } on MobileApiException catch (exception) {
      if (mounted) _message(exception.message);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final rows = _feedback;
    return Scaffold(
      drawer: const PresidentSideDrawer(),
      backgroundColor: AppColors.lightGrayBg,
      bottomNavigationBar: PresidentBottomNavBar(
        activeItem: null,
        onItemSelected: (item) => handleRoleNavSelection(context, item),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              PresidentHeader(
                leading: PresidentHeaderLeading.menu,
                onLeadingTap: () => Scaffold.of(context).openDrawer(),
                title: 'Feedback',
                subtitle: 'Public feedback management',
              ),
              if (_loading) const LinearProgressIndicator(minHeight: 3),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Search feedback...',
                          prefixIcon: Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'posted', child: Text('Active')),
                        DropdownMenuItem(value: 'hidden', child: Text('Hidden')),
                      ],
                      onChanged: (value) => setState(() => _status = value ?? 'all'),
                    ),
                  ],
                ),
              ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No feedback found.')),
                )
              else
                ...rows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: _FeedbackCard(
                      row: row,
                      onStatusTap: () => _changeStatus(row),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onStatusTap;

  const _FeedbackCard({required this.row, required this.onStatusTap});

  @override
  Widget build(BuildContext context) {
    final hidden = row['status'] == 'hidden';
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row['announcement_title']?.toString() ?? 'Announcement',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(label: Text(hidden ? 'Hidden' : 'Active')),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              row['name']?.toString() ?? 'Anonymous',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(row['comment']?.toString() ?? ''),
            const SizedBox(height: 8),
            Text(
              row['created_at']?.toString() ?? 'No date',
              style: const TextStyle(color: AppColors.lightText, fontSize: 12),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onStatusTap,
                icon: Icon(hidden ? Icons.restore : Icons.visibility_off_outlined),
                label: Text(hidden ? 'Restore' : 'Hide'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementDetailsPageState extends State<_AnnouncementDetailsPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late String _audience;
  late String _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.row['title']?.toString() ?? 'Announcement',
    );
    _contentController = TextEditingController(
      text: widget.row['content']?.toString() ?? '',
    );
    _audience = widget.row['visibility']?.toString() == 'officials_only'
        ? 'officials_only'
        : 'public';
    _status = widget.row['status']?.toString() == 'draft'
        ? 'draft'
        : 'published';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = int.tryParse(widget.row['announcement_id']?.toString() ?? '');
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (id == null || title.isEmpty || content.isEmpty) {
      _message('Title and content are required.');
      return;
    }

    setState(() => _saving = true);
    try {
      await MobileApiService.updateWallPost(
        announcementId: id,
        title: title,
        content: content,
        audience: _audience,
        status: _status,
      );
      if (mounted) {
        _message('Announcement updated.');
        Navigator.pop(context, true);
      }
    } on MobileApiException catch (exception) {
      if (mounted) _message(exception.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: AppColors.primaryRed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fieldEnabled = widget.canEdit && !_saving;
    final author = widget.row['author_name']?.toString().trim();
    final createdAt = widget.row['created_at']?.toString();
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      appBar: AppBar(
        title: const Text('Announcement details'),
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            [
              if (author != null && author.isNotEmpty) 'By $author',
              if (createdAt != null && createdAt.isNotEmpty) createdAt,
            ].join('  -  '),
            style: const TextStyle(color: AppColors.lightText),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            enabled: fieldEnabled,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            enabled: fieldEnabled,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Content',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _audience,
            decoration: const InputDecoration(
              labelText: 'Audience',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            items: const [
              DropdownMenuItem(value: 'public', child: Text('Public')),
              DropdownMenuItem(
                value: 'officials_only',
                child: Text('Officials only'),
              ),
            ],
            onChanged: fieldEnabled
                ? (value) => setState(() => _audience = value ?? 'public')
                : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            items: const [
              DropdownMenuItem(value: 'published', child: Text('Published')),
              DropdownMenuItem(value: 'draft', child: Text('Draft')),
            ],
            onChanged: fieldEnabled
                ? (value) => setState(() => _status = value ?? 'published')
                : null,
          ),
          if (widget.canEdit) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_saving ? 'Saving...' : 'Save changes'),
            ),
          ],
        ],
      ),
    );
  }
}
