import 'package:flutter/material.dart';

import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';
import '../../widgets/community_avatar.dart';

/// Shared by the home feed and announcements; posts use the existing API.
class CreatePostScreen extends StatefulWidget {
  final String initialCategory;
  final String initialContent;
  const CreatePostScreen({
    super.key,
    this.initialCategory = 'update',
    this.initialContent = '',
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late final TextEditingController _content = TextEditingController(
    text: widget.initialContent,
  );
  final _link = TextEditingController();
  late String _category = widget.initialCategory;
  String _visibility = 'public';
  bool _posting = false;
  bool _showLink = false;
  bool _published = false;
  bool _discarding = false;
  String? _error;

  @override
  void dispose() {
    _content.dispose();
    _link.dispose();
    super.dispose();
  }

  /// Only the president's announcements can be limited to officials, matching
  /// the web announcement form. Every other post is public.
  bool get _choosesAudience =>
      MobileApiService.currentUser?['role'] == 'sk_president' &&
      _category == 'announcement';

  bool get _officialsOnly =>
      _choosesAudience && _visibility == 'officials_only';

  Future<void> _leave() async {
    if (_posting || _discarding) return;
    if (_content.text.trim().isEmpty && _link.text.trim().isEmpty) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this post?'),
        content: const Text('Your draft has not been published.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      setState(() => _discarding = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _submit() async {
    final link = _showLink ? _link.text.trim() : '';
    final uri = Uri.tryParse(link);
    if (link.isNotEmpty &&
        (uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.host.isEmpty)) {
      setState(() => _error = 'Enter a complete link starting with https://.');
      return;
    }
    final text = [
      _content.text.trim(),
      if (link.isNotEmpty) link,
    ].where((p) => p.isNotEmpty).join('\n\n');
    if (text.isEmpty || text.length > 5000) {
      setState(
        () => _error = text.isEmpty
            ? 'Write something before posting.'
            : 'Keep your post and link within 5,000 characters.',
      );
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      await MobileApiService.createWallPost(
        content: text,
        category: _category,
        visibility: _officialsOnly ? 'officials_only' : 'public',
      );
      if (!mounted) return;
      setState(() => _published = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
    } on MobileApiException catch (exception) {
      if (mounted) {
        setState(() {
          _posting = false;
          _error = exception.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = MobileApiService.currentUser ?? {};
    final name = [
      user['first_name'],
      user['last_name'],
    ].where((p) => p != null).join(' ');
    return PopScope(
      canPop:
          _published ||
          _discarding ||
          (!_posting &&
              _content.text.trim().isEmpty &&
              _link.text.trim().isEmpty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightGrayBg,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close composer',
            onPressed: _posting ? null : _leave,
            icon: const Icon(Icons.close_rounded),
          ),
          title: const Text('Create Post'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton(
                onPressed:
                    _posting ||
                        (_content.text.trim().isEmpty &&
                            _link.text.trim().isEmpty)
                    ? null
                    : _submit,
                child: Text(_posting ? 'Posting…' : 'Post'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CommunityAvatar(
                    name: name,
                    photoUrl: user['profile_pic_url']?.toString(),
                    radius: 25,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'SK official' : name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              _officialsOnly
                                  ? Icons.shield_outlined
                                  : Icons.public_rounded,
                              size: 16,
                              color: AppColors.lightText,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                _officialsOnly
                                    ? 'Officials only · SK council'
                                    : 'Public · SK community',
                                style: const TextStyle(
                                  color: AppColors.lightText,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _content,
                enabled: !_posting,
                onChanged: (_) => setState(() {}),
                minLines: 6,
                maxLines: null,
                maxLength: 5000,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 18, height: 1.5),
                decoration: InputDecoration(
                  hintText: 'What’s happening in your council?',
                  hintStyle: TextStyle(
                    fontSize: 18,
                    color: AppColors.lightText,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.all(20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpace.radius),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpace.radius),
                    borderSide: const BorderSide(
                      color: AppColors.border,
                      width: .7,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Post type',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'update',
                    child: Text('Update'),
                  ),
                  if (user['role'] == 'sk_president')
                    const DropdownMenuItem(
                      value: 'announcement',
                      child: Text('Announcement'),
                    ),
                  const DropdownMenuItem(value: 'event', child: Text('Event')),
                  const DropdownMenuItem(
                    value: 'accomplishment',
                    child: Text('Accomplishment'),
                  ),
                ],
                onChanged: _posting
                    ? null
                    : (value) => setState(() => _category = value ?? 'update'),
              ),
              if (_choosesAudience) ...[
                const SizedBox(height: 20),
                Text('Audience', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                _AudienceOption(
                  icon: Icons.public_rounded,
                  title: 'Public',
                  subtitle: 'Everyone, including the public website',
                  selected: !_officialsOnly,
                  onTap: _posting
                      ? null
                      : () => setState(() => _visibility = 'public'),
                ),
                const SizedBox(height: 8),
                _AudienceOption(
                  icon: Icons.shield_outlined,
                  title: 'Officials only',
                  subtitle: 'SK chairmen and secretaries in the app',
                  selected: _officialsOnly,
                  onTap: _posting
                      ? null
                      : () => setState(() => _visibility = 'officials_only'),
                ),
              ],
              const SizedBox(height: 20),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                leading: const AppIconTile(icon: Icons.link_rounded),
                title: const Text('Add a link'),
                subtitle: const Text('Share a photo album, video, or resource'),
                trailing: Icon(
                  _showLink
                      ? Icons.remove_circle_outline
                      : Icons.add_circle_outline,
                ),
                onTap: _posting
                    ? null
                    : () => setState(() => _showLink = !_showLink),
              ),
              const SizedBox(height: 12),
              if (_showLink)
                TextField(
                  controller: _link,
                  enabled: !_posting,
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'https://',
                    labelText: 'Attachment link',
                  ),
                ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: false,
                leading: Icon(Icons.photo_library_outlined),
                title: Text('Photo / video'),
                subtitle: Text(
                  'Uploads are not available yet. You can add a link instead.',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _officialsOnly
                    ? 'Only SK officials will see this announcement in the '
                          'app. It won’t appear on the public website.'
                    : 'This post will be visible to everyone in the SK '
                          'community.',
                style: const TextStyle(
                  color: AppColors.lightText,
                  fontSize: 13,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error),
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

class _AudienceOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  const _AudienceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryRed : AppColors.muted;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? AppColors.softPink : AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpace.controlRadius),
          side: BorderSide(
            color: selected ? AppColors.primaryRed : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                AppIconTile(icon: icon, color: color, size: 19),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
