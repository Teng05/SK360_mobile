import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/app_ui.dart';
import 'community_avatar.dart';

class CommunityPostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final Future<void> Function()? onLike;
  final VoidCallback? onEdit;
  const CommunityPostCard({
    super.key,
    required this.post,
    this.onLike,
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
                      '$likes ${likes == 1 ? 'like' : 'likes'}',
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
                        child: Tooltip(
                          message: 'Comments are not available yet',
                          child: _action(
                            context,
                            'Comment',
                            Icons.mode_comment_outlined,
                            null,
                            compact,
                          ),
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
