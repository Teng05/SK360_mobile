import '../routes.dart';

enum NotificationKind {
  announcement,
  event,
  meeting,
  message,
  submission,
  module,
  ranking,
  other,
}

enum NotificationFilter {
  all('All'),
  unread('Unread'),
  announcements('Announcements'),
  events('Events'),
  messages('Messages'),
  submissions('Submissions');

  const NotificationFilter(this.label);
  final String label;

  bool includes(AppNotification item) => switch (this) {
    all => true,
    unread => !item.isRead,
    announcements => item.kind == NotificationKind.announcement,
    events =>
      item.kind == NotificationKind.event ||
          item.kind == NotificationKind.meeting,
    messages => item.kind == NotificationKind.message,
    submissions =>
      item.kind == NotificationKind.submission ||
          item.kind == NotificationKind.module,
  };
}

/// Presentation of the existing sync payload; no extra notification data is fetched.
class AppNotification {
  final Map<String, dynamic> data;
  const AppNotification(this.data);

  int? get id => int.tryParse('${data['notification_id'] ?? data['id'] ?? ''}');
  bool get isRead => data['is_read'] == true || '${data['is_read']}' == '1';
  String get title =>
      '${data['title'] ?? data['notification_title'] ?? data['type'] ?? 'Notification'}';
  String get description =>
      '${data['message'] ?? data['body'] ?? data['content'] ?? data['description'] ?? ''}';
  DateTime? get createdAt =>
      DateTime.tryParse('${data['created_at'] ?? ''}')?.toLocal();
  String get _type =>
      '${data['type'] ?? ''}'.trim().toLowerCase().replaceAll('-', '_');
  String get _section {
    final uri = Uri.tryParse('${data['url'] ?? ''}');
    return uri?.pathSegments
            .where((part) => part.isNotEmpty)
            .lastOrNull
            ?.toLowerCase() ??
        '';
  }

  NotificationKind get kind {
    final type = _type;
    if (type.startsWith('announcement')) return NotificationKind.announcement;
    if (type.startsWith('meeting')) return NotificationKind.meeting;
    if (type.startsWith('event')) return NotificationKind.event;
    if (type.startsWith('message') || type.startsWith('chat')) {
      return NotificationKind.message;
    }
    if (type == 'report_slot' ||
        type == 'budget_slot' ||
        type.startsWith('submission') ||
        type.endsWith('_report')) {
      return NotificationKind.submission;
    }
    if (type.startsWith('module')) return NotificationKind.module;
    if (type.startsWith('ranking')) return NotificationKind.ranking;
    // Older records may identify their section only through the web URL.
    return switch (_section) {
      'announcements' => NotificationKind.announcement,
      'calendar' || 'events' => NotificationKind.event,
      'meetings' => NotificationKind.meeting,
      'chat' || 'messages' => NotificationKind.message,
      'reports' || 'budget' || 'submissions' => NotificationKind.submission,
      'modules' => NotificationKind.module,
      'rankings' => NotificationKind.ranking,
      _ => NotificationKind.other,
    };
  }

  /// The backend supplies section links, not mobile detail identifiers. Only
  /// navigate to registered sections that the current role already uses.
  String? destination(String role) {
    if (!{'sk_president', 'sk_chairman', 'sk_secretary'}.contains(role)) {
      return null;
    }
    final president = role == 'sk_president';
    return switch (kind) {
      NotificationKind.announcement => AppRoutes.announcements,
      NotificationKind.event => AppRoutes.presidentCalendar,
      NotificationKind.meeting => AppRoutes.videoMeetings,
      NotificationKind.message => AppRoutes.presidentMessages,
      NotificationKind.submission =>
        president && _type.endsWith('_slot')
            ? AppRoutes.moduleManagement
            : !president && (_type.startsWith('budget') || _section == 'budget')
            ? AppRoutes.budget
            : AppRoutes.reports,
      NotificationKind.module =>
        president ? AppRoutes.moduleManagement : AppRoutes.reports,
      NotificationKind.ranking => AppRoutes.rankings,
      NotificationKind.other => null,
    };
  }
}
