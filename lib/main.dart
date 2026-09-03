import 'package:flutter/material.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'routes.dart';
import 'services/mobile_api_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/shared/mobile_profile_screen.dart';
import 'screens/shared/chat_screen.dart';
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
import 'screens/youth/youth_home_screen.dart';
import 'ui/app_ui.dart';

void main() {
  AndroidWebViewPlatform.registerWith();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SK 360° - Youth Governance Platform',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Geist',
        fontFamilyFallback: const ['Arial', 'Helvetica', 'Segoe UI'],
      ),
      routes: {
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.resetPassword: (context) => const ResetPasswordScreen(),
        AppRoutes.presidentHome: (context) => const SkPresHomeScreen(),
        AppRoutes.chairmanHome: (context) => const ChairmanHomeScreen(),
        AppRoutes.secretaryHome: (context) => const SkSecretaryHomeScreen(),
        AppRoutes.youthHome: (context) => const YouthHomeScreen(),
        AppRoutes.presidentMessages: (context) => const ChatScreen(),
        AppRoutes.presidentCalendar: (context) =>
            const PrototypeCalendarScreen(),
        AppRoutes.videoMeetings: (context) => const PresidentMeetingsScreen(),
        AppRoutes.profile: (context) => const MobileProfileScreen(),
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
          final role =
              MobileApiService.currentUser?['role']?.toString() ?? '';
          return role == 'sk_chairman' || role == 'sk_secretary'
              ? const OfficialSubmissionScreen(kind: SubmissionKind.report)
              : const PresidentReportsScreen();
        },
        AppRoutes.budget: (context) =>
            const OfficialSubmissionScreen(kind: SubmissionKind.budget),
        AppRoutes.moduleManagement: (context) => const ModuleManagementScreen(),
        AppRoutes.consolidation: (context) => const ConsolidationScreen(),
      },
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrayBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _SplashLogo(),
            SizedBox(height: 32),
            Text(
              'SK 360°',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.darkGray,
              ),
            ),
            SizedBox(height: 80),
            Text(
              'Empowering Youth Governance',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.lightText,
                fontWeight: FontWeight.w500,
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
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.primaryRed,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.shield, size: 60, color: AppColors.white),
    );
  }
}
