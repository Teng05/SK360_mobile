import 'package:flutter/material.dart';

import '../routes.dart';
import '../services/mobile_api_service.dart';
import '../ui/app_ui.dart';
import 'notification_bell.dart';

enum PresidentNavItem {
  home,
  calendar,
  chat,
  announcements,
  leadership,
  rankings,
  profile,
}

enum PresidentHeaderLeading { menu, back, none }

class PresidentHeader extends StatelessWidget {
  final PresidentHeaderLeading leading;
  final VoidCallback? onLeadingTap;
  final String title;
  final String subtitle;
  final List<Widget>? trailing;
  final Widget? customContent;

  const PresidentHeader({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.onLeadingTap,
    this.trailing,
    this.customContent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 18),
      decoration: const BoxDecoration(
        color: AppColors.primaryRed,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != PresidentHeaderLeading.none)
            IconButton(
              onPressed: onLeadingTap,
              icon: Icon(
                leading == PresidentHeaderLeading.menu
                    ? Icons.menu_rounded
                    : Icons.arrow_back_ios_new,
                color: Colors.white,
              ),
            )
          else
            const SizedBox(width: 48),
          Expanded(child: customContent ?? _buildDefaultCenter()),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const NotificationBell(),
              if (trailing != null) ...trailing!,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultCenter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
      ],
    );
  }
}

class PresidentBottomNavBar extends StatelessWidget {
  final PresidentNavItem? activeItem;
  final ValueChanged<PresidentNavItem> onItemSelected;

  const PresidentBottomNavBar({
    super.key,
    required this.activeItem,
    required this.onItemSelected,
  });

  static const List<_BottomItem> _items = [
    _BottomItem(PresidentNavItem.home, 'Home', Icons.home_outlined),
    _BottomItem(PresidentNavItem.calendar, 'Calendar', Icons.event_note),
    _BottomItem(PresidentNavItem.chat, 'Chat', Icons.chat_bubble_outline),
    _BottomItem(PresidentNavItem.profile, 'Profile', Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    final role = (MobileApiService.currentUser?['role'] ?? '').toString();
    final items = role == 'youth'
        ? const [
            _BottomItem(PresidentNavItem.home, 'Home', Icons.home_outlined),
            _BottomItem(
              PresidentNavItem.announcements,
              'News',
              Icons.campaign_outlined,
            ),
            _BottomItem(
              PresidentNavItem.leadership,
              'Leaders',
              Icons.badge_outlined,
            ),
            _BottomItem(
              PresidentNavItem.rankings,
              'Ranks',
              Icons.emoji_events_outlined,
            ),
            _BottomItem(
              PresidentNavItem.profile,
              'Profile',
              Icons.person_outline,
            ),
          ]
        : _items;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.primaryRed,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((item) {
          final bool isActive = item.item == activeItem;
          return GestureDetector(
            onTap: () => onItemSelected(item.item),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  color: isActive ? const Color(0xFFFFD54F) : Colors.white70,
                ),
                const SizedBox(height: 6),
                Text(
                  item.label,
                  style: TextStyle(
                    color: isActive ? const Color(0xFFFFD54F) : Colors.white70,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BottomItem {
  final PresidentNavItem item;
  final String label;
  final IconData icon;

  const _BottomItem(this.item, this.label, this.icon);
}

class PresidentSideDrawer extends StatelessWidget {
  const PresidentSideDrawer({super.key});

  static final List<_DrawerItem> _presidentItems = [
    _DrawerItem('Consolidation', Icons.folder_copy_outlined),
    _DrawerItem('Module Management', Icons.tune),
    _DrawerItem('View Reports', Icons.receipt_long),
    _DrawerItem('Announcements', Icons.campaign_outlined),
    _DrawerItem('Leadership Profiles', Icons.badge_outlined),
    _DrawerItem('Video Meetings', Icons.video_call),
    _DrawerItem('Rankings', Icons.emoji_events_outlined),
  ];

  static final List<_DrawerItem> _chairmanItems = [
    _DrawerItem('Reports', Icons.receipt_long),
    _DrawerItem('Budget', Icons.account_balance_wallet_outlined),
    _DrawerItem('Announcements', Icons.campaign_outlined),
    _DrawerItem('Leadership Profiles', Icons.badge_outlined),
    _DrawerItem('Video Meetings', Icons.video_call),
    _DrawerItem('Rankings', Icons.emoji_events_outlined),
  ];

  static final List<_DrawerItem> _youthItems = [
    _DrawerItem('Announcements', Icons.campaign_outlined),
    _DrawerItem('Leadership Profiles', Icons.badge_outlined),
    _DrawerItem('Rankings', Icons.emoji_events_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final role = _currentRole();
    final isOfficial = role == 'sk_chairman' || role == 'sk_secretary';
    final menuItems = role == 'youth'
        ? _youthItems
        : isOfficial
        ? _chairmanItems
        : _presidentItems;
    final roleLabel = switch (role) {
      'sk_chairman' => 'SK Chairman',
      'sk_secretary' => 'SK Secretary',
      'youth' => 'Youth',
      _ => 'SK Federation President',
    };

    return Drawer(
      child: Container(
        color: AppColors.primaryRed,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SK 360°',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  roleLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 32),
                ...menuItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: GestureDetector(
                      onTap: () => _handleMenuItemTap(context, item.label),
                      child: Row(
                        children: [
                          Icon(
                            item.icon,
                            color: _selectedItem(context) == item.label
                                ? const Color(0xFFFFD54F)
                                : Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: _selectedItem(context) == item.label
                                  ? const Color(0xFFFFD54F)
                                  : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Empowering Youth Governance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _selectedItem(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name;
    return switch (route) {
      AppRoutes.consolidation => 'Consolidation',
      AppRoutes.moduleManagement => 'Module Management',
      AppRoutes.reports => 'View Reports',
      AppRoutes.budget => 'Budget',
      AppRoutes.announcements => 'Announcements',
      AppRoutes.leadershipProfiles => 'Leadership Profiles',
      AppRoutes.videoMeetings => 'Video Meetings',
      AppRoutes.rankings => 'Rankings',
      _ => null,
    };
  }

  void _handleMenuItemTap(BuildContext context, String itemLabel) {
    Navigator.pop(context);

    switch (itemLabel) {
      case 'Video Meetings':
        Navigator.pushNamed(context, AppRoutes.videoMeetings);
        break;
      case 'Consolidation':
        Navigator.pushNamed(context, AppRoutes.consolidation);
        break;
      case 'Module Management':
        Navigator.pushNamed(context, AppRoutes.moduleManagement);
        break;
      case 'View Reports':
      case 'Reports':
        Navigator.pushNamed(context, AppRoutes.reports);
        break;
      case 'Budget':
        Navigator.pushNamed(context, AppRoutes.budget);
        break;
      case 'Announcements':
        Navigator.pushNamed(context, AppRoutes.announcements);
        break;
      case 'Leadership Profiles':
        Navigator.pushNamed(context, AppRoutes.leadershipProfiles);
        break;
      case 'Rankings':
        Navigator.pushNamed(context, AppRoutes.rankings);
        break;
    }
  }

  String _currentRole() {
    try {
      // Kept local to avoid changing existing imports across older screens.
      return (MobileApiService.currentUser?['role'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }
}

class _DrawerItem {
  final String label;
  final IconData icon;

  const _DrawerItem(this.label, this.icon);
}

void handleRoleNavSelection(BuildContext context, PresidentNavItem item) {
  switch (item) {
    case PresidentNavItem.home:
      Navigator.pushReplacementNamed(context, _homeRouteForCurrentRole());
      break;
    case PresidentNavItem.calendar:
      Navigator.pushReplacementNamed(context, AppRoutes.presidentCalendar);
      break;
    case PresidentNavItem.chat:
      Navigator.pushReplacementNamed(context, AppRoutes.presidentMessages);
      break;
    case PresidentNavItem.announcements:
      Navigator.pushReplacementNamed(context, AppRoutes.announcements);
      break;
    case PresidentNavItem.leadership:
      Navigator.pushReplacementNamed(context, AppRoutes.leadershipProfiles);
      break;
    case PresidentNavItem.rankings:
      Navigator.pushReplacementNamed(context, AppRoutes.rankings);
      break;
    case PresidentNavItem.profile:
      Navigator.pushReplacementNamed(context, AppRoutes.profile);
      break;
  }
}

String _homeRouteForCurrentRole() {
  final role = (MobileApiService.currentUser?['role'] ?? '').toString();
  return switch (role) {
    'sk_chairman' => AppRoutes.chairmanHome,
    'sk_secretary' => AppRoutes.secretaryHome,
    'youth' => AppRoutes.youthHome,
    _ => AppRoutes.presidentHome,
  };
}
