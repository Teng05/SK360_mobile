import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/mobile_api_service.dart';
import '../../ui/app_ui.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  NotificationFilter _filter = NotificationFilter.all;
  Timer? _refreshTimer;
  bool _refreshing = false;
  bool _markingAll = false;
  bool _opening = false;
  int? _openingId;
  String? _error;

  List<AppNotification> get _notifications {
    final rows = MobileApiService.syncedData?['notifications'] as List? ?? [];
    final items = rows
        .whereType<Map>()
        .map((row) => AppNotification(Map<String, dynamic>.from(row)))
        .toList();
    items.sort((a, b) {
      final order = (b.createdAt ?? DateTime(1970)).compareTo(
        a.createdAt ?? DateTime(1970),
      );
      return order != 0 ? order : (b.id ?? 0).compareTo(a.id ?? 0);
    });
    return items;
  }

  @override
  void initState() {
    super.initState();
    _refresh();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (MobileApiService.isLoggedIn &&
          ModalRoute.of(context)?.isCurrent == true) {
        _refresh(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing || _markingAll || _opening) return;
    setState(() => _refreshing = true);
    try {
      await MobileApiService.sync();
      if (mounted) setState(() => _error = null);
    } on MobileApiException catch (exception) {
      if (mounted && !silent) setState(() => _error = exception.message);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAll || _opening || _refreshing) return;
    final ids = _notifications
        .where((item) => !item.isRead)
        .map((item) => item.id)
        .whereType<int>()
        .toSet();
    setState(() {
      _markingAll = true;
      _error = null;
    });
    try {
      // Reuse the existing per-notification endpoint, including its sync.
      for (final id in ids) {
        await MobileApiService.markNotificationRead(id);
        if (!mounted) return;
        setState(() {});
      }
    } on MobileApiException catch (exception) {
      if (mounted) {
        setState(
          () => _error =
              'Some notifications could not be marked as read. ${exception.message}',
        );
      }
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _openNotification(AppNotification item) async {
    if (_opening || _markingAll || _refreshing) return;
    setState(() {
      _opening = true;
      _openingId = item.id;
      _error = null;
    });
    try {
      if (!item.isRead && item.id != null) {
        await MobileApiService.markNotificationRead(item.id!);
      }
    } on MobileApiException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    }
    if (!mounted) return;
    setState(() {
      _opening = false;
      _openingId = null;
    });
    final destination = item.destination(
      '${MobileApiService.currentUser?['role'] ?? ''}',
    );
    if (destination != null) {
      await Navigator.pushNamed(context, destination);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _notifications;
    final visible = items.where(_filter.includes).toList();
    final unread = items
        .where((item) => !item.isRead && item.id != null)
        .length;
    final busy = _markingAll || _opening || _refreshing;
    final role = '${MobileApiService.currentUser?['role'] ?? ''}';
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            _NotificationsHeader(
              markingAll: _markingAll,
              unread: unread,
              onMarkAll: unread == 0 || busy ? null : _markAllRead,
            ),
            const SizedBox(height: 14),
            AppFilterPills(
              labels: [
                for (final filter in NotificationFilter.values) filter.label,
              ],
              selectedIndex: NotificationFilter.values.indexOf(_filter),
              onSelected: (index) =>
                  setState(() => _filter = NotificationFilter.values[index]),
            ),
            const SizedBox(height: 12),
            if (_refreshing) const AppLoadingIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    if (visible.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: _refreshing && items.isEmpty
                              ? const Text(
                                  'Loading notifications…',
                                  style: TextStyle(color: AppColors.lightText),
                                )
                              : AppEmptyState(
                                  icon: Icons.notifications_none_rounded,
                                  title: _error != null && items.isEmpty
                                      ? 'Unable to load notifications'
                                      : items.isEmpty ||
                                            _filter == NotificationFilter.all
                                      ? 'No notifications yet'
                                      : _filter == NotificationFilter.unread
                                      ? 'No unread notifications'
                                      : 'No ${_filter.label.toLowerCase()} notifications',
                                  message: _error != null && items.isEmpty
                                      ? 'Check your connection and try again.'
                                      : items.isEmpty ||
                                            _filter == NotificationFilter.unread
                                      ? 'You’re all caught up. New updates will appear here.'
                                      : 'Updates in this category will appear here.',
                                  onAction: _error != null ? _refresh : null,
                                ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        sliver: SliverList.separated(
                          itemCount: visible.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = visible[index];
                            return _NotificationCard(
                              item: item,
                              opening: _opening && _openingId == item.id,
                              onTap:
                                  busy ||
                                      (item.destination(role) == null &&
                                          (item.isRead || item.id == null))
                                  ? null
                                  : () => _openNotification(item),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  final VoidCallback? onMarkAll;
  final bool markingAll;
  final int unread;
  const _NotificationsHeader({
    required this.onMarkAll,
    required this.markingAll,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth < 360 ||
          MediaQuery.textScalerOf(context).scale(14) > 18;
      final action = TextButton(
        onPressed: onMarkAll,
        child: Text(
          markingAll ? 'Marking as read…' : 'Mark all as read',
          style: const TextStyle(fontSize: 13),
        ),
      );
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          children: [
            Row(
              children: [
                AppHeaderButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                  icon: Icons.arrow_back_rounded,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Notifications',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        unread == 0 ? 'You’re all caught up' : '$unread unread',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: unread == 0
                              ? AppColors.lightText
                              : AppColors.primaryRed,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!compact) action,
              ],
            ),
            if (compact) Align(alignment: Alignment.centerRight, child: action),
          ],
        ),
      );
    },
  );
}

class _NotificationCard extends StatelessWidget {
  final AppNotification item;
  final VoidCallback? onTap;
  final bool opening;
  const _NotificationCard({
    required this.item,
    required this.onTap,
    required this.opening,
  });

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.kind) {
      NotificationKind.announcement => Icons.campaign_outlined,
      NotificationKind.event => Icons.calendar_month_outlined,
      NotificationKind.meeting => Icons.videocam_outlined,
      NotificationKind.message => Icons.chat_bubble_outline_rounded,
      NotificationKind.submission => Icons.description_outlined,
      NotificationKind.module => Icons.menu_book_outlined,
      NotificationKind.ranking => Icons.emoji_events_outlined,
      NotificationKind.other => Icons.notifications_none_rounded,
    };
    final tone = switch (item.kind) {
      NotificationKind.announcement => AppColors.primaryRed,
      NotificationKind.event => AppColors.info,
      NotificationKind.meeting => AppColors.info,
      NotificationKind.message => AppColors.info,
      NotificationKind.submission => AppColors.warning,
      NotificationKind.module => AppColors.warning,
      NotificationKind.ranking => AppColors.highlight,
      NotificationKind.other => AppColors.muted,
    };
    final color = item.isRead
        ? AppColors.white
        : Color.alphaBlend(
            AppColors.primaryRed.withValues(alpha: .04),
            AppColors.white,
          );
    final time = item.createdAt;
    return Semantics(
      label: item.isRead ? 'Read notification' : 'Unread notification',
      child: AppAccentCard(
        accent: item.isRead ? Colors.transparent : AppColors.primaryRed,
        color: color,
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconTile(icon: icon, size: 21, color: tone),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: item.isRead
                          ? FontWeight.w400
                          : FontWeight.w700,
                    ),
                  ),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.lightText,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (time != null)
                        Expanded(
                          child: Text(
                            _timeLabel(context, time),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        )
                      else
                        const Spacer(),
                      if (opening)
                        const SizedBox.square(
                          dimension: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (!item.isRead)
                        const AppStatusBadge(
                          label: 'New',
                          color: AppColors.primaryRed,
                          dot: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(BuildContext context, DateTime time) {
    final elapsed = DateTime.now().difference(time);
    if (elapsed.isNegative) {
      return MaterialLocalizations.of(context).formatMediumDate(time);
    }
    if (elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inHours < 1) {
      return '${elapsed.inMinutes} ${elapsed.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (elapsed.inDays < 1) {
      return '${elapsed.inHours} ${elapsed.inHours == 1 ? 'hour' : 'hours'} ago';
    }
    if (elapsed.inDays < 7) {
      return '${elapsed.inDays} ${elapsed.inDays == 1 ? 'day' : 'days'} ago';
    }
    return MaterialLocalizations.of(context).formatMediumDate(time);
  }
}
