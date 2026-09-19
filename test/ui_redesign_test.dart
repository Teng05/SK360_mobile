import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sk360/main.dart';
import 'package:sk360/models/app_notification.dart';
import 'package:sk360/routes.dart';
import 'package:sk360/screens/auth/login_screen.dart';
import 'package:sk360/screens/auth/registration_screen.dart';
import 'package:sk360/screens/auth/reset_password_screen.dart';
import 'package:sk360/screens/auth/set_password_screen.dart';
import 'package:sk360/screens/auth/verification_screen.dart';
import 'package:sk360/screens/shared/chat_screen.dart';
import 'package:sk360/screens/shared/create_post_screen.dart';
import 'package:sk360/screens/shared/mobile_profile_screen.dart';
import 'package:sk360/screens/shared/native_agora_meeting_screen.dart';
import 'package:sk360/screens/shared/notifications_screen.dart';
import 'package:sk360/screens/shared/official_submission_screen.dart';
import 'package:sk360/screens/shared/prototype_calendar_screen.dart';
import 'package:sk360/screens/shared/rankings_screen.dart';
import 'package:sk360/screens/shared/role_dashboard_screen.dart';
import 'package:sk360/screens/shared/synced_data_screen.dart';
import 'package:sk360/screens/sk_pres/consolidation_screen.dart';
import 'package:sk360/screens/sk_pres/module_management_screen.dart';
import 'package:sk360/screens/sk_pres/president_leadership_screen.dart';
import 'package:sk360/screens/sk_pres/president_meetings_screen.dart';
import 'package:sk360/screens/sk_pres/president_reports_screen.dart';
import 'package:sk360/services/mobile_api_service.dart';
import 'package:sk360/ui/app_ui.dart';
import 'package:sk360/widgets/president_components.dart';
import 'package:sk360/widgets/notification_bell.dart';

final _captureKey = GlobalKey();
final _now = DateTime.now();
final _future = _now.add(const Duration(days: 3));
String _date(DateTime date) => date.toIso8601String().substring(0, 10);

Map<String, dynamic> _fixtures() => {
  'barangays': [
    {'id': 1, 'barangay_id': 1, 'barangay_name': 'San Salvador'},
    {'id': 2, 'barangay_id': 2, 'barangay_name': 'Santo Tomas'},
  ],
  'wall_posts': [
    {
      'announcement_id': 1,
      'author_name': 'Alexandra Reyes',
      'title': 'Announcement',
      'content':
          'Let’s build a stronger community together. Our youth council meeting is scheduled for next week. Please prepare your project updates and accomplishment reports.',
      'created_at': _date(_now),
      'likes_count': 12,
      'visibility': 'officials_only',
    },
  ],
  'meetings': [
    {
      'meeting_id': 1,
      'title': 'Monthly youth council coordination meeting',
      'meeting_date': _date(_future),
      'meeting_time': '09:00:00',
      'status': 'scheduled',
      'agenda':
          'Project updates, budget planning, and upcoming youth activities.',
    },
  ],
  'events': [
    {
      'title': 'Youth leadership workshop',
      'start_datetime': _now.toIso8601String(),
      'event_type': 'program',
    },
  ],
  'submission_slots': [_slot],
  'accomplishment_reports': [_report],
  'budget_reports': [
    {
      ..._report,
      'title': 'Annual youth development budget',
      'fiscal_year': _now.year,
      'total_amount': '250000',
    },
  ],
  'leadership_profiles': [
    {
      'barangay_id': 1,
      'full_name': 'Alexandra Marie Reyes',
      'position': 'sk_chairman',
      'status': 'current',
      'term': '2023-2026',
    },
    {
      'barangay_id': 1,
      'full_name': 'Miguel Santos',
      'position': 'sk_councilor',
      'status': 'current',
      'term': '2023-2026',
    },
  ],
  'rankings': [
    {
      'barangay_id': 1,
      'barangay_name': 'San Salvador',
      'reporting_period': 'September 2026',
      'total_points': 320,
      'timely_submission_points': 80,
      'completeness_points': 90,
      'participation_points': 75,
    },
  ],
  'ranking_history': [
    {
      'period': 'September 2026',
      'rankings': [
        {'rank': 1, 'barangay_name': 'San Salvador', 'total_points': 320},
        {'rank': 2, 'barangay_name': 'Santo Tomas', 'total_points': 290},
        {
          'rank': 3,
          'barangay_name': 'Council with a long name',
          'total_points': 265,
        },
      ],
    },
  ],
  'notifications': [
    {
      'notification_id': 1,
      'type': 'report_slot',
      'created_at': _now
          .subtract(const Duration(minutes: 10))
          .toIso8601String(),
      'title': 'Report deadline approaching',
      'message':
          'Submit your accomplishment report before the end of the month.',
      'is_read': false,
    },
  ],
};

Map<String, dynamic> get _slot => {
  'slot_id': 1,
  'title': 'Monthly accomplishment report',
  'description':
      'Upload the signed report for your council’s projects and activities.',
  'submission_type': 'accomplishment_report',
  'role': 'Both',
  'status': 'open',
  'start_date': _date(_now.subtract(const Duration(days: 2))),
  'end_date': _date(_future),
};
List<Map<String, dynamic>> get _previewSlots => [
  {
    'slot_id': 2,
    'title': 'Q3 budget utilization report',
    'description':
        'Submit the quarterly statement of SK fund allocation and spending.',
    'submission_type': 'budget_report',
    'role': 'SK Chairman',
    'status': 'open',
    'start_date': _date(_now.subtract(const Duration(days: 10))),
    'end_date': _date(_now.add(const Duration(days: 21))),
  },
  {
    'slot_id': 3,
    'title': 'Annual youth development report',
    'description': '',
    'submission_type': 'accomplishment_report',
    'role': 'SK Secretary',
    'status': 'closed',
    'start_date': _date(_now.subtract(const Duration(days: 60))),
    'end_date': _date(_now.subtract(const Duration(days: 30))),
  },
];
Map<String, dynamic> get _report => {
  'title': 'Youth leadership and community activities',
  'report_title': 'Youth leadership and community activities',
  'barangay_id': 1,
  'status': 'submitted',
  'submitted_at': _date(_now),
  'report_type': 'monthly',
  'reporting_year': _now.year,
  'reporting_month': _now.month,
  'submission_method': 'file',
};

class _ApiOverrides extends HttpOverrides {
  bool empty = false;
  bool fail = false;
  final List<String> requests = [];
  final List<Map<String, dynamic>> publishedPosts = [];
  List<Map<String, dynamic>>? notificationRows;
  final Set<int> readNotificationIds = {};
  @override
  HttpClient createHttpClient(SecurityContext? context) => _Client(this);
  Object response(Uri uri) {
    requests.add(uri.path);
    if (uri.host.contains('googleapis')) return [];
    if (fail) return {'message': 'Connection unavailable'};
    if (uri.path.endsWith('/sync')) {
      return empty
          ? <String, dynamic>{}
          : {
              ..._fixtures(),
              'notifications':
                  (notificationRows ??
                          (_fixtures()['notifications'] as List)
                              .cast<Map<String, dynamic>>())
                      .map(
                        (item) => {
                          ...item,
                          if (readNotificationIds.contains(
                            item['notification_id'],
                          ))
                            'is_read': true,
                        },
                      )
                      .toList(),
            };
    }
    final readMatch = RegExp(
      r'/notifications/(\d+)/read$',
    ).firstMatch(uri.path);
    if (readMatch != null) {
      readNotificationIds.add(int.parse(readMatch.group(1)!));
      return {'message': 'Notification marked as read.'};
    }
    if (uri.path.endsWith('/barangays'))
      return {'barangays': _fixtures()['barangays']};
    if (uri.path.endsWith('/submission-slots')) {
      // Preview-only records show each slot state; tests use the single slot.
      final slots = empty
          ? []
          : [
              _slot,
              if (const bool.fromEnvironment('UI_PREVIEWS')) ..._previewSlots,
            ];
      return {
        'slots': slots,
        'summary': {
          'total_slots': slots.length,
          'open_slots': slots.where((s) => s['status'] == 'open').length,
          'closed_slots': slots.where((s) => s['status'] != 'open').length,
        },
      };
    }
    if (uri.path.endsWith('/submissions'))
      return {
        'submissions': [
          {'barangay_name': 'San Salvador', 'submitted': true},
        ],
      };
    if (uri.path.endsWith('/consolidation'))
      return {
        'years': [_now.year],
        'stats': {'total_barangays': 2, 'submitted': 1, 'pending': 1},
        'submissions': empty
            ? []
            : [
                {
                  'barangay': 'San Salvador',
                  'status': 'submitted',
                  'monthly': 'Submitted',
                  'quarterly': 'Pending',
                  'annual': 'Pending',
                  'last_submission': _date(_now),
                },
              ],
      };
    if (uri.path.endsWith('/chat/users')) return {'users': []};
    return <String, dynamic>{};
  }
}

class _Client implements HttpClient {
  final _ApiOverrides api;
  _Client(this.api);
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _Request(api, url);
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  final _ApiOverrides api;
  final Uri uri;
  _Request(this.api, this.uri);
  String body = '';
  @override
  HttpHeaders get headers => _Headers();
  @override
  void write(Object? object) {
    body += object.toString();
  }

  @override
  Future<HttpClientResponse> close() async {
    if (uri.path.endsWith('/wall/posts') && !api.fail) {
      api.publishedPosts.add(jsonDecode(body) as Map<String, dynamic>);
    }
    return _Response(api.response(uri), api.fail ? 503 : 200);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  final Object body;
  @override
  final int statusCode;
  _Response(this.body, this.statusCode);
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode(jsonEncode(body))).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      routes: {
        AppRoutes.resetPassword: (_) => const ResetPasswordScreen(),
        AppRoutes.presidentCalendar: (_) => const PrototypeCalendarScreen(),
        AppRoutes.profile: (_) => const MobileProfileScreen(),
        AppRoutes.notifications: (_) => const NotificationsScreen(),
        AppRoutes.announcements: (_) =>
            const Scaffold(body: Text('Announcement destination')),
      },
      home: RepaintBoundary(key: _captureKey, child: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _checkScroll(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull, reason: name);
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isNotEmpty) {
    final scrollable = scrollables.first;
    for (var i = 0; i < 4; i++) {
      await tester.drag(scrollable, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$name after scroll $i');
    }
  }
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ApiOverrides api;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = _ApiOverrides();
    HttpOverrides.global = api;
    MobileApiService.currentUser = {
      'user_id': 1,
      'role': 'sk_president',
      'first_name': 'Alexandra',
      'last_name': 'Reyes',
      'email': 'alexandra@example.com',
      'barangay_id': 1,
      'barangay_name': 'San Salvador',
    };
    MobileApiService.syncedData = _fixtures();
  });
  tearDown(() {
    HttpOverrides.global = null;
    MobileApiService.currentUser = null;
    MobileApiService.syncedData = null;
  });

  final screens = <String, Widget Function()>{
    'login': () => const LoginScreen(),
    'registration': () => const RegistrationScreen(),
    'password': () => const SetPasswordScreen(
      firstName: 'Alex',
      lastName: 'Reyes',
      email: 'alex@example.com',
      phoneNumber: '09123456789',
      barangayId: 1,
    ),
    'verification': () =>
        const VerificationScreen(email: 'alexandra.reyes@example.com'),
    'recovery': () => const ResetPasswordScreen(),
    'dashboard': () => const MobileDashboardScreen(),
    'composer': () => const CreatePostScreen(),
    'announcement-composer': () =>
        const CreatePostScreen(initialCategory: 'announcement'),
    'calendar': () => const PrototypeCalendarScreen(),
    'announcements': () => const SyncedDataScreen(
      title: 'Announcements',
      subtitle: 'Council updates',
      dataKey: 'wall_posts',
      icon: Icons.campaign_outlined,
      allowCreatePost: true,
    ),
    'chat': () => const ChatScreen(),
    'notifications': () => const NotificationsScreen(),
    'profile': () => const MobileProfileScreen(),
    'reports': () => const PresidentReportsScreen(),
    'submissions': () =>
        const OfficialSubmissionScreen(kind: SubmissionKind.report),
    'budgets': () =>
        const OfficialSubmissionScreen(kind: SubmissionKind.budget),
    'leadership': () => const PresidentLeadershipScreen(),
    'rankings': () => const RankingsScreen(),
    'consolidation': () => const ConsolidationScreen(),
    'modules': () => const ModuleManagementScreen(),
    'slot-details': () => const SubmissionSlotSubmissionsPage(
      slotId: 1,
      title: 'Monthly accomplishment report',
    ),
    'meetings': () => const PresidentMeetingsScreen(),
  };
  for (final size in [
    const Size(320, 640),
    const Size(390, 844),
    const Size(430, 932),
  ]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} fits ${size.width.toInt()}px', (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pump(tester, entry.value(), size: size);
        await _checkScroll(tester, entry.key);
      });
    }
  }
  for (final entry in screens.entries) {
    testWidgets('${entry.key} supports large text', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pump(
        tester,
        entry.value(),
        size: const Size(320, 700),
        scale: 1.5,
      );
      await _checkScroll(tester, entry.key);
    });
  }
  testWidgets('login validates, reveals password, and opens recovery', (
    tester,
  ) async {
    await _pump(tester, const LoginScreen());
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email and password.'), findsOneWidget);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(find.byTooltip('Hide password'), findsOneWidget);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot your password?'), findsOneWidget);
  });
  testWidgets('OTP cells fit and move focus after each digit', (tester) async {
    await _pump(
      tester,
      const VerificationScreen(email: 'alex@example.com'),
      size: const Size(320, 640),
    );
    await tester.enterText(find.byType(TextField).first, '1');
    await tester.pump();
    final second = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(second.focusNode!.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'bottom navigation reaches calendar and does not push active destination',
    (tester) async {
      await _pump(tester, const MobileDashboardScreen());
      await tester.tap(find.text('Calendar').last);
      await tester.pumpAndSettle();
      expect(find.byType(PrototypeCalendarScreen), findsOneWidget);
      await tester.tap(find.text('Calendar').last);
      await tester.pumpAndSettle();
      expect(find.byType(PrototypeCalendarScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final role in ['sk_chairman', 'sk_secretary']) {
    testWidgets('$role has report and budget shortcuts', (tester) async {
      MobileApiService.currentUser!['role'] = role;
      await _pump(tester, const MobileDashboardScreen());
      await tester.scrollUntilVisible(
        find.text('Submit a report'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Budget reports'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('failed refresh has a working retry', (tester) async {
    api.fail = true;
    await _pump(tester, const PresidentReportsScreen());
    expect(find.text('Unable to refresh'), findsOneWidget);
    api.fail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Unable to refresh'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('recovery code stage and profile forms fit with keyboard', (
    tester,
  ) async {
    await _pump(
      tester,
      const ResetPasswordScreen(),
      size: const Size(320, 640),
    );
    await tester.enterText(find.byType(TextField).first, 'alex@example.com');
    await tester.ensureVisible(find.text('Send reset code'));
    await tester.tap(find.text('Send reset code'));
    await tester.pumpAndSettle();
    expect(find.text('Set a new password'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));
    expect(tester.takeException(), isNull);
    await _pump(
      tester,
      const MobileProfileScreen(),
      size: const Size(320, 640),
    );
    await tester.scrollUntilVisible(
      find.text('Edit profile'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(find.text('Save Changes'), findsOneWidget);
    await tester.showKeyboard(find.byType(TextField).first);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('creation forms fit narrow screens', (tester) async {
    for (final entry in [
      (const PrototypeCalendarScreen(), 'Schedule event'),
      (const ModuleManagementScreen(), 'Create New Slot'),
      (const PresidentMeetingsScreen(), 'Create Meeting'),
    ]) {
      await _pump(tester, entry.$1, size: const Size(320, 640));
      final action = find.text(entry.$2);
      if (action.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          action,
          250,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull, reason: entry.$2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
  for (final entry in [
    (const PrototypeCalendarScreen(), 'Schedule event', 'Create Event'),
    (const ModuleManagementScreen(), 'Create New Slot', 'Create'),
    (const PresidentMeetingsScreen(), 'Create Meeting', 'Create'),
  ]) {
    for (final closeAction in ['Cancel', 'Save', 'Back']) {
      testWidgets(
        '${entry.$2} $closeAction can close while its text field is focused',
        (tester) async {
          await _pump(tester, entry.$1);
          await tester.scrollUntilVisible(
            find.text(entry.$2),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(entry.$2));
          await tester.pumpAndSettle();
          final field = find
              .descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(TextField),
              )
              .first;
          await tester.enterText(field, 'Council planning');
          if (closeAction == 'Back') {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(
              find.text(closeAction == 'Save' ? entry.$3 : 'Cancel'),
            );
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(AlertDialog), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets('group chat can close while its text field is focused', (
    tester,
  ) async {
    await _pump(tester, const ChatScreen());
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('Create group chat'));
      await tester.pumpAndSettle();
      final field = find
          .descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          )
          .first;
      await tester.enterText(field, 'Youth council');
      if (i == 0) {
        await tester.tap(find.text('Cancel'));
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('splash restores session and opens login promptly', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Youth governance. Connected.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOneWidget);
  });
  testWidgets('meeting permission state fits a narrow screen', (tester) async {
    const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => <int, int>{0: 0, 7: 0},
    );
    await _pump(
      tester,
      const NativeAgoraMeetingScreen(meetingId: 1, title: 'Council meeting'),
      size: const Size(320, 640),
    );
    expect(
      find.text('Camera and microphone permission are required.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });

  for (final name in [
    'calendar',
    'announcements',
    'rankings',
    'reports',
    'modules',
    'consolidation',
    'meetings',
  ]) {
    testWidgets('$name empty state fits large text', (tester) async {
      api.empty = true;
      MobileApiService.syncedData = {};
      await _pump(
        tester,
        screens[name]!(),
        size: const Size(320, 700),
        scale: 1.5,
      );
      await _checkScroll(tester, '$name empty');
    });
  }
  testWidgets('report upload form keeps PDF selection and submit action', (
    tester,
  ) async {
    MobileApiService.currentUser!['role'] = 'sk_chairman';
    await _pump(
      tester,
      const OfficialSubmissionScreen(kind: SubmissionKind.report),
      size: const Size(320, 700),
    );
    await tester.scrollUntilVisible(
      find.text('Submit Report'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Submit Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();
    expect(find.text('Choose PDF file'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit PDF'))
          .onPressed,
      isNull,
    );
    const channel = MethodChannel('sk360/file_viewer');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'name': 'report.pdf',
        'base64': base64Encode(utf8.encode('%PDF-test')),
      },
    );
    await tester.ensureVisible(find.text('Choose PDF file'));
    await tester.tap(find.text('Choose PDF file'));
    await tester.pumpAndSettle();
    expect(find.text('report.pdf'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit PDF'))
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      null,
    );
  });
  testWidgets('post, password, councilor and group forms remain accessible', (
    tester,
  ) async {
    await _pump(
      tester,
      screens['announcements']!(),
      size: const Size(320, 700),
    );
    await tester.tap(find.text('New post'));
    await tester.pumpAndSettle();
    expect(find.text('Post type'), findsOneWidget);
    await _checkScroll(tester, 'post form');
    await _pump(
      tester,
      const MobileProfileScreen(),
      size: const Size(320, 700),
    );
    await tester.scrollUntilVisible(
      find.text('Change password'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Show password'), findsNWidgets(3));
    await _checkScroll(tester, 'password form');
    MobileApiService.currentUser!['role'] = 'sk_chairman';
    await _pump(
      tester,
      const PresidentLeadershipScreen(),
      size: const Size(320, 700),
    );
    await tester.tap(find.byTooltip('Add council member'));
    await tester.pumpAndSettle();
    expect(find.text('Add SK Councilor'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _pump(tester, const ChatScreen(), size: const Size(320, 700));
    await tester.tap(find.byTooltip('Create group chat'));
    await tester.pumpAndSettle();
    expect(find.text('Group name'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('menu and notifications fit narrow screens with large text', (
    tester,
  ) async {
    await _pump(
      tester,
      const MobileDashboardScreen(),
      size: const Size(320, 700),
      scale: 1.5,
    );
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    expect(find.byType(PresidentSideDrawer), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _pump(
      tester,
      const MobileProfileScreen(),
      size: const Size(320, 700),
      scale: 1.5,
    );
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('notification bell opens a page and mark all updates its badge', (
    tester,
  ) async {
    api.notificationRows = [
      {
        'notification_id': 1,
        'type': 'announcement',
        'title': 'Council update',
        'is_read': 0,
      },
      {
        'notification_id': 2,
        'type': 'event',
        'title': 'Council activity',
        'is_read': 0,
      },
      {
        'notification_id': 3,
        'type': 'report_slot',
        'title': 'Report window',
        'is_read': 1,
      },
    ];
    await _pump(tester, const Scaffold(body: NotificationBell()));
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(ChoiceChip), findsNWidgets(6));
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();
    expect(api.readNotificationIds, {1, 2});
    expect(
      api.requests.where((path) => path.endsWith('/read')),
      [
        '/api/mobile/notifications/1/read',
        '/api/mobile/notifications/2/read',
      ].reversed,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Unread'));
    await tester.pumpAndSettle();
    expect(find.text('No unread notifications'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationsScreen), findsNothing);
    expect(
      find.descendant(
        of: find.byType(NotificationBell),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'notification filters include meetings in Events and both submission types',
    (tester) async {
      api.notificationRows = [
        {
          'notification_id': 1,
          'type': 'event',
          'title': 'Community activity',
          'is_read': 1,
        },
        {
          'notification_id': 2,
          'type': 'meeting_completed',
          'title': 'Finished meeting',
          'is_read': 0,
        },
        {
          'notification_id': 3,
          'type': 'report_slot',
          'title': 'Report window',
          'is_read': 0,
        },
        {
          'notification_id': 4,
          'type': 'budget_slot',
          'title': 'Budget window',
          'is_read': 0,
        },
        {
          'notification_id': 5,
          'type': 'message',
          'title': 'Council conversation',
          'is_read': 0,
        },
      ];
      await _pump(tester, const NotificationsScreen());
      final events = find.widgetWithText(ChoiceChip, 'Events');
      await tester.ensureVisible(events);
      await tester.tap(events);
      await tester.pumpAndSettle();
      expect(find.text('Community activity'), findsOneWidget);
      expect(find.text('Finished meeting'), findsOneWidget);
      expect(find.text('Report window'), findsNothing);
      final submissions = find.widgetWithText(ChoiceChip, 'Submissions');
      await tester.ensureVisible(submissions);
      await tester.tap(submissions);
      await tester.pumpAndSettle();
      expect(find.text('Report window'), findsOneWidget);
      expect(find.text('Budget window'), findsOneWidget);
      expect(find.text('Finished meeting'), findsNothing);
      final messages = find.widgetWithText(ChoiceChip, 'Messages');
      await tester.ensureVisible(messages);
      await tester.tap(messages);
      await tester.pumpAndSettle();
      expect(find.text('Council conversation'), findsOneWidget);
      expect(api.readNotificationIds, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'tapping a notification marks it read and opens its existing section',
    (tester) async {
      api.notificationRows = [
        {
          'notification_id': 7,
          'type': 'announcement',
          'title': 'Published council notice',
          'message': 'An update from your council.',
          'is_read': 0,
        },
      ];
      await _pump(tester, const NotificationsScreen());
      await tester.tap(find.text('Published council notice'));
      await tester.pumpAndSettle();
      expect(api.readNotificationIds, {7});
      expect(find.text('Announcement destination'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Unread notification'), findsNothing);
      expect(find.byType(NotificationsScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed notification mark all preserves unread records and can be retried',
    (tester) async {
      await _pump(tester, const NotificationsScreen());
      api.fail = true;
      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();
      expect(api.readNotificationIds, isEmpty);
      expect(
        find.textContaining('Some notifications could not be marked as read'),
        findsOneWidget,
      );
      api.fail = false;
      await tester.tap(find.text('Mark all as read'));
      await tester.pumpAndSettle();
      expect(api.readNotificationIds, {1});
      expect(
        find.textContaining('Some notifications could not be marked as read'),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('empty notifications show the requested full-page empty state', (
    tester,
  ) async {
    api.notificationRows = [];
    await _pump(tester, const NotificationsScreen());
    expect(find.text('No notifications yet'), findsOneWidget);
    expect(
      find.text('You’re all caught up. New updates will appear here.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Mark all as read'),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'notification destinations use registered sections and respect official roles',
    () {
      expect(
        const AppNotification({
          'type': 'budget_slot',
        }).destination('sk_secretary'),
        AppRoutes.budget,
      );
      expect(
        const AppNotification({
          'type': 'report_slot',
        }).destination('sk_chairman'),
        AppRoutes.reports,
      );
      expect(
        const AppNotification({
          'type': 'report_slot',
        }).destination('sk_president'),
        AppRoutes.moduleManagement,
      );
      expect(
        const AppNotification({'type': 'module'}).destination('sk_secretary'),
        AppRoutes.reports,
      );
      expect(
        const AppNotification({
          'type': 'meeting_completed',
        }).destination('sk_chairman'),
        AppRoutes.videoMeetings,
      );
      expect(
        const AppNotification({'type': 'message'}).destination('sk_chairman'),
        AppRoutes.presidentMessages,
      );
      expect(
        const AppNotification({'type': 'ranking'}).destination('sk_chairman'),
        AppRoutes.rankings,
      );
      expect(
        const AppNotification({
          'url': '/sk_secretary/calendar',
        }).destination('sk_secretary'),
        AppRoutes.presidentCalendar,
      );
      expect(
        const AppNotification({
          'type': 'unknown',
          'url': 'https://example.com/unrelated',
        }).destination('sk_president'),
        isNull,
      );
      expect(const AppNotification({'type': 'module'}).destination(''), isNull);
      expect(const AppNotification({'is_read': '1'}).isRead, isTrue);
    },
  );

  testWidgets(
    'community composer publishes content and attachment through the existing API',
    (tester) async {
      await _pump(tester, const MobileDashboardScreen());
      await tester.tap(find.text('Community'));
      await tester.pumpAndSettle();
      expect(find.text('Community updates'), findsOneWidget);
      await tester.tap(find.byTooltip('Create post'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Post'))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byType(TextField).first,
        'Youth leadership workshop this Saturday.',
      );
      await tester.scrollUntilVisible(
        find.text('Add a link'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Add a link'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'https://example.com/album',
      );
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();
      expect(
        api.publishedPosts.single['post_content'],
        'Youth leadership workshop this Saturday.\n\nhttps://example.com/album',
      );
      expect(api.publishedPosts.single['post_category'], 'update');
      expect(api.publishedPosts.single['visibility'], 'public');
      expect(find.text('Audience'), findsNothing);
      expect(find.byType(CreatePostScreen), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'failed posting keeps the draft and closing offers keep editing',
    (tester) async {
      await _pump(
        tester,
        const CreatePostScreen(),
        size: const Size(320, 700),
        scale: 1.5,
      );
      await tester.enterText(find.byType(TextField).first, 'Keep this draft');
      api.fail = true;
      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Keep this draft',
      );
      expect(api.publishedPosts, isEmpty);
      await tester.tap(find.byTooltip('Close composer'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this post?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(CreatePostScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('president can limit an announcement to officials', (
    tester,
  ) async {
    await _pump(
      tester,
      const CreatePostScreen(initialCategory: 'announcement'),
      size: const Size(320, 700),
      scale: 1.5,
    );
    expect(find.text('Audience'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'Council briefing at 3 PM.',
    );
    await tester.scrollUntilVisible(
      find.text('Officials only'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Officials only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Officials only'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('won’t appear on the public website'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Post'));
    await tester.pumpAndSettle();
    expect(api.publishedPosts.single['post_category'], 'announcement');
    expect(api.publishedPosts.single['visibility'], 'officials_only');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('posts offer like and copy but no share action', (tester) async {
    await _pump(tester, screens['announcements']!());
    await tester.scrollUntilVisible(
      find.text('Like'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Share'), findsNothing);
    await tester.tap(find.byTooltip('Post options').first);
    await tester.pumpAndSettle();
    expect(find.text('Copy post text'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  if (const bool.fromEnvironment('UI_PREVIEWS')) {
    testWidgets('export representative UI previews', (tester) async {
      debugDisableShadows = false;
      // Load the app's Manrope family so previews match the device.
      final manrope = FontLoader(AppTheme.fontFamily);
      for (final weight in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
      ]) {
        final file = File('assets/fonts/Manrope-$weight.ttf');
        manrope.addFont(
          Future.value(ByteData.sublistView(file.readAsBytesSync())),
        );
      }
      await manrope.load();
      // Load the SDK's bundled Roboto and icons for human-readable previews.
      var directory = File(Platform.resolvedExecutable).parent;
      while (directory.parent.path != directory.path) {
        final font = File(
          '${directory.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        );
        if (font.existsSync()) {
          final loader = FontLoader('Roboto')
            ..addFont(
              Future.value(ByteData.sublistView(font.readAsBytesSync())),
            );
          await loader.load();
          final icons = File(
            '${directory.path}/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          );
          await (FontLoader('MaterialIcons')..addFont(
                Future.value(ByteData.sublistView(icons.readAsBytesSync())),
              ))
              .load();
          break;
        }
        directory = directory.parent;
      }
      for (final name in screens.keys) {
        // Preview-only records exercise the notification styles; app data still
        // comes exclusively from the existing sync endpoint.
        if (name == 'notifications') {
          api.notificationRows = [
            ...(_fixtures()['notifications'] as List)
                .cast<Map<String, dynamic>>(),
            {
              'notification_id': 2,
              'type': 'announcement',
              'title': 'Council update published',
              'message': 'Your council has shared a new community update.',
              'created_at': _now
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
              'is_read': 0,
            },
            {
              'notification_id': 3,
              'type': 'event',
              'title': 'Calendar updated',
              'message':
                  'A youth activity has been added to your council calendar.',
              'created_at': _now
                  .subtract(const Duration(hours: 3))
                  .toIso8601String(),
              'is_read': 1,
            },
            {
              'notification_id': 4,
              'type': 'meeting_completed',
              'title': 'Meeting completed',
              'message':
                  'Your scheduled council meeting is now in past meetings.',
              'created_at': _now
                  .subtract(const Duration(days: 1))
                  .toIso8601String(),
              'is_read': 1,
            },
          ];
        } else {
          api.notificationRows = null;
        }
        // --dart-define=PREVIEW_HEIGHT=2400 captures full-length pages.
        await _pump(
          tester,
          screens[name]!(),
          size: Size(
            390,
            double.parse(
              const String.fromEnvironment(
                'PREVIEW_HEIGHT',
                defaultValue: '844',
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await precacheImage(
            const AssetImage('assets/images/sk logo.png'),
            _captureKey.currentContext!,
          );
        });
        await tester.pump();
        final boundary =
            _captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('build/ui-previews').create(recursive: true);
          await File(
            'build/ui-previews/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        if (name == 'dashboard') {
          await tester.tap(find.text('Community'));
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'build/ui-previews/community.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
      debugDisableShadows = true;
    });
  }
}
