import 'package:flutter/material.dart';

import '../routes.dart';
import '../services/mobile_api_service.dart';
import '../ui/app_ui.dart';
import 'community_avatar.dart';
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

/// The single page header used across the app:
/// [menu or back] [logo] Title / subtitle · [bell] [extra actions] [avatar].
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
        final roomy = constraints.maxWidth >= 360 && !largeText;
        final showLogo =
            customContent == null &&
            (title.startsWith('SK 360') ||
                (constraints.maxWidth >= 410 && !largeText));
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              if (leading != PresidentHeaderLeading.none) ...[
                AppHeaderButton(
                  tooltip: leading == PresidentHeaderLeading.menu
                      ? 'Open menu'
                      : 'Back',
                  onPressed: onLeadingTap,
                  icon: leading == PresidentHeaderLeading.menu
                      ? Icons.menu_rounded
                      : Icons.arrow_back_rounded,
                ),
                const SizedBox(width: 10),
              ] else
                const SizedBox(width: 4),
              if (showLogo) ...[
                const AppLogoTile(size: 36),
                const SizedBox(width: 10),
              ],
              Expanded(
                child:
                    customContent ??
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
              ),
              const SizedBox(width: 4),
              const NotificationBell(),
              if (trailing != null) ...trailing!,
              if (roomy) ...[const SizedBox(width: 6), const _HeaderAvatar()],
            ],
          ),
        );
      },
    );
  }
}

/// The signed-in official's photo, opening their profile.
class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar();

  @override
  Widget build(BuildContext context) {
    final user = MobileApiService.currentUser ?? {};
    final name = [
      user['first_name'],
      user['last_name'],
    ].where((part) => part != null).join(' ');
    return Tooltip(
      message: 'Your profile',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => handleRoleNavSelection(context, PresidentNavItem.profile),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderPink, width: 1.5),
          ),
          child: CommunityAvatar(
            name: name,
            photoUrl: user['profile_pic_url']?.toString(),
            radius: 17,
          ),
        ),
      ),
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
    _BottomItem(
      PresidentNavItem.home,
      'Home',
      Icons.home_outlined,
      Icons.home_rounded,
    ),
    _BottomItem(
      PresidentNavItem.calendar,
      'Calendar',
      Icons.calendar_month_outlined,
      Icons.calendar_month_rounded,
    ),
    _BottomItem(
      PresidentNavItem.chat,
      'Chat',
      Icons.chat_bubble_outline_rounded,
      Icons.chat_bubble_rounded,
    ),
    _BottomItem(
      PresidentNavItem.profile,
      'Profile',
      Icons.person_outline_rounded,
      Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A1B2130),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              children: _items.map((item) {
                final selected = item.item == activeItem;
                final color = selected
                    ? AppColors.primaryRed
                    : AppColors.lightText;
                return Expanded(
                  child: Semantics(
                    selected: selected,
                    button: true,
                    label: item.label,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: selected ? null : () => onItemSelected(item.item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.softPink
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                selected ? item.activeIcon : item.icon,
                                size: 23,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomItem {
  final PresidentNavItem item;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _BottomItem(this.item, this.label, this.icon, this.activeIcon);
}

class PresidentSideDrawer extends StatelessWidget {
  const PresidentSideDrawer({super.key});

  static final List<_DrawerItem> _presidentItems = [
    _DrawerItem('Consolidation', Icons.folder_copy_outlined),
    _DrawerItem('Module Management', Icons.dashboard_customize_outlined),
    _DrawerItem('View Reports', Icons.receipt_long_outlined),
    _DrawerItem('Announcements', Icons.campaign_outlined),
    _DrawerItem('Leadership Profiles', Icons.badge_outlined),
    _DrawerItem('Video Meetings', Icons.videocam_outlined),
    _DrawerItem('Rankings', Icons.emoji_events_outlined),
  ];

  static final List<_DrawerItem> _chairmanItems = [
    _DrawerItem('Reports', Icons.receipt_long_outlined),
    _DrawerItem('Budget', Icons.account_balance_wallet_outlined),
    _DrawerItem('Announcements', Icons.campaign_outlined),
    _DrawerItem('Leadership Profiles', Icons.badge_outlined),
    _DrawerItem('Video Meetings', Icons.videocam_outlined),
    _DrawerItem('Rankings', Icons.emoji_events_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final role = _currentRole();
    final isOfficial = role == 'sk_chairman' || role == 'sk_secretary';
    final menuItems = isOfficial ? _chairmanItems : _presidentItems;
    final roleLabel = switch (role) {
      'sk_chairman' => 'SK Chairman',
      'sk_secretary' => 'SK Secretary',
      _ => 'SK Federation President',
    };
    final user = MobileApiService.currentUser ?? {};
    final name = [
      user['first_name'],
      user['last_name'],
    ].where((part) => part != null).join(' ');
    return Drawer(
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            const AppHeader(),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.softPink,
                borderRadius: BorderRadius.circular(AppSpace.radius),
                border: Border.all(color: AppColors.borderPink),
              ),
              child: Row(
                children: [
                  CommunityAvatar(
                    name: name,
                    photoUrl: user['profile_pic_url']?.toString(),
                    radius: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'SK official' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        AppStatusBadge(
                          label: roleLabel,
                          color: AppColors.primaryRed,
                          dot: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: AppOverline('Your workspace'),
            ),
            const SizedBox(height: 10),
            ...menuItems.map((item) {
              final selected = _selectedItem(context) == item.label;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  selected: selected,
                  selectedColor: AppColors.actionRed,
                  selectedTileColor: AppColors.softPink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primaryRed
                          : AppColors.primaryRed.withValues(alpha: .07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item.icon,
                      size: 20,
                      color: selected ? Colors.white : AppColors.primaryRed,
                    ),
                  ),
                  title: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.actionRed,
                        )
                      : null,
                  onTap: () => _handleMenuItemTap(context, item.label),
                ),
              );
            }),
            const Divider(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Serving the youth of Lipa City',
                style: TextStyle(
                  color: AppColors.lightText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _selectedItem(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name;
    return switch (route) {
      AppRoutes.consolidation => 'Consolidation',
      AppRoutes.moduleManagement => 'Module Management',
      AppRoutes.reports =>
        _currentRole() == 'sk_president' ? 'View Reports' : 'Reports',
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
  final destination = switch (item) {
    PresidentNavItem.home => _homeRouteForCurrentRole(),
    PresidentNavItem.calendar => AppRoutes.presidentCalendar,
    PresidentNavItem.chat => AppRoutes.presidentMessages,
    PresidentNavItem.profile => AppRoutes.profile,
    PresidentNavItem.announcements => AppRoutes.announcements,
    PresidentNavItem.leadership => AppRoutes.leadershipProfiles,
    PresidentNavItem.rankings => AppRoutes.rankings,
  };
  if (ModalRoute.of(context)?.settings.name == destination) return;
  switch (item) {
    case PresidentNavItem.home:
      Navigator.pushReplacementNamed(context, _homeRouteForCurrentRole());
      break;
    case PresidentNavItem.calendar:
      Navigator.pushNamed(context, AppRoutes.presidentCalendar);
      break;
    case PresidentNavItem.chat:
      Navigator.pushNamed(context, AppRoutes.presidentMessages);
      break;
    case PresidentNavItem.announcements:
      Navigator.pushNamed(context, AppRoutes.announcements);
      break;
    case PresidentNavItem.leadership:
      Navigator.pushNamed(context, AppRoutes.leadershipProfiles);
      break;
    case PresidentNavItem.rankings:
      Navigator.pushNamed(context, AppRoutes.rankings);
      break;
    case PresidentNavItem.profile:
      Navigator.pushNamed(context, AppRoutes.profile);
      break;
  }
}

String _homeRouteForCurrentRole() {
  final role = (MobileApiService.currentUser?['role'] ?? '').toString();
  return switch (role) {
    'sk_chairman' => AppRoutes.chairmanHome,
    'sk_secretary' => AppRoutes.secretaryHome,
    _ => AppRoutes.presidentHome,
  };
}
