import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

class MobileApiService {
  // Shared API client and session state for every mobile screen.
  static const String _rememberedEmailKey = 'remembered_email';
  static const String _accessTokenKey = 'access_token';
  static const String _userKey = 'current_user';
  static const String baseUrl = 'https://sk360lipacity.org/api/mobile';
  static String webUrl(String path) {
    final root = baseUrl.replaceFirst(RegExp(r'/api/mobile$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$root$normalizedPath';
  }

  static String? _accessToken;
  static Map<String, dynamic>? currentUser;
  static Map<String, dynamic>? syncedData;

  static bool get isLoggedIn => _accessToken != null;

  static Future<String?> rememberedEmail() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_rememberedEmailKey);
  }

  static Future<void> rememberEmail(String email) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_rememberedEmailKey, email);
  }

  static Future<void> clearRememberedEmail() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_rememberedEmailKey);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _request(
      'POST',
      '/login',
      body: {
        'email': email,
        'password': password,
        'device_name': Platform.operatingSystem,
      },
      requiresAuth: false,
    );

    _accessToken = response['access_token'] as String?;
    currentUser = response['user'] as Map<String, dynamic>?;

    await _saveSession();

    syncedData = await sync();

    return response;
  }

  /// Restores the last authenticated session when the app starts.
  static Future<bool> restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_accessTokenKey);
    final savedUser = preferences.getString(_userKey);

    if (token == null || token.isEmpty || savedUser == null) {
      return false;
    }

    try {
      final decodedUser = jsonDecode(savedUser);
      if (decodedUser is! Map) {
        await _clearSession();
        return false;
      }

      _accessToken = token;
      currentUser = Map<String, dynamic>.from(decodedUser);
      await sync();
      return true;
    } catch (_) {
      await _clearSession();
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> barangays() async {
    final response = await _request('GET', '/barangays', requiresAuth: false);
    final rows = response['barangays'] as List<dynamic>? ?? [];

    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required int barangayId,
    required String password,
    required String passwordConfirmation,
  }) {
    return _request(
      'POST',
      '/register',
      body: {
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'phone_number': phoneNumber,
        'barangay_id': barangayId,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
      requiresAuth: false,
    );
  }

  static Future<Map<String, dynamic>> verifyRegistration({
    required String email,
    required String code,
  }) {
    return _request(
      'POST',
      '/verify',
      body: {'email': email, 'code': code},
      requiresAuth: false,
    );
  }

  static Future<Map<String, dynamic>> resendVerificationCode({
    required String email,
  }) {
    return _request(
      'POST',
      '/verify/resend',
      body: {'email': email},
      requiresAuth: false,
    );
  }

  static Future<Map<String, dynamic>> requestPasswordReset({
    required String method,
    String? email,
    String? phone,
  }) {
    return _request(
      'POST',
      '/password/reset/request',
      body: {'method': method, 'email': ?email, 'phone': ?phone},
      requiresAuth: false,
    );
  }

  static Future<Map<String, dynamic>> verifyPasswordReset({
    required String method,
    required String target,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) {
    return _request(
      'POST',
      '/password/reset/verify',
      body: {
        'method': method,
        'target': target,
        'code': code,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
      requiresAuth: false,
    );
  }

  // Create a post from the mobile announcement screen.
  static Future<Map<String, dynamic>> createWallPost({
    String? title,
    required String content,
    String category = 'update',
    String audience = 'public',
    String status = 'published',
  }) async {
    final response = await _request(
      'POST',
      '/wall/posts',
      body: {
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        'post_content': content,
        'post_category': category,
        'audience': audience,
        'status': status,
      },
    );

    await sync();

    return response;
  }

  static Future<Map<String, dynamic>> toggleWallLike(int announcementId) async {
    final response = await _request('POST', '/wall/posts/$announcementId/like');
    await sync();

    return response;
  }

  // Hide or restore feedback managed by an authorized official.
  static Future<Map<String, dynamic>> updateFeedback({
    required int feedbackId,
    required String status,
  }) async {
    final response = await _request(
      'PATCH',
      '/feedback/$feedbackId',
      body: {'status': status},
    );

    await sync();
    return response;
  }

  static Future<Map<String, dynamic>> updateWallPost({
    required int announcementId,
    required String title,
    required String content,
    required String audience,
    required String status,
  }) async {
    final response = await _request(
      'PATCH',
      '/wall/posts/$announcementId',
      body: {
        'title': title,
        'post_content': content,
        'audience': audience,
        'status': status,
      },
    );

    await sync();
    return response;
  }

  // Save profile text and the optional gallery-selected profile picture.
  static Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
    File? profilePicture,
  }) async {
    final response = profilePicture == null
        ? await _request(
            'POST',
            '/profile',
            body: {'first_name': firstName, 'last_name': lastName},
          )
        : await _uploadProfile(firstName, lastName, profilePicture);

    currentUser = response['user'] as Map<String, dynamic>? ?? currentUser;
    await _saveSession();
    await sync();

    return response;
  }

  static Future<Map<String, dynamic>> _uploadProfile(
    String firstName,
    String lastName,
    File picture,
  ) async {
    final boundary = 'sk360-${DateTime.now().microsecondsSinceEpoch}';
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/profile'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.contentType = ContentType(
        'multipart',
        'form-data',
        parameters: {'boundary': boundary},
      );
      if (_accessToken != null) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $_accessToken',
        );
      }

      void field(String name, String value) {
        request.write('--$boundary\r\n');
        request.write('Content-Disposition: form-data; name="$name"\r\n\r\n');
        request.write('$value\r\n');
      }

      field('first_name', firstName);
      field('last_name', lastName);
      final fileName = picture.path.split(Platform.pathSeparator).last;
      final extension = fileName.split('.').last.toLowerCase();
      final mimeType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      request.write('--$boundary\r\n');
      request.write(
        'Content-Disposition: form-data; name="profile_pic"; filename="$fileName"\r\n',
      );
      request.write('Content-Type: $mimeType\r\n\r\n');
      request.add(await picture.readAsBytes());
      request.write('\r\n--$boundary--\r\n');

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final decoded = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MobileApiException(
          decoded['message']?.toString() ?? 'Profile picture upload failed.',
          statusCode: response.statusCode,
        );
      }
      return decoded;
    } on SocketException {
      throw MobileApiException('Cannot reach the web server.');
    } on FormatException {
      throw MobileApiException('The web server returned an invalid response.');
    } finally {
      client.close(force: true);
    }
  }

  // Direct password update endpoint kept for older profile flows.
  static Future<Map<String, dynamic>> updatePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) {
    return _request(
      'POST',
      '/profile/password',
      body: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  // Request OTP before changing the current user's password.
  static Future<Map<String, dynamic>> requestPasswordChange({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) {
    return _request(
      'POST',
      '/profile/password/request',
      body: {
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  // Confirm the password change using the emailed OTP.
  static Future<Map<String, dynamic>> verifyPasswordChange({
    required String code,
  }) {
    return _request('POST', '/profile/password/verify', body: {'code': code});
  }

  // Create a calendar event and refresh synced data.
  static Future<Map<String, dynamic>> createEvent({
    required String title,
    required String description,
    required DateTime startDateTime,
    DateTime? endDateTime,
    String? location,
    String eventType = 'event',
    String visibility = 'public',
  }) async {
    final response = await _request(
      'POST',
      '/events',
      body: {
        'title': title,
        'description': description,
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
        'event_type': eventType,
        'start_datetime': startDateTime.toIso8601String(),
        if (endDateTime != null) 'end_datetime': endDateTime.toIso8601String(),
        'visibility': visibility,
      },
    );

    await sync();

    return response;
  }

  // Update an existing calendar event.
  static Future<Map<String, dynamic>> updateEvent({
    required int eventId,
    required String title,
    required String description,
    required DateTime startDateTime,
    required DateTime endDateTime,
    String? location,
    String eventType = 'event',
    String visibility = 'public',
  }) async {
    final response = await _request(
      'PATCH',
      '/events/$eventId',
      body: {
        'title': title,
        'description': description,
        if (location != null && location.trim().isNotEmpty)
          'location': location.trim(),
        'event_type': eventType,
        'start_datetime': startDateTime.toIso8601String(),
        'end_datetime': endDateTime.toIso8601String(),
        'visibility': visibility,
      },
    );

    await sync();
    return response;
  }

  static Future<Map<String, dynamic>> createMeeting({
    required String title,
    required DateTime meetingDate,
    required TimeOfDayData meetingTime,
    String? agenda,
  }) async {
    final response = await _request(
      'POST',
      '/meetings',
      body: {
        'title': title,
        'agenda': agenda,
        'meeting_date': meetingDate.toIso8601String().substring(0, 10),
        'meeting_time':
            '${meetingTime.hour.toString().padLeft(2, '0')}:${meetingTime.minute.toString().padLeft(2, '0')}',
      },
    );

    await sync();

    return response;
  }

  static Future<String> meetingJoinUrl(int meetingId) async {
    final response = await _request('GET', '/meetings/$meetingId/join-url');
    return response['join_url']?.toString() ?? '';
  }

  static Future<void> endMeeting(int meetingId) async {
    await _request('PATCH', '/meetings/$meetingId/end');
    await sync();
  }

  // Update meeting details before the meeting starts.
  static Future<Map<String, dynamic>> updateMeeting({
    required int meetingId,
    required String title,
    String? agenda,
    required DateTime meetingDate,
    required TimeOfDayData meetingTime,
  }) async {
    final response = await _request(
      'PATCH',
      '/meetings/$meetingId',
      body: {
        'title': title,
        'agenda': agenda,
        'meeting_date': meetingDate.toIso8601String().substring(0, 10),
        'meeting_time':
            '${meetingTime.hour.toString().padLeft(2, '0')}:${meetingTime.minute.toString().padLeft(2, '0')}',
      },
    );

    await sync();
    return response;
  }

  static Future<Map<String, dynamic>> meetingAgoraToken(int meetingId) {
    return _request('POST', '/meetings/$meetingId/agora-token');
  }

  static Future<Map<String, dynamic>> createCouncilMember({
    required String name,
    String? email,
    String? phone,
    String? term,
  }) async {
    final response = await _request(
      'POST',
      '/leadership/council',
      body: {
        'name': name,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (term != null && term.trim().isNotEmpty) 'term': term.trim(),
      },
    );

    await sync();

    return response;
  }

  static Future<List<Map<String, dynamic>>> chatUsers({
    String search = '',
  }) async {
    final suffix = search.trim().isEmpty
        ? ''
        : '?search=${Uri.encodeQueryComponent(search.trim())}';
    final response = await _request('GET', '/chat/users$suffix');
    final rows = response['users'] as List<dynamic>? ?? [];
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  static Future<Map<String, dynamic>> storeOfficialSubmission({
    required int slotId,
    required String submissionType,
    required PdfUpload pdfFile,
    String reportType = 'monthly',
    int? reportingYear,
    int? reportingMonth,
    String? reportingQuarter,
    String? remarks,
  }) async {
    final response = await _multipartRequest(
      '/official-submissions',
      fields: {
        'slot_id': slotId,
        'submission_type': submissionType,
        'report_type': reportType,
        'reporting_year': ?reportingYear,
        'reporting_month': ?reportingMonth,
        'reporting_quarter': ?reportingQuarter,
        if (remarks != null && remarks.trim().isNotEmpty)
          'remarks': remarks.trim(),
      },
      fileField: 'report_file',
      fileName: pdfFile.name,
      fileBytes: pdfFile.bytes,
    );

    await sync();

    return response;
  }

  static Future<Map<String, dynamic>> _multipartRequest(
    String path, {
    required Map<String, Object> fields,
    required String fileField,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final client = HttpClient();
    final boundary = '----sk360${DateTime.now().microsecondsSinceEpoch}';

    try {
      final request = await client.postUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );

      if (_accessToken != null) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $_accessToken',
        );
      }

      void writeText(String value) => request.add(utf8.encode(value));

      for (final entry in fields.entries) {
        writeText('--$boundary\r\n');
        writeText(
          'Content-Disposition: form-data; name="${entry.key}"\r\n\r\n',
        );
        writeText('${entry.value}\r\n');
      }

      writeText('--$boundary\r\n');
      writeText(
        'Content-Disposition: form-data; name="$fileField"; filename="$fileName"\r\n',
      );
      writeText('Content-Type: application/pdf\r\n\r\n');
      request.add(fileBytes);
      writeText('\r\n--$boundary--\r\n');

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final decoded = responseBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw MobileApiException(
          decoded['message']?.toString() ?? 'Upload failed.',
          statusCode: response.statusCode,
        );
      }

      return decoded;
    } on SocketException {
      throw MobileApiException(
        'Cannot reach the web server. Make sure Laravel is running and your phone is on the same Wi-Fi.',
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, dynamic>> submissionSlots() {
    return _request('GET', '/submission-slots');
  }

  static Future<Map<String, dynamic>> toggleSubmissionSlot(int slotId) {
    return _request('PATCH', '/submission-slots/$slotId/toggle');
  }

  static Future<Map<String, dynamic>> submissionSlotSubmissions(int slotId) {
    return _request('GET', '/submission-slots/$slotId/submissions');
  }

  static Future<Map<String, dynamic>> createSubmissionSlot({
    required String submissionType,
    required String title,
    required String role,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
  }) async {
    final response = await _request(
      'POST',
      '/submission-slots',
      body: {
        'submission_type': submissionType,
        'submission_title': title,
        'description': description,
        'submission_role': role,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'end_date': endDate.toIso8601String().substring(0, 10),
      },
    );

    return response;
  }

  static Future<Map<String, dynamic>> deleteSubmissionSlot(int slotId) {
    return _request('DELETE', '/submission-slots/$slotId');
  }

  static Future<Map<String, dynamic>> markNotificationRead(
    int notificationId,
  ) async {
    final response = await _request(
      'POST',
      '/notifications/$notificationId/read',
    );

    await sync();

    return response;
  }

  static Future<Map<String, dynamic>> consolidation({
    int? year,
    String period = 'all',
    int? month,
    String? quarter,
  }) {
    final query = <String, String>{
      if (year != null) 'year': '$year',
      'period': period,
      if (month != null) 'month': '$month',
      'quarter': ?quarter,
    };
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';

    return _request('GET', '/consolidation$suffix');
  }

  // Pull the latest records shared by the Laravel web application.
  static Future<Map<String, dynamic>> sync({DateTime? since}) async {
    final query = since == null
        ? ''
        : '?since=${Uri.encodeComponent(since.toIso8601String())}';
    final response = await _request('GET', '/sync$query');
    syncedData = response;

    return response;
  }

  static Future<void> logout() async {
    try {
      if (_accessToken != null) {
        await _request('POST', '/logout');
      }
    } finally {
      await _clearSession();
    }
  }

  static Future<void> _saveSession() async {
    final preferences = await SharedPreferences.getInstance();
    if (_accessToken == null || currentUser == null) return;

    await preferences.setString(_accessTokenKey, _accessToken!);
    await preferences.setString(_userKey, jsonEncode(currentUser));
  }

  static Future<void> _clearSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_accessTokenKey);
    await preferences.remove(_userKey);
    _accessToken = null;
    currentUser = null;
    syncedData = null;
  }

  static Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final client = HttpClient();

    try {
      final request = await client.openUrl(method, uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

      if (requiresAuth && _accessToken != null) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $_accessToken',
        );
      }

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final decoded = responseBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errors = decoded['errors'];
        final detailedMessage = errors is Map
            ? errors.values
                  .whereType<List<dynamic>>()
                  .expand((messages) => messages)
                  .join(' ')
            : '';

        throw MobileApiException(
          detailedMessage.isNotEmpty
              ? detailedMessage
              : decoded['message']?.toString() ?? 'Request failed.',
          statusCode: response.statusCode,
        );
      }

      return decoded;
    } on SocketException {
      throw MobileApiException(
        'Cannot reach the web server. Make sure Laravel is running and your phone is on the same Wi-Fi.',
      );
    } on FormatException {
      throw MobileApiException('The web server returned an invalid response.');
    } finally {
      client.close(force: true);
    }
  }
}

class PdfUpload {
  final String name;
  final Uint8List bytes;

  const PdfUpload({required this.name, required this.bytes});
}

class TimeOfDayData {
  final int hour;
  final int minute;

  const TimeOfDayData({required this.hour, required this.minute});
}

class MobileApiException implements Exception {
  final String message;
  final int? statusCode;

  MobileApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
