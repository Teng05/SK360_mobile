import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'routes.dart';
import 'services/mobile_api_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/shared/mobile_profile_screen.dart';
import 'screens/shared/chat_screen.dart';
import 'screens/shared/notifications_screen.dart';
import 'screens/shared/official_submission_screen.dart';
import 'screens/shared/prototype_calendar_screen.dart';
import 'screens/shared/rankings_screen.dart';
import 'screens/shared/synced_data_screen.dart';
import 'screens/sk_chairman/sk_chairman_home_screen.dart';
import 'screens/sk_pres/consolidation_screen.dart';
import 'screens/sk_pres/module_management_screen.dart';
import 'screens/sk_pres/president_meetings_screen.dart';
import 'screens/sk_pres/president_leadership_screen.dart';
import 'screens/sk_pres/president_reports_screen.dart';
import 'screens/sk_pres/sk_pres_home_screen.dart';
import 'screens/sk_secretary/sk_secretary_home_screen.dart';
import 'ui/app_ui.dart';

void main() {
  AndroidWebViewPlatform.registerWith();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final routeBuilders = <String, WidgetBuilder>{
      AppRoutes.login: (context) => const LoginScreen(),
      AppRoutes.resetPassword: (context) => const ResetPasswordScreen(),
      AppRoutes.presidentHome: (context) => const SkPresHomeScreen(),
      AppRoutes.chairmanHome: (context) => const ChairmanHomeScreen(),
      AppRoutes.secretaryHome: (context) => const SkSecretaryHomeScreen(),
      AppRoutes.presidentMessages: (context) => const ChatScreen(),
      AppRoutes.presidentCalendar: (context) => const PrototypeCalendarScreen(),
      AppRoutes.videoMeetings: (context) => const PresidentMeetingsScreen(),
      AppRoutes.profile: (context) => const MobileProfileScreen(),
      AppRoutes.notifications: (context) => const NotificationsScreen(),
      AppRoutes.announcements: (context) => const SyncedDataScreen(
        title: 'Announcements',
        subtitle: 'Public posts',
        dataKey: 'wall_posts',
        icon: Icons.campaign_outlined,
        allowCreatePost: true,
      ),
      AppRoutes.leadershipProfiles: (context) =>
          const PresidentLeadershipScreen(),
      AppRoutes.rankings: (context) => const RankingsScreen(),
      AppRoutes.reports: (context) {
        final role = MobileApiService.currentUser?['role']?.toString() ?? '';
        return role == 'sk_chairman' || role == 'sk_secretary'
            ? const OfficialSubmissionScreen(kind: SubmissionKind.report)
            : const PresidentReportsScreen();
      },
      AppRoutes.budget: (context) =>
          const OfficialSubmissionScreen(kind: SubmissionKind.budget),
      AppRoutes.moduleManagement: (context) => const ModuleManagementScreen(),
      AppRoutes.consolidation: (context) => const ConsolidationScreen(),
    };
    const homeRoutes = {
      AppRoutes.presidentHome,
      AppRoutes.chairmanHome,
      AppRoutes.secretaryHome,
    };

    return MaterialApp(
      title: 'SK 360° - SK Governance Platform',
      theme: AppTheme.light,
      routes: routeBuilders.map(
        (name, builder) => MapEntry(
          name,
          (context) =>
              homeRoutes.contains(name) || name == AppRoutes.notifications
              ? builder(context)
              : BackNavigationGuard(child: builder(context)),
        ),
      ),
      navigatorObservers: [_routeObserver],
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

final _routeObserver = _AppRouteObserver();

class _AppRouteObserver extends NavigatorObserver {
  String? currentRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRoute = route.settings.name;
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    currentRoute = newRoute?.settings.name;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentRoute = previousRoute?.settings.name;
    super.didPop(route, previousRoute);
  }
}

class BackNavigationGuard extends StatefulWidget {
  final Widget child;

  const BackNavigationGuard({super.key, required this.child});

  @override
  State<BackNavigationGuard> createState() => _BackNavigationGuardState();
}

class _BackNavigationGuardState extends State<BackNavigationGuard> {
  Timer? _exitTimer;
  bool _canExit = false;

  static const _homeRoutes = {
    AppRoutes.presidentHome,
    AppRoutes.chairmanHome,
    AppRoutes.secretaryHome,
  };

  @override
  void dispose() {
    _exitTimer?.cancel();
    super.dispose();
  }

  Future<bool> _handleBack() async {
    final route = _routeObserver.currentRoute;
    final role = MobileApiService.currentUser?['role']?.toString();
    final navigator = Navigator.of(context);
    final homeRoute = switch (role) {
      'sk_president' => AppRoutes.presidentHome,
      'sk_chairman' => AppRoutes.chairmanHome,
      'sk_secretary' => AppRoutes.secretaryHome,
      _ => AppRoutes.login,
    };

    final isAuthenticated = _homeRoutes.contains(homeRoute);
    final isInnerScreen =
        isAuthenticated &&
        (route == null || !_homeRoutes.contains(route)) &&
        navigator.canPop();

    if (isInnerScreen) {
      if (mounted) {
        navigator.pushNamedAndRemoveUntil(homeRoute, (route) => false);
      }
      return false;
    }

    // Allow unnamed authentication screens (for example OTP) to pop normally.
    if (!isAuthenticated && navigator.canPop()) {
      navigator.pop();
      return false;
    }

    if (!_canExit) {
      setState(() => _canExit = true);
      _exitTimer?.cancel();
      _exitTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _canExit = false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Press back again to exit.')),
      );
      return false;
    }

    await SystemNavigator.pop();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: widget.child,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _minimumDuration = Duration(milliseconds: 650);
  late final AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: _minimumDuration,
    )..forward();
    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    final startedAt = DateTime.now();
    final restored = await MobileApiService.restoreSession();
    final remaining = _minimumDuration - DateTime.now().difference(startedAt);
    if (remaining > Duration.zero) await Future.delayed(remaining);
    if (!mounted) return;

    if (restored) {
      final role = MobileApiService.currentUser?['role']?.toString();
      Navigator.pushReplacementNamed(context, _homeRouteForRole(role));
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  String _homeRouteForRole(String? role) {
    return switch (role) {
      'sk_president' => AppRoutes.presidentHome,
      'sk_chairman' => AppRoutes.chairmanHome,
      'sk_secretary' => AppRoutes.secretaryHome,
      _ => AppRoutes.login,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _SplashLogo(),
                  SizedBox(height: 28),
                  Text(
                    'SK 360°',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: AppColors.darkGray,
                    ),
                  ),
                  SizedBox(height: 12),
                  AppEyebrow(label: 'Sangguniang Kabataan'),
                  SizedBox(height: 14),
                  Text(
                    'Youth governance. Connected.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.lightText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 28,
              right: 28,
              bottom: 24,
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) => LinearProgressIndicator(
                      value: null,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(8),
                      backgroundColor: AppColors.softPink,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryRed,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Opening your workspace…',
                    style: TextStyle(color: AppColors.lightText, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryRed,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryRed.withValues(alpha: .3),
            blurRadius: 30,
            spreadRadius: -6,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: const AppLogo(),
    );
  }
}
