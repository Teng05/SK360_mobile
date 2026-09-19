import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../routes.dart';
import '../services/mobile_api_service.dart';
import '../ui/app_ui.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  Timer? _refreshTimer;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!MobileApiService.isLoggedIn ||
          _refreshing ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      _refreshing = true;
      try {
        await MobileApiService.sync();
        if (mounted) setState(() {});
      } catch (_) {
        // Keep the last badge when background refresh fails.
      } finally {
        _refreshing = false;
      }
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
        .where((item) => !AppNotification(item).isRead)
        .length;

    return IconButton(
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tooltip: 'Notifications',
      onPressed: () => _openNotifications(context),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            unread > 0
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
            color: AppColors.darkGray,
            size: 25,
          ),
          if (unread > 0)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: Center(
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
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
    await Navigator.pushNamed(context, AppRoutes.notifications);
    if (mounted) setState(() {});
  }
}
