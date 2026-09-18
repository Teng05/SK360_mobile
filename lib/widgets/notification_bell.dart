import 'dart:async';

import 'package:flutter/material.dart';

import '../services/mobile_api_service.dart';
import '../screens/shared/meeting_webview_screen.dart';
import '../ui/app_ui.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!MobileApiService.isLoggedIn) return;
      try {
        await MobileApiService.sync();
        if (mounted) setState(() {});
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get _notifications {
    final rows = (MobileApiService.syncedData?['notifications'] as List?) ?? [];
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications
        .where((item) => item['is_read'] != true && item['is_read'] != 1)
        .length;

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => _openNotifications(context),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded, color: Colors.white),
          if (unread > 0)
            Positioned(
              right: -4,
              top: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFC107),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openNotifications(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => _NotificationSheet(
        notifications: _notifications,
        onMarkRead: _markRead,
        onOpen: (item) => _openNotification(context, item),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _markRead(int id) async {
    try {
      await MobileApiService.markNotificationRead(id);
      if (mounted) setState(() {});
    } on MobileApiException catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(exception.message),
            backgroundColor: AppColors.primaryRed,
          ),
        );
      }
    }
  }

  Future<void> _openNotification(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final id = int.tryParse(
      '${item['notification_id'] ?? item['id'] ?? ''}',
    );
    if (id != null && item['is_read'] != true && item['is_read'] != 1) {
      await _markRead(id);
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _NotificationDetails(item: item),
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  final List<Map<String, dynamic>> notifications;
  final ValueChanged<int> onMarkRead;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const _NotificationSheet({
    required this.notifications,
    required this.onMarkRead,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'Notifications',
                style: TextStyle(
                  color: AppColors.darkGray,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            if (notifications.isEmpty)
              const Expanded(child: Center(child: Text('No notifications yet')))
            else
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final item = notifications[index];
                    final isRead =
                        item['is_read'] == true || item['is_read'] == 1;
                    final id = int.tryParse(
                      '${item['notification_id'] ?? item['id'] ?? ''}',
                    );
                    return ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        onOpen(item);
                      },
                      tileColor: isRead ? Colors.white : AppColors.softPink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.borderPink),
                      ),
                      leading: Icon(
                        isRead
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                        color: AppColors.primaryRed,
                      ),
                      title: Text(
                        _title(item),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _body(item),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isRead || id == null
                          ? null
                          : TextButton(
                              onPressed: () => onMarkRead(id),
                              child: const Text('Read'),
                            ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _title(Map<String, dynamic> item) =>
      '${item['title'] ?? item['notification_title'] ?? item['type'] ?? 'Notification'}';

  String _body(Map<String, dynamic> item) =>
      '${item['message'] ?? item['body'] ?? item['content'] ?? item['description'] ?? ''}';
}

class _NotificationDetails extends StatelessWidget {
  final Map<String, dynamic> item;

  const _NotificationDetails({required this.item});

  @override
  Widget build(BuildContext context) {
    final url = item['url']?.toString().trim() ?? '';
    final timestamp = item['created_at']?.toString() ??
        item['read_at']?.toString() ??
        '';

    return AlertDialog(
      title: Text(_title(item)),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (timestamp.isNotEmpty)
              Text(
                timestamp,
                style: const TextStyle(color: AppColors.lightText),
              ),
            const SizedBox(height: 12),
            Text(_body(item)),
          ],
        ),
      ),
      actions: [
        if (url.isNotEmpty)
          TextButton.icon(
            onPressed: () {
              final navigator = Navigator.of(context);
              navigator.pop();
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => MeetingWebViewScreen(
                    url: _webUrl(url),
                    title: 'Related information',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open related record'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _webUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return MobileApiService.webUrl(value);
  }

  String _title(Map<String, dynamic> value) =>
      '${value['title'] ?? value['notification_title'] ?? value['type'] ?? 'Notification'}';

  String _body(Map<String, dynamic> value) =>
      '${value['message'] ?? value['body'] ?? value['content'] ?? value['description'] ?? 'No details available.'}';
}
