import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/mobile_api_service.dart';
import '../ui/app_ui.dart';
import 'community_avatar.dart';

class CommunityPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final Future<void> Function()? onLike;
  final Future<void> Function()? onCommentChanged;
  final VoidCallback? onEdit;
  const CommunityPostCard({
    super.key,
    required this.post,
    this.onLike,
    this.onCommentChanged,
    this.onEdit,
  });

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> {
  bool _expanded = false;
  bool _liking = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final author = post['author_name']?.toString() ?? 'SK 360 Official';
    final content = post['content']?.toString() ?? '';
    final category = post['title']?.toString() ?? 'Update';
    final liked =
        post['liked_by_current_user'] == true ||
        post['liked_by_current_user'] == 1;
    final likes = int.tryParse('${post['likes_count'] ?? 0}') ?? 0;
    final comments = int.tryParse('${post['feedback_count'] ?? 0}') ?? 0;
    final categoryColor = postCategoryColor(category);
    final officialsOnly = post['visibility'] == 'officials_only';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: DecoratedBox(
        decoration: AppDecorations.surface(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CommunityAvatar(
                    name: author,
                    photoUrl: post['author_profile_pic_url']?.toString(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          author,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        AppMeta(
                          icon: officialsOnly
                              ? Icons.shield_outlined
                              : Icons.public_rounded,
                          label:
                              '${_dateLabel(post['created_at']?.toString() ?? '')} · '
                              '${officialsOnly ? 'SK officials' : 'SK community'}',
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Post options',
                    onSelected: (value) {
                      if (value == 'edit') {
                        widget.onEdit?.call();
                      } else {
                        _copy(author, content);
                      }
                    },
                    itemBuilder: (_) => [
                      if (widget.onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit announcement'),
                        ),
                      const PopupMenuItem(
                        value: 'copy',
                        child: Text('Copy post text'),
                      ),
                    ],
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: AppColors.lightText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  AppStatusBadge(
                    label: category,
                    color: categoryColor,
                    dot: true,
                  ),
                  if (officialsOnly)
                    const AppStatusBadge(
                      label: 'Officials only',
                      color: AppColors.info,
                      icon: Icons.shield_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final style = Theme.of(context).textTheme.bodyLarge;
                  final painter = TextPainter(
                    text: TextSpan(text: content, style: style),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                    maxLines: 7,
                  )..layout(maxWidth: constraints.maxWidth);
                  final truncated = painter.didExceedMaxLines;
                  painter.dispose();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content,
                        maxLines: _expanded ? null : 7,
                        overflow: _expanded ? null : TextOverflow.ellipsis,
                        style: style,
                      ),
                      if (truncated)
                        TextButton(
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                          child: Text(_expanded ? 'See less' : 'See more'),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.thumb_up_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '$likes ${likes == 1 ? 'like' : 'likes'} · '
                      '$comments ${comments == 1 ? 'comment' : 'comments'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(14) > 19;
                  return Row(
                    children: [
                      Expanded(
                        child: _action(
                          context,
                          liked ? 'Liked' : 'Like',
                          liked
                              ? Icons.thumb_up_rounded
                              : Icons.thumb_up_outlined,
                          widget.onLike == null || _liking ? null : _like,
                          compact,
                          selected: liked,
                        ),
                      ),
                      Expanded(
                        child: _action(
                          context,
                          'Comment',
                          Icons.mode_comment_outlined,
                          _showComments,
                          compact,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback? onPressed,
    bool compact, {
    bool selected = false,
  }) {
    final color = selected ? AppColors.actionRed : AppColors.lightText;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),
      child: compact
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label, style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
    );
  }

  Future<void> _like() async {
    setState(() => _liking = true);
    try {
      await widget.onLike!();
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _copy(String author, String content) async {
    await Clipboard.setData(
      ClipboardData(text: '$author · SK 360°\n\n$content'),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post copied.')));
    }
  }

  Future<void> _showComments() async {
    final id = int.tryParse(
      '${widget.post['announcement_id'] ?? widget.post['id'] ?? ''}',
    );
    if (id == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CommentsSheet(
        announcementId: id,
        title: widget.post['title']?.toString() ?? 'Post comments',
        onCommentPosted: widget.onCommentChanged,
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final int announcementId;
  final String title;
  final Future<void> Function()? onCommentPosted;

  const _CommentsSheet({
    required this.announcementId,
    required this.title,
    this.onCommentPosted,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  late Future<List<Map<String, dynamic>>> _commentsFuture;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _commentsFuture = _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadComments() async {
    final response = await MobileApiService.wallPostComments(
      widget.announcementId,
    );
    final rows = (response['feedbacks'] ?? response['comments']) as List<dynamic>? ?? [];
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<void> _postComment() async {
    final comment = _controller.text.trim();
    if (comment.isEmpty || _posting) return;

    setState(() => _posting = true);
    try {
      await MobileApiService.storeWallPostComment(
        announcementId: widget.announcementId,
        comment: comment,
      );
      _controller.clear();
      await widget.onCommentPosted?.call();
      if (mounted) {
        setState(() => _commentsFuture = _loadComments());
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendlyError(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .74,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Comments', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _commentsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return AppEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Unable to load comments',
                      message: _friendlyError(snapshot.error),
                    );
                  }
                  final comments = snapshot.data ?? [];
                  if (comments.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.mode_comment_outlined,
                      title: 'No comments yet',
                      message: 'Be the first to comment on this post.',
                    );
                  }
                  return ListView.separated(
                    itemCount: comments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      final name = comment['name']?.toString() ?? 'SK Official';
                      final role = comment['role_label']?.toString();
                      final barangay = comment['barangay_name']?.toString();
                      return DecoratedBox(
                        decoration: AppDecorations.inset(),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CommunityAvatar(name: name),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    if (role != null && role.isNotEmpty)
                                      Text(
                                        [
                                          role,
                                          if (barangay != null &&
                                              barangay.isNotEmpty)
                                            'Barangay $barangay',
                                        ].join(' · '),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    const SizedBox(height: 6),
                                    Text(
                                      comment['comment']?.toString() ?? '',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment...',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _posting ? null : _postComment,
                  child: _posting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _friendlyError(Object? error) {
  if (error is MobileApiException) return error.message;
  return 'Please check your connection and try again.';
}

/// Category tones: announcements red, accomplishments green, events blue,
/// everything else a soft yellow highlight.
Color postCategoryColor(String category) {
  final value = category.toLowerCase();
  if (value.contains('announcement')) return AppColors.primaryRed;
  if (value.contains('accomplishment')) return AppColors.success;
  if (value.contains('event')) return AppColors.info;
  return AppColors.highlight;
}

String _dateLabel(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value.isEmpty ? 'Community update' : value;
  final elapsed = DateTime.now().difference(date);
  if (!elapsed.isNegative && elapsed.inMinutes < 1) return 'Just now';
  if (!elapsed.isNegative && elapsed.inHours < 1) {
    return '${elapsed.inMinutes}m';
  }
  if (!elapsed.isNegative && elapsed.inDays < 1) return '${elapsed.inHours}h';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}${date.year == DateTime.now().year ? '' : ', ${date.year}'}';
}
